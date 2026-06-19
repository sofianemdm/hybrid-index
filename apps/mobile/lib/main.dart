import 'package:flutter/material.dart';

import 'core/env.dart';

void main() {
  runApp(const HybridIndexApp());
}

/// Squelette de l'app (incrément 0). Le design system (thème sombre « feel jeu »,
/// tokens) et les features (onboarding, home, wod, radar...) arrivent aux incréments suivants
/// — cf. docs/design-system.md et docs/architecture.md §1.2.
class HybridIndexApp extends StatelessWidget {
  const HybridIndexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HYBRID INDEX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('HYBRID INDEX', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('api: ${Env.apiBaseUrl}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
