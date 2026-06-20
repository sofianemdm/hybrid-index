import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/index_ring.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/rank_badge.dart';
import '../../widgets/rank_progress_bar.dart';
import '../../widgets/social_proof_card.dart';

/// L'écran « waouh » : l'Index se remplit, le rang et le radar apparaissent.
class RevealScreen extends ConsumerWidget {
  final Profile profile;
  const RevealScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = profile.index;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HiSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const SizedBox(height: HiSpace.md),
                  const Text('TON HYBRID INDEX',
                      style: TextStyle(color: HiColors.textSecondary, letterSpacing: 3, fontSize: 13)),
                  const SizedBox(height: HiSpace.lg),
                  IndexRing(value: idx.value, percentile: idx.percentile),
                  const SizedBox(height: HiSpace.lg),
                  RankBadge(rank: idx.rank, fontSize: 15),
                  if (idx.isProvisional) ...[
                    const SizedBox(height: HiSpace.sm),
                    const Text('Index provisoire — affine-le en loggant plus de WODs.',
                        textAlign: TextAlign.center, style: TextStyle(color: HiColors.warn, fontSize: 12)),
                  ],
                  if (idx.rankProgress != null) ...[
                    const SizedBox(height: HiSpace.lg),
                    RankProgressBar(rp: idx.rankProgress!),
                  ],
                  if (profile.socialProof != null) ...[
                    const SizedBox(height: HiSpace.lg),
                    SocialProofCard(proof: profile.socialProof!),
                  ],
                  const SizedBox(height: HiSpace.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(HiSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ton radar',
                              style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: HiSpace.sm),
                          RadarView(radar: profile.radar),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: HiSpace.lg),
                  HiButton(
                    label: 'Voir mon profil',
                    onPressed: () {
                      ref.invalidate(myProfileProvider);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                  const SizedBox(height: HiSpace.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
