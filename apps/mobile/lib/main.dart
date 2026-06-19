import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/session.dart';
import 'theme/app_theme.dart';

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
    return MaterialApp(
      title: 'HYBRID INDEX',
      debugShowCheckedModeBanner: false,
      theme: buildHiTheme(),
      home: const AuthGate(),
    );
  }
}
