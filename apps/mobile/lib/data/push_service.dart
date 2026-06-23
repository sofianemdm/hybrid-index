import 'package:flutter/foundation.dart';

import '../core/env.dart';
import 'api_client.dart';

/// Service de notifications push — « prêt mais inactif ».
///
/// L'app est entièrement câblée pour le push (point d'init, enregistrement du token côté API,
/// flag d'activation), mais RIEN ne s'exécute tant que [Env.pushEnabled] est faux. C'est
/// l'interrupteur : le jour où le projet Firebase est créé, on :
///   1. ajoute les dépendances `firebase_core` + `firebase_messaging` au pubspec,
///   2. génère `firebase_options.dart` (flutterfire configure),
///   3. remplace [_acquireToken] par l'acquisition réelle du token FCM,
///   4. build avec --dart-define=PUSH_ENABLED=true.
/// Aucun autre changement de structure n'est nécessaire.
class PushService {
  PushService(this._api);
  final ApiClient _api;

  Future<void> init() async {
    if (!Env.pushEnabled) {
      debugPrint('[push] inactif (Env.pushEnabled=false) — prêt à activer avec Firebase.');
      return;
    }
    // --- ACTIVATION (à brancher avec firebase_messaging) ---
    // 1) demander la permission (FirebaseMessaging.instance.requestPermission)
    // 2) récupérer le token (FirebaseMessaging.instance.getToken)
    // 3) l'enregistrer côté API (déjà implémenté ci-dessous)
    final token = await _acquireToken();
    if (token == null) return;
    try {
      await _api.registerPushToken(token);
    } catch (e) {
      debugPrint('[push] enregistrement token échoué: $e');
    }
  }

  /// Acquisition du token FCM. Stub tant que Firebase n'est pas branché (retourne null).
  Future<String?> _acquireToken() async {
    // TODO(activation Firebase) : return await FirebaseMessaging.instance.getToken();
    return null;
  }
}
