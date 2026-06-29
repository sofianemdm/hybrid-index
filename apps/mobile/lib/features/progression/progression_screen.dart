import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/hi_skeleton.dart';
import '../challenge/challenge_screen.dart';
import '../endgame/endgame_screen.dart';
import '../history/history_screen.dart';

/// Progression : défi de la semaine + Grand Chelem + badges débloqués.
class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  late Future<List<BadgeModel>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(apiClientProvider).badges();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _future;
        },
        child: FutureBuilder<List<BadgeModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const HiListSkeleton(count: 6, itemHeight: 64);
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: HiSpace.xl),
                  child: ErrorRetry(onRetry: () => setState(_load)),
                ),
              ]);
            }
            final badges = snap.data!;
            final visible = _visibleBadges(badges);
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                Text(t.progressionTitle, style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.md),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: HiColors.strokeStrong),
                    foregroundColor: HiColors.textPrimary,
                  ),
                  icon: const Icon(Icons.history),
                  label: Text(t.progressionHistoryButton),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
                const SizedBox(height: HiSpace.md),
                const ChallengeBanner(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: HiColors.strokeStrong),
                    foregroundColor: HiColors.attrSpeed,
                  ),
                  icon: const Icon(Icons.emoji_events),
                  label: Text(t.progressionEndgameButton),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EndgameScreen()),
                  ),
                ),
                const SizedBox(height: HiSpace.lg),
                Text(t.progressionBadges(badges.where((b) => b.unlocked).length, badges.length),
                    style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                Text(t.progressionBadgesHint,
                    style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
                const SizedBox(height: HiSpace.sm),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: visible.map(_badgeTile).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  /// Réduit les séries progressives : par série, on ne montre que le palier le plus haut
  /// atteint + le prochain à débloquer. Les badges isolés (sans série) sont tous affichés.
  List<BadgeModel> _visibleBadges(List<BadgeModel> all) {
    final result = <BadgeModel>[];
    final bySeries = <String, List<BadgeModel>>{};
    for (final b in all) {
      final s = b.series;
      if (s == null) {
        result.add(b);
      } else {
        bySeries.putIfAbsent(s, () => []).add(b);
      }
    }
    for (final group in bySeries.values) {
      group.sort((a, b) => a.seriesOrder.compareTo(b.seriesOrder));
      final unlocked = group.where((b) => b.unlocked).toList();
      if (unlocked.isEmpty) {
        result.add(group.first); // aucun atteint → premier palier à viser
        continue;
      }
      final current = unlocked.last; // plus haut palier atteint
      result.add(current);
      final next = group.where((b) => !b.unlocked && b.seriesOrder > current.seriesOrder);
      if (next.isNotEmpty) result.add(next.first); // prochain à débloquer
    }
    return result;
  }

  Widget _badgeTile(BadgeModel b) {
    final t = AppLocalizations.of(context);
    final color = _rarityColor(b.rarity);
    final on = b.unlocked;
    // a11y : tuile de badge énoncée avec son état (débloqué / verrouillé) + sa description.
    return Semantics(
      label: '${t.a11yBadge(b.name)}, ${on ? t.a11yUnlocked : t.a11yLocked}. ${b.description}',
      child: ExcludeSemantics(
      child: Container(
      padding: const EdgeInsets.all(HiSpace.sm),
      decoration: BoxDecoration(
        color: on ? color.withValues(alpha: 0.12) : HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: on ? color.withValues(alpha: 0.6) : HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          Icon(on ? Icons.military_tech : Icons.lock_outline, color: on ? color : HiColors.textTertiary, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: on ? HiColors.textPrimary : HiColors.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(b.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: HiColors.textTertiary, fontSize: 11, height: 1.1)),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Color _rarityColor(String r) {
    switch (r) {
      case 'legendary':
        return HiColors.attrPower;
      case 'epic':
        return HiColors.brandSecondary;
      case 'rare':
        return HiColors.brandPrimary;
      default:
        return HiColors.textSecondary;
    }
  }
}
