import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart' show appNavigatorKey, appMessengerKey;
import '../core/env.dart';
import '../features/messaging/chat_screen.dart';
import '../features/messaging/conversations_screen.dart';
import '../theme/tokens.dart';
import 'api_client.dart';

/// Handler de notification en ARRIÈRE-PLAN / app TUÉE (data-only).
///
/// DOIT être une fonction top-level (ou statique) annotée `@pragma('vm:entry-point')` : FCM
/// l'exécute dans un isolate Dart séparé, sans le code d'`main()` ni le moindre contexte UI
/// (pas de `BuildContext`, pas de navigator, pas de provider). On reste donc MINIMAL et SÛR :
/// on ré-initialise Firebase (l'isolate est neuf) puis on se contente de tracer. Le routage
/// réel se fera au tap via `onMessageOpenedApp` / `getInitialMessage` une fois l'app au premier plan.
@pragma('vm:entry-point')
Future<void> firebaseBgHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('[push] bg message: type=${message.data['type']}');
  } catch (e) {
    debugPrint('[push] bg handler KO: $e');
  }
}

/// Onglets de la coquille principale (HomeShell). Doit rester aligné avec l'ordre des onglets
/// dans `features/home/home_shell.dart` (IndexedStack + barre de nav).
class _Tab {
  static const home = 0; // Accueil
  static const sessions = 1; // Séances / Coach
  static const community = 2; // Communauté
  static const leaderboard = 3; // Ligue / Classement
}

/// Service de notifications push (Firebase Cloud Messaging).
///
/// Ne fait RIEN tant que [Env.pushEnabled] est faux (build sans `--dart-define=PUSH_ENABLED=true`)
/// OU sur le web (`kIsWeb`) : FCM web nécessite une config dédiée (service worker + clé VAPID), non
/// gérée ici. Sur Android/iOS, `Firebase.initializeApp()` lit la config native (google-services.json /
/// GoogleService-Info.plist) — pas besoin de firebase_options.dart.
///
/// Routage des taps : le backend (`apps/api/.../push.service.ts`) place un champ `type` dans
/// `message.data`. Chaque `type` mène à un écran. Tout type inconnu ou absent retombe sur l'Accueil
/// (jamais de crash, jamais d'écran vide).
class PushService {
  PushService(this._api, {required this.goToTab, this.deviceLocale});
  final ApiClient _api;

  /// Bascule l'onglet actif de la coquille (branché sur `homeTabProvider` dans main.dart).
  final void Function(int tab) goToTab;

  /// Langue courante de l'app ('fr' / 'en'), transmise au backend pour des push localisés
  /// (`Profile.locale`). `null` = on ne touche pas à la langue côté serveur.
  final String? deviceLocale;

  Future<void> init() async {
    // Garde-fou : inactif par défaut et toujours sur le web (préserve la version navigateur).
    if (!Env.pushEnabled || kIsWeb) {
      debugPrint('[push] inactif (pushEnabled=${Env.pushEnabled}, web=$kIsWeb).');
      return;
    }
    try {
      await Firebase.initializeApp(); // lit la config native (google-services.json)
      // Handler des push reçus app en arrière-plan / tuée (data-only) : doit être branché AVANT
      // toute réception. Fonction top-level @pragma('vm:entry-point') (isolate dédié, sans UI).
      FirebaseMessaging.onBackgroundMessage(firebaseBgHandler);
      final messaging = FirebaseMessaging.instance;
      // Demande la permission (iOS l'exige ; Android 13+ aussi).
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] permission refusée par l’utilisateur.');
        return;
      }
      await _registerToken(messaging);
      // Transmet la langue du device au backend (push localisés FR/EN → Profile.locale).
      await _syncLocale();
      // Le token peut changer (réinstallation, restauration) → on le ré-enregistre.
      messaging.onTokenRefresh.listen((t) {
        _api.registerPushToken(t).catchError((Object e) {
          debugPrint('[push] refresh token KO: $e');
          return false;
        });
      });
      _wireHandlers(messaging);
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

  /// Pousse la langue courante de l'app vers `Profile.locale` (via PATCH /v1/me) afin que le
  /// backend envoie le bon FR/EN. Tolérant : un échec réseau n'interrompt jamais l'init push.
  Future<void> _syncLocale() async {
    final loc = deviceLocale;
    if (loc != 'fr' && loc != 'en') return;
    try {
      await _api.updateMe({'locale': loc});
    } catch (e) {
      debugPrint('[push] sync locale échouée: $e');
    }
  }

