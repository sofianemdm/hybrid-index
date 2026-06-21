import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/session.dart';
import 'data/theme_mode.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

void main() {
  runApp(const ProviderScope(child: HybridIndexApp()));
}

/// App HYBRID INDEX (iOS + Android, ici aussi Web pour la démo navigateur).
/// Le design system « feel jeu » sombre est défini dans theme/ ; l'app n'appelle que l'`api`.
class HybridIndexApp extends ConsumerStatefulWidget {
  const HybridIndexApp({super.key});

  @override
  ConsumerState<HybridIndexApp> createState() => _HybridIndexAppState();
}

class _HybridIndexAppState extends ConsumerState<HybridIndexApp> {
  @override
  void initState() {
    super.initState();
    // Restaure la session (token persisté) au démarrage.
    Future.microtask(() => ref.read(sessionProvider.notifier).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'HYBRID INDEX',
      debugShowCheckedModeBanner: false,
      theme: buildHiTheme(Brightness.light),
      darkTheme: buildHiTheme(Brightness.dark),
      themeMode: themeMode,
      // Synchronise la palette des tokens HiColors avec le thème RÉELLEMENT appliqué (système inclus)
      // AVANT que le sous-arbre ne se construise.
      builder: (context, child) {
        HiColors.active = Theme.of(context).brightness == Brightness.light ? kHiLight : kHiDark;
        return child!;
      },
      home: const AuthGate(),
    );
  }
}
