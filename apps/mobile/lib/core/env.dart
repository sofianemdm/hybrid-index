/// Configuration d'environnement de l'app (injectée au build via --dart-define).
/// L'app mobile ne connaît QUE l'`api` (jamais le score-service — cf. architecture §1.2).
class Env {
  const Env._();

  /// URL de base de l'API publique.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
