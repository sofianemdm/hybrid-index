import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/session.dart';
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

  /// Carte de choix bien visible (dialogue centré « Ajouter une séance »).
  Widget _choiceCard(BuildContext ctx,
      {required IconData icon, required String title, required String subtitle, required String value}) {
    return Material(
      color: HiColors.bgElevated2,
      borderRadius: BorderRadius.circular(HiRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(HiRadius.md),
        onTap: () => Navigator.of(ctx).pop(value),
        child: Container(
          padding: const EdgeInsets.all(HiSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HiRadius.md),
            border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.45), width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HiColors.brandPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(HiRadius.sm),
                ),
                child: Icon(icon, color: HiColors.brandPrimary),
              ),
              const SizedBox(width: HiSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: HiColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: HiColors.bgElevated,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(HiSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ajouter une séance',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: HiSpace.lg),
              _choiceCard(ctx,
                  icon: Icons.timer_outlined,
                  title: 'Ajouter une séance rapidement',
                  subtitle: 'Choisis une séance de référence',
                  value: 'log'),
              const SizedBox(height: HiSpace.md),
              _choiceCard(ctx,
                  icon: Icons.build,
                  title: 'Construire une séance',
                  subtitle: 'Compose ta propre séance, estimée automatiquement',
                  value: 'build'),
            ],
          ),
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
      ref.invalidate(completionPlanProvider);
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
