import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/env.dart';

/// Analytics « prêt mais inactif » — capture d'events produit pour piloter la rétention
/// (D1/D7/D30, tunnel d'activation, temps jusqu'au « wow »). Sans clé PostHog, les events sont
/// seulement journalisés (aucun envoi réseau). Avec la clé, ils sont postés sur l'API HTTP PostHog
/// (pas de SDK lourd). Tolérant : un échec d'envoi n'impacte jamais l'app.
class Analytics {
  Analytics._();

  static bool get enabled => Env.posthogKey.isNotEmpty;

  /// Identifiant stable de l'utilisateur (posé au login ; 'anonymous' avant).
  static String distinctId = 'anonymous';
  static void identify(String userId) => distinctId = userId;
  static void reset() => distinctId = 'anonymous';

  /// Capture un event. No-op réseau si désactivé (journalisé en debug).
  static Future<void> capture(String event, [Map<String, Object?> properties = const {}]) async {
    if (!enabled) {
      if (kDebugMode) debugPrint('[analytics] $event ${properties.isEmpty ? '' : properties}');
      return;
    }
    try {
      await http
          .post(
            Uri.parse('${Env.posthogHost}/capture/'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'api_key': Env.posthogKey,
              'event': event,
              'distinct_id': distinctId,
              'properties': {...properties, '\$lib': 'hybrid-index-flutter'},
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Analytique non bloquant : on avale toute erreur.
    }
  }
}
