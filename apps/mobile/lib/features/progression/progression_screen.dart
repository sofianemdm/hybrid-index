import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../endgame/endgame_screen.dart';

/// Progression : série hebdomadaire (streak) + badges débloqués.
class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  late Future<({StreakState streak, List<BadgeModel> badges, List<IndexPoint> history})> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    _future = () async {
      final results = await Future.wait([api.streak(), api.badges(), api.history()]);
      return (
        streak: results[0] as StreakState,
        badges: results[1] as List<BadgeModel>,
        history: results[2] as List<IndexPoint>,
      );
    }();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<({StreakState streak, List<BadgeModel> badges, List<IndexPoint> history})>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text('${snap.error}', style: const TextStyle(color: HiColors.error)),
                ),
              ]);
            }
            final data = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                const Text('Progression',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.md),
                _indexCurveCard(data.history),
                const SizedBox(height: HiSpace.md),
                _streakCard(data.streak),
                const SizedBox(height: HiSpace.md),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: HiColors.strokeStrong),
                    foregroundColor: HiColors.attrSpeed,
                  ),
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Endgame — Grand Chelem & rang mondial'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EndgameScreen()),
                  ),
                ),
                const SizedBox(height: HiSpace.lg),
                Text('Badges (${data.badges.where((b) => b.unlocked).length}/${data.badges.length})',
                    style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: HiSpace.sm),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: data.badges.map(_badgeTile).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Courbe de progression personnelle de l'Hybrid Index (H3). Met en avant le progrès individuel.
  Widget _indexCurveCard(List<IndexPoint> history) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.lg),
        border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ta courbe Hybrid Index',
              style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: HiSpace.md),
          if (history.length < 2)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: HiSpace.md),
              child: Text('Logue 2-3 WODs pour voir ta progression se dessiner.',
                  style: TextStyle(color: HiColors.textTertiary)),
            )
          else
            SizedBox(height: 180, child: LineChart(_chartData(history))),
          if (history.length >= 2) ...[
            const SizedBox(height: HiSpace.sm),
            Builder(builder: (_) {
              final gain = history.last.value - history.first.value;
              return Text(
                gain > 0 ? '📈 +$gain points depuis le début' : 'Continue à loguer pour faire grimper ta courbe',
                style: const TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              );
            }),
          ],
        ],
      ),
    );
  }

  LineChartData _chartData(List<IndexPoint> h) {
    final spots = <FlSpot>[
      for (var i = 0; i < h.length; i++) FlSpot(i.toDouble(), h[i].value.toDouble()),
    ];
    final values = h.map((p) => p.value).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 30).clamp(0, 1000).toDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 30).clamp(0, 1000).toDouble();
    return LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 200)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: HiColors.brandPrimary,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: HiColors.brandPrimary.withValues(alpha: 0.12)),
        ),
      ],
    );
  }

  Widget _streakCard(StreakState s) {
    final progress = s.weeklyGoal == 0 ? 0.0 : (s.thisWeekCount / s.weeklyGoal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.lg),
        border: Border.all(color: HiColors.warn.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: HiColors.warn, size: 32),
              const SizedBox(width: HiSpace.sm),
              Text('${s.current} sem.',
                  style: const TextStyle(color: HiColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('série en cours · record ${s.best}',
                  style: const TextStyle(color: HiColors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: HiSpace.md),
          Text('Cette semaine : ${s.thisWeekCount}/${s.weeklyGoal} WODs'
              '${s.weekValidated ? ' ✓ validée' : ''}',
              style: const TextStyle(color: HiColors.textSecondary)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(HiRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: HiColors.bgElevated2,
              valueColor: AlwaysStoppedAnimation(s.weekValidated ? HiColors.success : HiColors.brandPrimary),
            ),
          ),
          const SizedBox(height: HiSpace.md),
          Row(
            children: [
              const Icon(Icons.ac_unit, color: HiColors.info, size: 18),
              const SizedBox(width: 6),
              Text('${s.freezeTokens} jeton(s) de gel (protègent une semaine ratée)',
                  style: const TextStyle(color: HiColors.textTertiary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: HiSpace.md),
          Row(
            children: [
              const Expanded(child: Text('Objectif hebdo', style: TextStyle(color: HiColors.textSecondary, fontSize: 13))),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: HiColors.textSecondary, size: 20),
                onPressed: s.weeklyGoal > 2 ? () => _setGoal(s.weeklyGoal - 1) : null,
              ),
              Text('${s.weeklyGoal}', style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: HiColors.textSecondary, size: 20),
                onPressed: s.weeklyGoal < 5 ? () => _setGoal(s.weeklyGoal + 1) : null,
              ),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.beach_access, size: 18, color: HiColors.info),
            label: const Text('Marquer une semaine de repos', style: TextStyle(color: HiColors.info)),
            onPressed: _planRest,
          ),
        ],
      ),
    );
  }

  Future<void> _setGoal(int goal) async {
    try {
      await ref.read(apiClientProvider).updateStreak(weeklyGoal: goal);
      setState(_load);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _planRest() async {
    try {
      await ref.read(apiClientProvider).updateStreak(plannedRest: true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Semaine de repos planifiée — ta série est protégée.')));
        setState(_load);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _badgeTile(BadgeModel b) {
    final color = _rarityColor(b.rarity);
    final on = b.unlocked;
    return Container(
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
                    style: const TextStyle(color: HiColors.textTertiary, fontSize: 11, height: 1.1)),
              ],
            ),
          ),
        ],
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
