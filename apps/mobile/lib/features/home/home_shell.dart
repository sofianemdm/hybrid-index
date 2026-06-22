import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../theme/tokens.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../log/log_wod_screen.dart';
import '../progression/progression_screen.dart';
import '../community/community_tab.dart';
import '../wods/wod_tab.dart';
import '../wods/wod_builder_screen.dart';
import 'home_screen.dart';

/// Coquille principale : Accueil / Classement + bouton central « Logger une séance ».
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  Future<void> _openLog() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.build, color: HiColors.brandPrimary),
              title: Text('Construire une séance', style: TextStyle(color: HiColors.textPrimary)),
              subtitle: Text('Compose ta propre séance, estimée automatiquement', style: TextStyle(color: HiColors.textTertiary)),
              onTap: () => Navigator.of(context).pop('build'),
            ),
            ListTile(
              leading: Icon(Icons.timer_outlined, color: HiColors.brandPrimary),
              title: Text('Ajouter une séance rapidement', style: TextStyle(color: HiColors.textPrimary)),
              subtitle: Text('Choisis une séance de référence, vois comment la faire et enregistre ton résultat', style: TextStyle(color: HiColors.textTertiary)),
              onTap: () => Navigator.of(context).pop('log'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final route = choice == 'build'
        ? MaterialPageRoute<bool>(builder: (_) => const WodBuilderScreen())
        : MaterialPageRoute<bool>(builder: (_) => const LogWodScreen());
    final changed = await Navigator.of(context).push<bool>(route);
    if (changed == true || choice == 'build') {
      ref.invalidate(myProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [HomeScreen(), WodTab(), CommunityTab(), ProgressionScreen(), LeaderboardScreen()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HiColors.brandPrimary,
        foregroundColor: HiColors.textOnBrand,
        onPressed: _openLog,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une séance', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: HiColors.bgElevated,
        indicatorColor: HiColors.brandPrimary.withValues(alpha: 0.18),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Séances'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Communauté'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Progrès'),
          NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'Classement'),
        ],
      ),
    );
  }
}
