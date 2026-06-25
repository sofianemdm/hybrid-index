import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

/// A21 — « Radar Insight » : traduit le radar en une phrase actionnable, juste sous le radar.
/// Met en avant les 2 points forts et le point faible à renforcer « pour devenir complet ».
/// Quand le radar est haut et équilibré, bascule en récompense « Athlète complet ».
class RadarInsight extends StatelessWidget {
  const RadarInsight({super.key, required this.radar});

  final List<RadarAttribute> radar;

  @override
  Widget build(BuildContext context) {
    final unlocked = radar.where((a) => a.unlocked).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    // Pas assez d'attributs débloqués pour un conseil pertinent.
    if (unlocked.length < 3) return const SizedBox.shrink();

    final weakest = unlocked.last;
    final maxScore = unlocked.first.score;
    final minScore = weakest.score;
    final balanced = minScore >= 60 && (maxScore - minScore) <= 12;

    final String text;
    final IconData icon;
    final Color accent;
    if (balanced) {
      icon = Icons.workspace_premium_rounded;
      accent = HiColors.brandSecondaryText;
      text = 'Athlète complet — ton radar est remarquablement équilibré. Tu incarnes l\'esprit hybride.';
    } else {
      icon = Icons.insights_rounded;
      accent = HiColors.brandPrimary;
      final top1 = HiLabels.attribute(unlocked[0].attribute);
      final top2 = HiLabels.attribute(unlocked[1].attribute);
      final weak = HiLabels.attribute(weakest.attribute);
      text = 'Tu brilles en $top1 et $top2. Renforce ton point faible — $weak — pour devenir complet.';
    }

    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: HiSpace.sm),
          Expanded(
            child: Text(
              text,
              style: HiType.body.copyWith(color: HiColors.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
