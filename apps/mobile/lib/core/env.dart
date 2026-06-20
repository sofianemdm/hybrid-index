/// Configuration d'environnement de l'app (injectée au build via --dart-define).
/// L'app mobile ne connaît QUE l'`api` (jamais le score-service — cf. architecture §1.2).
class Env {
  const Env._();

  /// URL de base de l'API publique.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// ID client Google OAuth (public). Surchargeable via --dart-define=GOOGLE_CLIENT_ID=...
  /// Vide = bouton Google désactivé.
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '963703387600-v3hj9b93pmldhr3tfs866vi14bcim5v1.apps.googleusercontent.com',
  );

  static bool get googleEnabled => googleClientId.isNotEmpty;
}
