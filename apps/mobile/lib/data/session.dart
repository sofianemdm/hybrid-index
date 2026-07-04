// TEMPORAIRE (auth-rebuild) : session factice sans connexion réelle. À REMPLACER par la nouvelle auth.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

/// Token de dev injecté dans [ApiClient] tant qu'il n'y a pas de vraie connexion.
const _devToken = 'dev';

/// Client API partagé (singleton applicatif). Reçoit d'emblée le token de dev
/// (auth-rebuild) pour que les écrans qui appellent l'API continuent de fonctionner.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  client.setToken(_devToken);
  return client;
});

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

/// TEMPORAIRE (auth-rebuild) : session factice.
///
/// Démarre DIRECTEMENT en [AuthStatus.loggedIn] avec un utilisateur placeholder. Aucune logique
/// réseau ni persistance : les anciennes méthodes de connexion (register/login/google/apple) ont
/// été retirées avec l'écran d'auth. Les méthodes conservées ([logout], [refreshMe]) sont des
/// no-op non réseau, pour ne pas casser les appelants (réglages, etc.).
class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._ref)
      : super(const SessionState(
          status: AuthStatus.loggedIn,
          user: AuthUser(id: 'dev', email: 'dev@local', displayName: 'Dev'),
        ));

  // ignore: unused_field
  final Ref _ref;

  /// No-op : la restauration de session réelle sera reconstruite avec la nouvelle auth.
  Future<void> bootstrap() async {}

  /// Re-fetch /me après une modification de profil (objectif, pseudo…). Conservé car appelé par
  /// les réglages ; tolérant si l'API n'est pas jointe.
  Future<void> refreshMe() async {
    if (state.status != AuthStatus.loggedIn || state.user == null) return;
    try {
      final me = await _ref.read(apiClientProvider).me();
      state = state.copyWith(
        user: AuthUser(
          id: state.user!.id,
          email: state.user!.email,
          displayName: me['displayName'] as String? ?? state.user!.displayName,
        ),
        sex: me['sex'] as String?,
        goal: me['goal'] as String?,
      );
    } catch (_) {/* auth-rebuild : pas de session réelle, on ignore */}
  }

  /// No-op réseau : sans vraie auth, il n'y a rien à déconnecter. Conservé pour les appelants
  /// (réglages). À REMPLACER par la vraie déconnexion avec la nouvelle auth.
  Future<void> logout() async {}
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) => SessionNotifier(ref));