  /// Branche les 3 points d'entrée d'une notification :
  /// 1. [FirebaseMessaging.onMessage] : reçue alors que l'app est AU PREMIER PLAN → bannière in-app
  ///    non bloquante (le système n'affiche rien de lui-même dans ce cas).
  /// 2. [FirebaseMessaging.onMessageOpenedApp] : tap alors que l'app est EN ARRIÈRE-PLAN → routage.
  /// 3. [FirebaseMessaging.instance.getInitialMessage] : tap qui a LANCÉ l'app (process tué) → routage.
  void _wireHandlers(FirebaseMessaging messaging) {
    FirebaseMessaging.onMessage.listen(_showForegroundBanner);
    FirebaseMessaging.onMessageOpenedApp.listen(_route);

    // L'app a été ouverte depuis l'état « tuée » via un tap sur la notif : on attend que le premier
    // frame soit posé (navigator prêt) avant de router.
    messaging.getInitialMessage().then((msg) {
      if (msg == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _route(msg));
    });
  }

  /// Bannière in-app NON bloquante (snackbar) quand une notif arrive app au premier plan. Un tap
  /// sur « Voir » route vers l'écran cible. Tolérant : si le messenger n'est pas prêt, on n'affiche
  /// simplement rien (jamais d'exception).
  void _showForegroundBanner(RemoteMessage message) {
    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    final notif = message.notification;
    final title = notif?.title ?? _fallbackTitle(_typeOf(message));
    final body = notif?.body ?? '';

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HiColors.bgElevated2,
          duration: const Duration(seconds: 5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              if (body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HiColors.textSecondary, fontSize: 12.5)),
                ),
            ],
          ),
          action: SnackBarAction(
            label: 'Voir',
            textColor: HiColors.brandPrimary,
            onPressed: () => _route(message),
          ),
        ),
      );
  }

  /// Achemine vers l'écran cible selon `message.data['type']`. Robuste aux données manquantes :
  /// type absent/inconnu → Accueil, sans crash.
  void _route(RemoteMessage message) {
    final type = _typeOf(message);
    switch (type) {
      case 'new-message':
        // Deep-link : si le backend a joint `conversationId` (+ `senderId`/`senderName`) on ouvre
        // DIRECTEMENT le bon fil de discussion. Sinon (ancienne notif), repli sur la liste.
        goToTab(_Tab.community);
        final convId = _dataStr(message, 'conversationId');
        final senderId = _dataStr(message, 'senderId');
        final senderName = _dataStr(message, 'senderName');
        if (convId.isNotEmpty && senderId.isNotEmpty) {
          _push((_) => ChatScreen(
                conversationId: convId,
                otherUserId: senderId,
                otherName: senderName.isNotEmpty ? senderName : '—',
              ));
        } else {
          _push((_) => const ConversationsScreen());
        }
      case 'kudos':
      // Notifications sociales (likes/commentaires/réponses/mentions de posts & commentaires) :
      // toutes mènent à l'onglet Communauté. Le payload FCM ne porte que `type` (pas d'id de post/
      // commentaire), donc on ne peut pas deep-linker plus fin pour l'instant — voir compte-rendu.
      case 'post-kudos':
      case 'comment':
      case 'comment-kudos':
      case 'comment-reply':
      case 'mention':
        goToTab(_Tab.community);
      case 'rank-overtaken':
      case 'near-rank':
        goToTab(_Tab.leaderboard);
      case 'stale-attribute':
        goToTab(_Tab.sessions);
      case 'weekly-recap':
        goToTab(_Tab.home);
      default:
        // Type absent ou inconnu → Accueil par défaut (état dégradé géré, pas de crash).
        goToTab(_Tab.home);
    }
  }

  /// Empile un écran sur le navigator global, en revenant d'abord à la racine de la coquille pour
  /// éviter d'accumuler les routes. No-op si le navigator n'est pas encore monté.
  void _push(WidgetBuilder builder) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute<void>(builder: builder));
  }

  /// `type` normalisé (chaîne ou vide) — `message.data` est un `Map<String, dynamic>`.
  String _typeOf(RemoteMessage message) => _dataStr(message, 'type');

  /// Lit une clé STRING du bloc `data` du push (FCM impose des strings), ou '' si absente/non-string.
  String _dataStr(RemoteMessage message, String key) {
    final raw = message.data[key];
    return raw is String ? raw : '';
  }

  /// Titre de repli si la notif n'a pas de bloc `notification` (data-only) au premier plan.
  String _fallbackTitle(String type) {
    switch (type) {
      case 'new-message':
        return 'Nouveau message';
      case 'kudos':
        return 'On a réagi à ta perf';
      case 'post-kudos':
        return 'On a applaudi ta publication';
      case 'comment':
        return 'Nouveau commentaire';
      case 'comment-kudos':
        return 'On a applaudi ton commentaire';
      case 'comment-reply':
        return 'Nouvelle réponse';
      case 'mention':
        return 'On t’a mentionné';
      case 'rank-overtaken':
        return 'On t’a doublé au classement';
      case 'near-rank':
        return 'Le prochain palier est tout proche';
      case 'stale-attribute':
        return 'Un de tes axes mérite un re-test';
      case 'weekly-recap':
        return 'Ta semaine en bref';
      default:
        return 'Athlete League';
    }
  }
}
