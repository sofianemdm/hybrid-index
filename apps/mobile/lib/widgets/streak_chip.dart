import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../theme/haptics.dart';
import '../theme/tokens.dart';

/// Flamme de série hebdomadaire — discrète (coin de l'accueil). Ton jamais culpabilisant :
/// affiche les semaines actives ; si la semaine en cours n'est pas validée, invite en douceur.
/// Masquée pour un compte tout neuf (current 0 ET aucune séance cette semaine).
class StreakChip extends StatelessWidget {
  final StreakState streak;
  const StreakChip({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final hidden = streak.current == 0 && streak.thisWeekCount == 0;
    if (hidden) return const SizedBox.shrink();

    const orange = HiColors.streakFlame;
    final active = streak.current > 0;
    final color = active ? orange : HiColors.textTertiary;
    final t = AppLocalizations.of(context);
    // a11y : bouton annoncé avec la valeur (« Série de N semaines ») ; cible tactile garantie ≥ 48dp.
    return Semantics(
      button: true,
      label: t.streakSheetTitle,
      value: '${streak.current}',
      child: Tooltip(
        message: _detail(context),
        child: GestureDetector(
          onTap: () {
            HiHaptics.tap();
            _showSheet(context);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: HiTap.minTarget, minHeight: HiTap.minTarget),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(HiRadius.pill),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(active ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                        color: color, size: 16),
                    const SizedBox(width: 4),
                    Text('${streak.current}', style: HiType.numericM.copyWith(color: color, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _detail(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (streak.weekValidated) return t.streakDetailValidated(streak.current);
    final left = (streak.weeklyGoal - streak.thisWeekCount).clamp(0, streak.weeklyGoal);
    return left == 0
        ? t.streakDetailSeries(streak.current)
        : t.streakDetailLeft(left);
  }

  void _showSheet(BuildContext context) {
    final t = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HiRadius.xxl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(HiSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: HiColors.streakFlame, size: 28),
                const SizedBox(width: HiSpace.sm),
                Text(t.streakSheetTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
              ],
            ),
            const SizedBox(height: HiSpace.md),
            Text(
              streak.current > 0
                  ? t.streakSheetActive(streak.current, streak.weeklyGoal)
                  : t.streakSheetStart(streak.weeklyGoal),
              style: HiType.body.copyWith(color: HiColors.textSecondary),
            ),
            const SizedBox(height: HiSpace.sm),
            _row(t.streakThisWeek, '${streak.thisWeekCount}/${streak.weeklyGoal}'),
            _row(t.streakBest, t.streakBestValue(streak.best)),
            if (streak.freezeTokens > 0)
              _row(t.streakFreezeTokens, '${streak.freezeTokens} 🛡️', hint: t.streakFreezeHint),
            const SizedBox(height: HiSpace.md),
            Text(t.streakNoPressure,
                style: HiType.caption.copyWith(color: HiColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
                if (hint != null) Text(hint, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
              ],
            ),
          ),
          Text(value, style: HiType.numericM.copyWith(color: HiColors.textSecondary)),
        ],
      ),
    );
  }
}
