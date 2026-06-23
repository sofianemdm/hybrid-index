import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';
import 'api_client.dart';
import 'models.dart';

/// Client API partagé (singleton applicatif).
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Plan de séances pour compléter le radar (révéler le vrai Index). À invalider après tout log/suppression
/// de résultat (les attributs débloqués changent). autoDispose : rechargé à l'ouverture de l'accueil.
final completionPlanProvider =
    FutureProvider.autoDispose<CompletionPlan>((ref) => ref.read(apiClientProvider).completionPlan());

enum AuthStatus { loading, loggedOut, loggedIn }

class SessionState {
  final AuthStatus status;
  final AuthUser? user;
  final String? sex;
  final String? goal;
  const SessionState({required this.status, this.user, this.sex, this.goal});

  SessionState copyWith({AuthStatus? status, AuthUser? user, String? sex, String? goal}) => SessionState(
        status: status ?? this.status,
        user: user ?? this.user,
        sex: sex ?? this.sex,
        goal: goal ?? this.goal,
      );
}

const _kToken = 'hi_token';

/// État d'authentification, persisté via shared_preferences.
class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._ref) : super(const SessionState(status: AuthStatus.loading));

  final Ref _ref;
  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token == null) {
      state = const SessionState(status: AuthStatus.loggedOut);
      return;
    }
    _api.setToken(token);
    try {
      final me = await _api.me();
      Analytics.identify(me['id'] as String);
      state = SessionState(
        status: AuthStatus.loggedIn,
        user: AuthUser(
          id: me['id'] as String,
          email: me['email'] as String? ?? '',
          displayName: me['displayName'] as String? ?? '',
        ),
        sex: me['sex'] as String?,
        goal: me['goal'] as String?,
      );
    } catch (_) {
      await prefs.remove(_kToken);
      _api.setToken(null);
      state = const SessionState(status: AuthStatus.loggedOut);
    }
  }

  Future<void> _persist(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    _api.setToken(token);
  }

  Future<void> register(Map<String, dynamic> payload) async {
    final res = await _api.register(payload);
    Analytics.identify(res.user.id);
    await _persist(res.token);
    state = SessionState(
      status: AuthStatus.loggedIn,
      user: res.user,
      sex: payload['sex'] as String?,
      goal: payload['goal'] as String?,
    );
  }

  /// Connexion via Google. `profile` requis seulement à la première connexion (age-gate).
  Future<void> loginWithGoogle(String idToken, {Map<String, dynamic>? profile}) async {
    final res = await _api.googleAuth(idToken, profile);
    Analytics.identify(res.user.id);
    await _persist(res.token);
    final me = await _api.me();
    state = SessionState(
      status: AuthStatus.loggedIn,
      user: res.user,
      sex: me['sex'] as String?,
      goal: me['goal'] as String?,
    );
  }

  Future<void> login(String email, String password) async {
    final res = await _api.login(email, password);
    Analytics.identify(res.user.id);
    await _persist(res.token);
    final me = await _api.me();
    state = SessionState(
      status: AuthStatus.loggedIn,
      user: res.user,
      sex: me['sex'] as String?,
      goal: me['goal'] as String?,
    );
  }

  /// Re-fetch /me après une modification de profil (objectif, pseudo…).
  Future<void> refreshMe() async {
    if (state.status != AuthStatus.loggedIn || state.user == null) return;
    final me = await _api.me();
    state = state.copyWith(
      user: AuthUser(
        id: state.user!.id,
        email: state.user!.email,
        displayName: me['displayName'] as String? ?? state.user!.displayName,
      ),
      sex: me['sex'] as String?,
      goal: me['goal'] as String?,
    );
  }

  Future<void> logout() async {
    Analytics.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    _api.setToken(null);
    state = const SessionState(status: AuthStatus.loggedOut);
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) => SessionNotifier(ref));
