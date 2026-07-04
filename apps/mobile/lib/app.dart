import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/models.dart';
import 'data/realtime_service.dart';
import 'data/session.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'l10n/app_localizations.dart';
import 'theme/tokens.dart';
import 'widgets/error_retry.dart';

/// Navigator global de l'app (branché sur [MaterialApp.navigatorKey] dans main.dart).
/// Permet de naviguer SANS `BuildContext` — indispensable pour router un tap sur une notification
/// FCM (le handler n'a pas de contexte d'écran). Voir `data/push_service.dart`.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Messenger global (branché sur [MaterialApp.scaffoldMessengerKey] dans main.dart) → permet
/// d'afficher une bannière/snackbar in-app NON bloquante sans `BuildContext`, p. ex. lorsqu'une
/// notification FCM arrive alors que l'app est au premier plan. Voir `data/push_service.dart`.
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Profil de l'utilisateur connecté (Index + radar). `null` = onboarding non terminé.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return null;
  return ref.read(apiClientProvider).myProfile();
});

/// Avatar de l'utilisateur connecté (valeurs par défaut si jamais personnalisé).
final avatarProvider = FutureProvider<AvatarConfig>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) {
    return const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);
  }
  return ref.read(apiClientProvider).getAvatar();
});

/// Badges gagnés (forme compacte pour la carte de joueur). Tolérant : [] si erreur/déconnecté.
final cardBadgesProvider = FutureProvider<List<CardBadge>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return const [];
  try {
    return await ref.read(apiClientProvider).badgesCard();
  } catch (_) {
    return const [];
  }
});

/// Série hebdomadaire (semaines actives). `null` si déconnecté. Tolérant : renvoie null en cas
/// d'erreur réseau (la flamme est non bloquante, jamais une raison d'échec d'écran).
final streakProvider = FutureProvider<StreakState?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return null;
  try {
    return await ref.read(apiClientProvider).streak();
  } catch (_) {
    return null;
  }
});

/// Récap de la semaine en cours. Non bloquant (null si erreur/déconnecté).
final weeklyRecapProvider = FutureProvider<WeeklyRecap?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return null;
  try {
    return await ref.read(apiClientProvider).weeklyRecap();
  } catch (_) {
    return null;
  }
});

/// Historique de l'Index (pour la projection « à ce rythme, X+ dans N sem »). Tolérant.
final indexHistoryProvider = FutureProvider<List<IndexPoint>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return const [];
  try {
    return await ref.read(apiClientProvider).history();
  } catch (_) {
    return const [];
  }
});

/// Nombre total de messages NON LUS (somme sur les conversations) → pastille rouge sur l'icône
/// messages. Invalidé à l'ouverture/fermeture des conversations. Tolérant (0 si erreur).
final unreadMessagesProvider = FutureProvider<int>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) return 0;
  try {
    final convos = await ref.read(apiClientProvider).conversations();
    return convos.fold<int>(0, (sum, c) => sum + c.unread);
  } catch (_) {
    return 0;
  }
});

/// Id de la conversation actuellement OUVERTE à l'écran (chat au premier plan), ou `null` si
/// l'utilisateur n'est dans aucun chat. Posé par `ChatScreen` à son `initState`/`dispose`. Sert au
/// bandeau in-app temps réel ([RealtimeBanner]) à NE PAS notifier un message de la conversation déjà
/// affichée (sinon doublon visuel : la bulle apparaît ET un bandeau s'affiche pour le même message).
final activeConversationProvider = StateProvider<String?>((ref) => null);

/// État du cycle de vie de l'app, alimenté par l'observateur global de [main.dart]
/// (`didChangeAppLifecycleState`). Permet aux providers à scrutation périodique (ex.
/// [inboxBadgeProvider]) de SUSPENDRE leur poll quand l'app n'est pas au premier plan,
/// comme le fait déjà le chat — on n'interroge pas le réseau en arrière-plan.
final appLifecycleProvider = StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);

