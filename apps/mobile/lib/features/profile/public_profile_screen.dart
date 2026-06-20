import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/index_ring.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/rank_badge.dart';

/// Profil public d'un autre athlète (tout est public) + comparaison avec le mien.
class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.read(apiClientProvider).publicProfile(userId);
    final mine = ref.watch(myProfileProvider).value;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<PublicProfile>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text('${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: HiColors.error)),
                ),
              );
            }
            final p = snap.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(HiSpace.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Text(p.displayName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${HiLabels.goal(p.goal)} · ${p.position != null ? '#${p.position} de sa ligue' : '—'}',
                        style: const TextStyle(color: HiColors.textSecondary)),
                    const SizedBox(height: HiSpace.lg),
                    if (p.index != null)
                      IndexRing(value: p.index!.value, percentile: p.index!.percentile, size: 200)
                    else
                      const Text('Pas encore d’Index.', style: TextStyle(color: HiColors.textTertiary)),
                    const SizedBox(height: HiSpace.md),
                    RankBadge(rank: p.rank, fontSize: 14),
                    const SizedBox(height: HiSpace.lg),
                    if (mine != null && p.index != null) _compareCard(mine, p),
                    const SizedBox(height: HiSpace.md),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(HiSpace.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Son radar',
                                style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: HiSpace.sm),
                            RadarView(radar: p.radar),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _compareCard(Profile mine, PublicProfile other) {
    final diff = mine.index.value - other.index!.value;
    final ahead = diff >= 0;
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: (ahead ? HiColors.success : HiColors.error).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ahead ? Icons.trending_up : Icons.trending_down,
              color: ahead ? HiColors.success : HiColors.error),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Text(
              ahead
                  ? 'Tu es devant de ${diff.abs()} points (toi ${mine.index.value} · lui ${other.index!.value}).'
                  : 'Il te devance de ${diff.abs()} points (toi ${mine.index.value} · lui ${other.index!.value}).',
              style: const TextStyle(color: HiColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
