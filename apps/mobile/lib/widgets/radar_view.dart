import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

/// Radar des 6 attributs + liste lisible dessous (alternative non-couleur, a11y).
class RadarView extends StatelessWidget {
  final List<RadarAttribute> radar;
  const RadarView({super.key, required this.radar});

  @override
  Widget build(BuildContext context) {
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
                  entryRadius: 3,
                  dataEntries: radar
                      .map((a) => RadarEntry(value: a.unlocked ? a.score.toDouble() : 0))
                      .toList(),
                ),
              ],
              radarBackgroundColor: Colors.transparent,
              radarBorderData: const BorderSide(color: HiColors.strokeSubtle, width: 1),
              gridBorderData: const BorderSide(color: HiColors.strokeSubtle, width: 1),
              tickBorderData: const BorderSide(color: Colors.transparent),
              ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
              tickCount: 4,
              titlePositionPercentageOffset: 0.18,
              titleTextStyle: const TextStyle(color: HiColors.textSecondary, fontSize: 11),
              getTitle: (index, angle) {
                final a = radar[index % radar.length];
                return RadarChartTitle(text: HiLabels.attribute(a.attribute));
              },
            ),
          ),
        ),
        const SizedBox(height: HiSpace.md),
        ...radar.map(_attrRow),
      ],
    );
  }

  Widget _attrRow(RadarAttribute a) {
    final color = a.unlocked ? HiColors.attribute(a.attribute) : HiColors.attrLocked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(a.unlocked ? Icons.circle : Icons.lock, size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              HiLabels.attribute(a.attribute),
              style: const TextStyle(color: HiColors.textSecondary, fontSize: 14),
            ),
          ),
          if (a.isEstimated)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('estimé', style: TextStyle(color: HiColors.warn, fontSize: 11)),
            ),
          Text(
            a.unlocked ? '${a.score}' : '—',
            style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
