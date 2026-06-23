import 'package:flutter/material.dart';

import '../data/models.dart';
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
    return Tooltip(
      message: _detail(),
      child: GestureDetector(
        onTap: () {
          HiHaptics.tap();
          _showSheet(context);
        },
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
    );
  }

  String _detail() {
    if (streak.weekValidated) return 'Semaine validée ✅ — série de ${streak.current}';
    final left = (streak.weeklyGoal - streak.thisWeekCount).clamp(0, streak.weeklyGoal);
    return left == 0
        ? 'Série de ${streak.current} semaines'
        : 'Encore $left séance${left > 1 ? 's' : ''} pour valider ta semaine';
  }

  void _showSheet(BuildContext context) {
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
                Text('Ta série', style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
              ],
            ),
            const SizedBox(height: HiSpace.md),
            Text(
              streak.current > 0
                  ? '${streak.current} semaine${streak.current > 1 ? 's' : ''} active${streak.current > 1 ? 's' : ''} d\'affilée. '
                      'Une semaine compte dès ${streak.weeklyGoal} séances.'
                  : 'Fais ${streak.weeklyGoal} séances cette semaine pour démarrer ta série.',
              style: HiType.body.copyWith(color: HiColors.textSecondary),
            ),
            const SizedBox(height: HiSpace.sm),
            _row('Cette semaine', '${streak.thisWeekCount}/${streak.weeklyGoal}'),
            _row('Record', '${streak.best} sem.'),
            if (streak.freezeTokens > 0)
              _row('Jetons de repos', '${streak.freezeTokens} 🛡️', hint: 'Protègent une semaine ratée.'),
            const SizedBox(height: HiSpace.md),
            Text('Pas de pression : rater une semaine ne fait jamais baisser ton Index.',
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
