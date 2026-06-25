import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:avatar_maker/avatar_maker.dart';

import 'app.dart';
import 'data/analytics.dart';
import 'data/locale_mode.dart';
import 'data/push_service.dart';
import 'data/session.dart';
import 'data/theme_mode.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/celebration.dart';

void main() {
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
    // Push : prêt mais inactif (no-op tant que Env.pushEnabled est faux).
    Future.microtask(() => PushService(ref.read(apiClientProvider)).init());
    Analytics.capture('app_open');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nouveau « passage » dans l'app → on ré-autorise une célébration FORTE (anti-fatigue : 1/session).
    if (state == AppLifecycleState.resumed) Celebration.resetSession();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return AvatarMakerProvider(child: MaterialApp(
      title: 'Athlete League',
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
      home: const AuthGate(),
    ));
  }
}
