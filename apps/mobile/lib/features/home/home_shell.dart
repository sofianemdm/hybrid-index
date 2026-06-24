import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/session.dart';
import '../../data/ui_state.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../log/log_wod_screen.dart';
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
  // L'onglet actif vit dans homeTabProvider (partagé) pour pouvoir y revenir depuis ailleurs.

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
    final t = AppLocalizations.of(context);
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
              Text(t.homeAddSessionTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: HiSpace.lg),
              _choiceCard(ctx,
                  icon: Icons.timer_outlined,
                  title: t.homeAddQuickTitle,
                  subtitle: t.homeAddQuickSubtitle,
                  value: 'log'),
              const SizedBox(height: HiSpace.md),
              _choiceCard(ctx,
                  icon: Icons.build,
                  title: t.homeBuildSessionTitle,
                  subtitle: t.homeBuildSessionSubtitle,
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
    final t = AppLocalizations.of(context);
    final tab = ref.watch(homeTabProvider);
    return Scaffold(
      extendBody: true, // le contenu glisse sous la barre translucide
      body: IndexedStack(
        index: tab,
        // 4 onglets (Progression sortie de la barre → accessible via la carte Index de l'Accueil).
        children: const [HomeScreen(), WodTab(), CommunityTab(), LeaderboardScreen()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: HiShadow.glowBrand(0.4)),
        child: FloatingActionButton(
          backgroundColor: HiColors.brandPrimary,
          foregroundColor: HiColors.textOnBrand,
          elevation: 0,
          shape: const CircleBorder(),
          tooltip: t.homeAddSessionTitle,
          onPressed: () {
            HiHaptics.tap();
            _openLog();
          },
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      bottomNavigationBar: _notchedNav(t),
    );
  }

  /// Barre de navigation à encoche (4 onglets + action centrale dockée) — pattern AAA (Strava/IG).
  Widget _notchedNav(AppLocalizations t) {
    final tabs = <(IconData, IconData, String, int)>[
      (Icons.bolt_outlined, Icons.bolt_rounded, t.navHome, 0),
      (Icons.fitness_center_outlined, Icons.fitness_center_rounded, t.navSessions, 1),
      (Icons.groups_outlined, Icons.groups_rounded, t.navCommunity, 2),
      (Icons.leaderboard_outlined, Icons.leaderboard_rounded, t.navLeaderboard, 3),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HiSpace.md, 0, HiSpace.md, HiSpace.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(HiRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: BottomAppBar(
              color: HiColors.bgElevated2.withValues(alpha: 0.86),
              elevation: 0,
              height: 64,
              padding: EdgeInsets.zero,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              child: Row(
                children: [
                  Expanded(child: _navItem(tabs[0])),
                  Expanded(child: _navItem(tabs[1])),
                  const SizedBox(width: 64), // place de l'encoche / FAB central
                  Expanded(child: _navItem(tabs[2])),
                  Expanded(child: _navItem(tabs[3])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem((IconData, IconData, String, int) tab) {
    final i = tab.$4;
    final active = ref.watch(homeTabProvider) == i;
    final color = active ? HiColors.brandPrimary : HiColors.textTertiary;
    return Semantics(
      label: tab.$3,
      selected: active,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HiHaptics.tap();
          ref.read(homeTabProvider.notifier).state = i;
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.0 : 0.9,
              duration: HiMotion.fast,
              curve: Curves.easeOut,
              child: Icon(active ? tab.$2 : tab.$1, color: color, size: 23),
            ),
            const SizedBox(height: 2),
            Text(tab.$3,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: HiType.caption.copyWith(
                    color: color, fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
