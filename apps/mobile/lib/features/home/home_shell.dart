import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../theme/tokens.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../log/log_wod_screen.dart';
import 'home_screen.dart';

/// Coquille principale : Accueil / Classement + bouton central « Logger un WOD ».
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  Future<void> _openLog() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LogWodScreen()),
    );
    if (changed == true) {
      ref.invalidate(myProfileProvider);
      ref.invalidate(rivalProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [HomeScreen(), LeaderboardScreen()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HiColors.brandPrimary,
        foregroundColor: HiColors.textOnBrand,
        onPressed: _openLog,
        icon: const Icon(Icons.add),
        label: const Text('Logger un WOD', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: HiColors.bgElevated,
        indicatorColor: HiColors.brandPrimary.withValues(alpha: 0.18),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'Classement'),
        ],
      ),
    );
  }
}
