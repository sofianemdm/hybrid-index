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
                  style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
              const Spacer(),
              if (atMax)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Rang maximal',
                      style: HiType.label.copyWith(color: HiColors.brandPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(width: HiSpace.xs),
                  Icon(Icons.workspace_premium_rounded, size: 16, color: HiColors.brandPrimary),
                ])
              else
                Text('encore ${rp.pointsToNext} pts → ${HiLabels.rank(rp.next!)}',
                    style: HiType.body.copyWith(color: HiColors.textSecondary)),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(HiRadius.pill),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: HiColors.bgElevated2),
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = (c.maxWidth * visual).clamp(0.0, c.maxWidth);
                      return AnimatedContainer(
                        duration: HiMotion.base,
                        curve: HiMotion.enter,
                        width: w,
                        decoration: BoxDecoration(
                          color: HiColors.brandPrimary,
                          borderRadius: BorderRadius.circular(HiRadius.pill),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