/// Pastille « boîte de réception » de la CLOCHE = messages non lus + invitations de club en attente.
///
/// TEMPS RÉEL D'ABORD : on s'abonne au flux WebSocket ([realtimeServiceProvider]). Dès qu'un
/// événement `dm` arrive — MÊME hors écran messagerie — on refetch IMMÉDIATEMENT le compteur, donc
/// la pastille bouge en quasi-instantané côté destinataire (plus d'attente de ~1 min). Le polling
/// REST RESTE un repli : intervalle court (4 s) quand le WS est DOWN, long (20 s) quand il est UP
/// (le WS porte alors l'instantanéité). Le poll se met en PAUSE en arrière-plan (cf. chat_screen).
final inboxBadgeProvider = StreamProvider.autoDispose<int>((ref) async* {
  final session = ref.watch(sessionProvider);
  if (session.status != AuthStatus.loggedIn) {
    yield 0;
    return;
  }
  final api = ref.read(apiClientProvider);
  final realtime = ref.read(realtimeServiceProvider);

  // Réveil immédiat du poll sur événement temps réel : un `dm` reçu complète le `Completer` courant
  // → on sort tout de suite de l'attente et on refetch (badge à jour sans attendre le prochain cycle).
  Completer<void>? wake;
  final rtSub = realtime.events.listen((e) {
    final w = wake;
    if (e is DmReceived && w != null && !w.isCompleted) w.complete();
  });
  ref.onDispose(rtSub.cancel);

  while (true) {
    // Hors premier plan : on ne scrute pas. On attend le retour au premier plan avant de reprendre
    // (un `await` sur le changement d'état évite tout poll réseau en arrière-plan).
    if (ref.read(appLifecycleProvider) != AppLifecycleState.resumed) {
      final completer = Completer<void>();
      final sub = ref.listen<AppLifecycleState>(appLifecycleProvider, (_, next) {
        if (next == AppLifecycleState.resumed && !completer.isCompleted) completer.complete();
      });
      await completer.future;
      sub.close();
    }
    var count = 0;
    try {
      final convos = await api.conversations();
      count += convos.fold<int>(0, (sum, c) => sum + c.unread);
    } catch (_) {/* réseau : on garde le reste */}
    try {
      final invites = await api.myClubInvites();
      count += invites.length;
    } catch (_) {/* réseau */}
    yield count;

    // Attente jusqu'au prochain cycle OU jusqu'à un événement temps réel (le premier qui survient).
    // Repli plus réactif quand le WS est down ; rythme détendu quand il porte déjà l'instantanéité.
    final pollDelay = realtime.isConnected
        ? const Duration(seconds: 20)
        : const Duration(seconds: 4);
    final w = Completer<void>();
    wake = w;
    final timer = Timer(pollDelay, () {
      if (!w.isCompleted) w.complete();
    });
    await w.future;
    timer.cancel();
    wake = null;
  }
});

/// Point d'entrée logique : décide quel écran montrer selon l'état d'auth + onboarding.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sessionProvider.select((s) => s.status));

    switch (status) {
      case AuthStatus.loading:
        return const _Splash();
      case AuthStatus.loggedOut:
        return const AuthScreen();
      case AuthStatus.loggedIn:
        final profile = ref.watch(myProfileProvider);
        return profile.when(
          loading: () => const _Splash(),
          // Erreur de chargement du profil : Réessayer + PORTE DE SORTIE « Se déconnecter »
          // (sinon un jeton bloquant enferme l'utilisateur dans l'écran d'erreur à chaque visite).
          error: (e, _) {
            // ignore: avoid_print
            print('DIAG AuthGate ErrorRetry cause: ${e.runtimeType} : $e');
            return Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: ErrorRetry(onRetry: () => ref.invalidate(myProfileProvider))),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: TextButton(
                    onPressed: () async {
                      await ref.read(sessionProvider.notifier).logout();
                      ref.invalidate(myProfileProvider);
                    },
                    child: Text(AppLocalizations.of(context).settingsSignOut,
                        style: TextStyle(color: HiColors.textTertiary)),
                  ),
                ),
              ],
            ),
          );
          },
          data: (p) => p == null ? const OnboardingScreen() : const HomeShell(),
        );
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ATHLETE LEAGUE',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3, color: HiColors.textPrimary)),
            const SizedBox(height: 20),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: HiColors.brandPrimary, strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}
