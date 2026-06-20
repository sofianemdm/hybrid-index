import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/env.dart';
import 'models.dart';

/// Erreur API normalisée (envelope { error: { code, message, details } }).
class ApiException implements Exception {
  final String code;
  final String message;
  final int status;
  final Map<String, dynamic>? details;
  ApiException(this.code, this.message, this.status, {this.details});
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
        case 'PATCH':
          res = await _client.patch(uri, headers: _headers, body: jsonEncode(body));
          break;
        case 'DELETE':
          res = await _client.delete(uri, headers: _headers);
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
      details: err?['details'] is Map ? Map<String, dynamic>.from(err!['details'] as Map) : null,
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

  /// Connexion Google : `profile` requis seulement à la première connexion.
  Future<({String token, AuthUser user})> googleAuth(String idToken, Map<String, dynamic>? profile) async {
    final body = <String, dynamic>{'idToken': idToken, if (profile != null) 'profile': profile};
    final j = await _send('POST', '/v1/auth/google', body) as Map<String, dynamic>;
    return (token: j['token'] as String, user: AuthUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<Map<String, dynamic>> me() async => await _send('GET', '/v1/me') as Map<String, dynamic>;

  Future<void> updateMe(Map<String, dynamic> payload) async => await _send('PATCH', '/v1/me', payload);

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

  Future<({Profile profile, List<String> newBadges})> logResult(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/results', payload) as Map<String, dynamic>;
    final badges = ((j['unlockedBadges'] as List?) ?? [])
        .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return (profile: Profile.fromJson(j['profile'] as Map<String, dynamic>), newBadges: badges);
  }

  Future<List<WodResultItem>> results() async {
    final j = await _send('GET', '/v1/results') as List<dynamic>;
    return j.map((e) => WodResultItem.fromJson(e as Map<String, dynamic>)).toList();
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

  // --- Coach / profils publics ---
  Future<CoachResult> coach({String? attribute}) async {
    final q = attribute == null ? '' : '?attribute=$attribute';
    final j = await _send('GET', '/v1/coach$q') as Map<String, dynamic>;
    return CoachResult.fromJson(j);
  }

  Future<PublicProfile> publicProfile(String userId) async {
    final j = await _send('GET', '/v1/profiles/$userId') as Map<String, dynamic>;
    return PublicProfile.fromJson(j);
  }

  // --- Engagement / RGPD ---
  Future<StreakState> streak() async {
    final j = await _send('GET', '/v1/me/streak') as Map<String, dynamic>;
    return StreakState.fromJson(j);
  }

  Future<List<BadgeModel>> badges() async {
    final j = await _send('GET', '/v1/me/badges') as List<dynamic>;
    return j.map((e) => BadgeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StreakState> updateStreak({int? weeklyGoal, bool? plannedRest}) async {
    final body = <String, dynamic>{
      if (weeklyGoal != null) 'weeklyGoal': weeklyGoal,
      if (plannedRest != null) 'plannedRest': plannedRest,
    };
    final j = await _send('PATCH', '/v1/me/streak', body) as Map<String, dynamic>;
    return StreakState.fromJson(j);
  }

  Future<List<FeedItem>> notificationsFeed() async {
    final j = await _send('GET', '/v1/me/notifications/feed') as List<dynamic>;
    return j.map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> notificationPrefs() async =>
      await _send('GET', '/v1/me/notifications') as Map<String, dynamic>;

  Future<void> updateNotificationPrefs(Map<String, dynamic> payload) async =>
      _send('PATCH', '/v1/me/notifications', payload);

  Future<EndgameInfo> endgame() async {
    final j = await _send('GET', '/v1/me/endgame') as Map<String, dynamic>;
    return EndgameInfo.fromJson(j);
  }

  Future<dynamic> exportData() async => _send('GET', '/v1/me/export');

  Future<void> deleteAccount() async => _send('DELETE', '/v1/me');

  // --- WOD Engine ---
  Future<List<WodCatalogEntry>> wodsCatalog() async {
    final j = await _send('GET', '/v1/wods') as List<dynamic>;
    return j.map((e) => WodCatalogEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WodDetail> wodDetail(String id) async {
    final j = await _send('GET', '/v1/wods/$id') as Map<String, dynamic>;
    return WodDetail.fromJson(j);
  }

  Future<List<WodLeaderboardEntry>> wodLeaderboard(String id, String sex) async {
    final j = await _send('GET', '/v1/wods/$id/leaderboard?sex=$sex') as Map<String, dynamic>;
    return ((j['entries'] as List?) ?? []).map((e) => WodLeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  // --- Avatar ---
  Future<AvatarConfig> getAvatar() async {
    final j = await _send('GET', '/v1/me/avatar') as Map<String, dynamic>;
    return AvatarConfig.fromJson(j);
  }

  Future<void> updateAvatar(AvatarConfig config) async => _send('PATCH', '/v1/me/avatar', config.toJson());
}
