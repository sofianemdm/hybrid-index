import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/env.dart';
import 'api_client.dart';

/// Service de notifications push (Firebase Cloud Messaging).
///
/// Ne fait RIEN tant que [Env.pushEnabled] est faux (build sans `--dart-define=PUSH_ENABLED=true`)
/// OU sur le web (`kIsWeb`) : FCM web nécessite une config dédiée (service worker + clé VAPID), non
/// gérée ici. Sur Android/iOS, `Firebase.initializeApp()` lit la config native (google-services.json /
/// GoogleService-Info.plist) — pas besoin de firebase_options.dart.
class PushService {
  PushService(this._api);
  final ApiClient _api;

  Future<void> init() async {
    // Garde-fou : inactif par défaut et toujours sur le web (préserve la version navigateur).
    if (!Env.pushEnabled || kIsWeb) {
      debugPrint('[push] inactif (pushEnabled=${Env.pushEnabled}, web=$kIsWeb).');
      return;
    }
    try {
      await Firebase.initializeApp(); // lit la config native (google-services.json)
      final messaging = FirebaseMessaging.instance;
      // Demande la permission (iOS l'exige ; Android 13+ aussi).
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] permission refusée par l’utilisateur.');
        return;
      }
      await _registerToken(messaging);
      // Le token peut changer (réinstallation, restauration) → on le ré-enregistre.
      messaging.onTokenRefresh.listen((t) {
        _api.registerPushToken(t).catchError((Object e) {
          debugPrint('[push] refresh token KO: $e');
          return false;
        });
      });
    } catch (e) {
      debugPrint('[push] init échouée: $e');
    }
  }

  Future<void> _registerToken(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    if (token == null) return;
    try {
      await _api.registerPushToken(token);
    } catch (e) {
      debugPrint('[push] enregistrement token échoué: $e');
    }
  }
}
