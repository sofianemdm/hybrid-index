import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

/// Barre « prochain rang » (goal-gradient). Jamais vide : un sliver minimum reste visible
/// même près de 0, mais le NOMBRE de points affiché reste honnête (vrai pointsToNext).
class RankProgressBar extends StatelessWidget {
  final RankProgress rp;
  const RankProgressBar({super.key, required this.rp});

  @override
  Widget build(BuildContext context) {
    final atMax = rp.next == null;
    // Honnête : la valeur affichée est le vrai pointsToNext ; seul le remplissage a un plancher visuel.
    final visual = atMax ? 1.0 : rp.progress.clamp(0.05, 1.0);

    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(HiLabels.rank(rp.current),
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (atMax)
                Text('Rang maximal 👑',
                    style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w700, fontSize: 13))
              else
                Text('encore ${rp.pointsToNext} pts → ${HiLabels.rank(rp.next!)}',
                    style: TextStyle(color: HiColors.textSecondary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(HiRadius.pill),
            child: LinearProgressIndicator(
              value: visual,
              minHeight: 8,
              backgroundColor: HiColors.bgElevated2,
              valueColor: AlwaysStoppedAnimation(HiColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
