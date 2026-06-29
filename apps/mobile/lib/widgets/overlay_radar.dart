import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

/// Deux radars superposés : toi (cyan plein) vs un autre athlète (violet contour).
class OverlayRadar extends StatelessWidget {
  final List<RadarAttribute> mine;
  final List<RadarAttribute> other;
  const OverlayRadar({super.key, required this.mine, required this.other});

  @override
  Widget build(BuildContext context) {
    // On aligne les deux séries sur le MÊME ordre d'attributs (celui de `mine`),
    // en indexant l'adversaire par clé d'attribut — sinon les sommets seraient mal appariés.
    final otherByKey = {for (final a in other) a.attribute: a};
    double v(RadarAttribute? a) => (a != null && a.unlocked) ? a.score.toDouble() : 0;

    // fl_chart exige au moins 3 sommets ; le radar canonique en a 6, on garde une garde de sécurité.
    if (mine.length < 3) {
      return SizedBox(
        height: 120,
        child: Center(child: Text('Radar indisponible', style: TextStyle(color: HiColors.textTertiary))),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              dataSets: [
                RadarDataSet(
                  fillColor: HiColors.brandPrimary.withValues(alpha: 0.18),
                  borderColor: HiColors.brandPrimary,
                  borderWidth: 2,
                  entryRadius: 2,
                  dataEntries: mine.map((a) => RadarEntry(value: v(a))).toList(),
                ),
                RadarDataSet(
                  fillColor: Colors.transparent,
                  borderColor: HiColors.brandSecondary,
                  borderWidth: 2,
                  entryRadius: 2,
                  dataEntries: mine.map((a) => RadarEntry(value: v(otherByKey[a.attribute]))).toList(),
                ),
              ],
              radarBackgroundColor: Colors.transparent,
              radarBorderData: BorderSide(color: HiColors.strokeSubtle, width: 1),
              gridBorderData: BorderSide(color: HiColors.strokeSubtle, width: 1),
              tickBorderData: const BorderSide(color: Colors.transparent),
              ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
              tickCount: 4,
              titlePositionPercentageOffset: 0.18,
              titleTextStyle: HiType.caption.copyWith(color: HiColors.textSecondary, fontSize: 11),
              getTitle: (index, angle) => RadarChartTitle(text: HiLabels.attribute(mine[index % mine.length].attribute)),
            ),
          ),
        ),
        const SizedBox(height: HiSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend('Toi', HiColors.brandPrimary),
            const SizedBox(width: HiSpace.lg),
            _legend('Lui/Elle', HiColors.brandSecondary),
          ],
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: HiType.caption.copyWith(color: HiColors.textSecondary)),
        ],
      );
}
