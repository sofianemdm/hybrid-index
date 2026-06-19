import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/env.dart';
import 'models.dart';

/// Erreur API normalisée (envelope { error: { code, message } }).
class ApiException implements Exception {
  final String code;
  final String message;
  final int status;
  ApiException(this.code, this.message, this.status);
  @override
  String toString() => message;
}

/// Client HTTP vers l'`api` publique. Gère le bearer token.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Env.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_token != null) 'authorization': 'Bearer $_token',
      };

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$_baseUrl$path');
    late http.Response res;
    try {
      switch (method) {
        case 'POST':
          res = await _client.post(uri, headers: _headers, body: jsonEncode(body));
          break;
        case 'GET':
        default:
          res = await _client.get(uri, headers: _headers);
          break;
      }
    } catch (_) {
      throw ApiException('NETWORK', 'Serveur injoignable. L\'API tourne-t-elle sur $_baseUrl ?', 0);
    }

    final text = res.body.isEmpty ? '{}' : res.body;
    final dynamic decoded = jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    final err = (decoded is Map && decoded['error'] is Map) ? decoded['error'] as Map : null;
    throw ApiException(
      err?['code']?.toString() ?? 'ERROR',
      err?['message']?.toString() ?? 'Une erreur est survenue (${res.statusCode}).',
      res.statusCode,
    );
  }

  // --- Auth ---
  Future<({String token, AuthUser user})> register(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/auth/register', payload) as Map<String, dynamic>;
    return (token: j['token'] as String, user: AuthUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<({String token, AuthUser user})> login(String email, String password) async {
    final j = await _send('POST', '/v1/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    return (token: j['token'] as String, user: AuthUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<Map<String, dynamic>> me() async => await _send('GET', '/v1/me') as Map<String, dynamic>;

  // --- Onboarding ---
  Future<Profile> onboardingEstimate(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/onboarding/estimate', payload) as Map<String, dynamic>;
    return Profile.fromJson(j);
  }

  Future<Profile> onboardingComplete(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/onboarding/complete', payload) as Map<String, dynamic>;
    return Profile.fromJson(j);
  }

  // --- Profil / résultats ---
  Future<Profile?> myProfile() async {
    try {
      final j = await _send('GET', '/v1/me/profile') as Map<String, dynamic>;
      return Profile.fromJson(j);
    } on ApiException catch (e) {
      if (e.status == 404) return null; // pas encore d'Index
      rethrow;
    }
  }

  Future<Profile> logResult(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/results', payload) as Map<String, dynamic>;
    return Profile.fromJson(j['profile'] as Map<String, dynamic>);
  }

  // --- Classement / rival ---
  Future<Leaderboard> leaderboard(String sex, {int limit = 50}) async {
    final j = await _send('GET', '/v1/leaderboard?sex=$sex&limit=$limit') as Map<String, dynamic>;
    return Leaderboard.fromJson(j);
  }

  Future<Rival> rival() async {
    final j = await _send('GET', '/v1/me/rival') as Map<String, dynamic>;
    return Rival.fromJson(j);
  }
}
