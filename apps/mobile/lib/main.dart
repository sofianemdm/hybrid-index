import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_router.dart';
import 'data/analytics.dart';
import 'data/locale_mode.dart';
import 'data/push_service.dart';
import 'data/realtime_service.dart';
import 'data/session.dart';
import 'data/theme_mode.dart';
import 'data/ui_state.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/celebration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Crash reporting (Crashlytics) : toute erreur non gérée de l'APK est reportée à la console
  // Firebase (ligne exacte, modèle d'appareil, version) au lieu de disparaître en silence.
  await _initCrashReporting();
  // Garde-fou global : tout widget qui plante au build est remplacé par un message propre
  // (plus jamais le gros rouge « Unexpected null value » chez l'utilisateur). Wrappé dans une
  // Directionality pour fonctionner même hors d'un MaterialApp.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        alignment: Alignment.center,
        color: HiColors.bgBase,
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: HiColors.textTertiary, size: 30),
            const SizedBox(height: HiSpace.sm),
            Flexible(
              child: Text(
                'Oups, un souci d\'affichage ici.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HiColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  };
  runApp(const ProviderScope(child: HybridIndexApp()));
}

/// Branche Crashlytics — UNIQUEMENT sur l'APK release (jamais web, jamais debug : les sessions de
/// dev ne polluent pas les rapports). Best-effort : un échec d'init ne bloque JAMAIS le démarrage.
Future<void> _initCrashReporting() async {
  if (kIsWeb || !kReleaseMode) return;
  try {
    // Firebase peut déjà avoir été initialisé (ou le sera par PushService, qui se garde aussi).
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    // Erreurs du framework Flutter (build/layout/gesture) → rapport fatal.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Erreurs asynchrones hors framework (futures non attendues, zones) → rapport fatal.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true; // consommée : pas de double-report ni de kill du process par le handler défaut
    };
  } catch (e) {
    debugPrint('[crash] Crashlytics indisponible (app démarre normalement) : $e');
  }
}

/// Résout le code de langue ('fr' / 'en') à transmettre au backend pour les push localisés.
/// Priorité : choix explicite de l'utilisateur ([chosen]) ; sinon langue du système. Tout ce qui
/// n'est ni FR ni EN retombe sur 'fr' (seules langues supportées + repli serveur).
String _resolveLocaleCode(Locale? chosen) {
  final code = (chosen ?? WidgetsBinding.instance.platformDispatcher.locale).languageCode;
  return code == 'en' ? 'en' : 'fr';
}

/// App HYBRID INDEX (iOS + Android, ici aussi Web pour la démo navigateur).
/// Le design system « feel jeu » sombre est défini dans theme/ ; l'app n'appelle que l'`api`.
class HybridIndexApp extends ConsumerStatefulWidget {
  const HybridIndexApp({super.key});

  @override
  ConsumerState<HybridIndexApp> createState() => _HybridIndexAppState();
}

class _HybridIndexAppState extends ConsumerState<HybridIndexApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restaure la session (token persisté) au démarrage.
    Future.microtask(() => ref.read(sessionProvider.notifier).bootstrap());
    // Push : prêt mais inactif (no-op tant que Env.pushEnabled est faux). Le service route les taps
    // de notification via le navigator global + bascule l'onglet de la coquille (homeTabProvider).
    Future.microtask(
      () => PushService(
        ref.read(apiClientProvider),
        goToTab: (tab) => ref.read(homeTabProvider.notifier).state = tab,
        deviceLocale: _resolveLocaleCode(ref.read(localeProvider)),
      ).init(),
    );
    // Service WebSocket temps réel : on l'INSTANCIE ici (provider paresseux) pour activer ses
    // écoutes session/lifecycle. Purement additif — le polling REST reste en repli si le WS échoue.
    Future.microtask(() => ref.read(realtimeServiceProvider));
    Analytics.capture('app_open');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Publie l'état pour les providers à scrutation périodique (ex. inboxBadgeProvider) → ils
    // suspendent leur poll réseau en arrière-plan et le reprennent au retour au premier plan.
    ref.read(appLifecycleProvider.notifier).state = state;
    // Nouveau « passage » dans l'app → on ré-autorise une célébration FORTE (anti-fatigue : 1/session).
    if (state == AppLifecycleState.resumed) Celebration.resetSession();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    // MaterialApp.router (go_router) : les écrans clés ont une ADRESSE (/seance/fran, /profil/:id,
    // /conversation/:id, /ligue) → deep links, App Links Android, URLs web réelles. La clé du
    // Navigator (taps FCM) vit désormais dans le routeur (appRouter → appNavigatorKey).
    return MaterialApp.router(
      title: 'Athlete League',
      routerConfig: appRouter,
      scaffoldMessengerKey: appMessengerKey, // bannière in-app si une notif arrive app au premier plan
      debugShowCheckedModeBanner: false,
      theme: buildHiTheme(Brightness.light),
      darkTheme: buildHiTheme(Brightness.dark),
      themeMode: themeMode,
      locale: locale, // null = langue du système (FR/EN)
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Synchronise la palette des tokens HiColors avec le thème RÉELLEMENT appliqué (système inclus)
      // AVANT que le sous-arbre ne se construise.
      builder: (context, child) {
        HiColors.active = Theme.of(context).brightness == Brightness.light ? kHiLight : kHiDark;
        return child!;
      },
    );
  }
}
