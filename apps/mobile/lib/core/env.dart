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
    // Client OAuth *Web* du projet Firebase hybrid-index-ffe2c (doit être IDENTIQUE au
    // GOOGLE_CLIENT_ID vérifié par le backend). Sert de serverClientId sur mobile.
    defaultValue: '702021189861-5v879fvjgs796gttas206gb5qip0meq7.apps.googleusercontent.com',
  );

  static bool get googleEnabled => googleClientId.isNotEmpty;

  /// Notifications push : OFF par défaut tant que Firebase n'est pas configuré (« prêt mais
  /// inactif »). Activable via --dart-define=PUSH_ENABLED=true une fois les credentials FCM en place.
  static const bool pushEnabled = bool.fromEnvironment('PUSH_ENABLED', defaultValue: false);

  /// Analytics (PostHog) : vide = inactif (les events sont seulement journalisés). Fournir la clé
  /// projet via --dart-define=POSTHOG_KEY=... pour activer l'envoi réel.
  static const String posthogKey = String.fromEnvironment('POSTHOG_KEY', defaultValue: '');
  static const String posthogHost = String.fromEnvironment('POSTHOG_HOST', defaultValue: 'https://eu.i.posthog.com');
}
