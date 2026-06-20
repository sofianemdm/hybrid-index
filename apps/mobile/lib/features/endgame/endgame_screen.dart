import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';

/// Endgame : Grand Chelem (battre le pro sur les 15 WODs), classement mondial, ambassadeur.
class EndgameScreen extends ConsumerStatefulWidget {
  const EndgameScreen({super.key});

  @override
  ConsumerState<EndgameScreen> createState() => _EndgameScreenState();
}

class _EndgameScreenState extends ConsumerState<EndgameScreen> {
  late Future<EndgameInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).endgame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Endgame'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<EndgameInfo>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('${snap.error}', style: const TextStyle(color: HiColors.error)));
            }
            final e = snap.data!;
            final progress = e.total == 0 ? 0.0 : e.beaten / e.total;
            return ListView(
              padding: const EdgeInsets.all(HiSpace.lg),
              children: [
                // Grand Chelem
                Container(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  decoration: BoxDecoration(
                    color: HiColors.bgElevated,
                    borderRadius: BorderRadius.circular(HiRadius.lg),
                    border: Border.all(color: HiColors.attrSpeed.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, color: HiColors.attrSpeed),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Grand Chelem',
                                style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
                          ),
                          Text('${e.beaten}/${e.total}',
                              style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Bats le temps/score « pro » sur les 15 WODs de référence.',
                          style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: HiSpace.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(HiRadius.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: HiColors.bgElevated2,
                          valueColor: AlwaysStoppedAnimation(
                              e.grandSlamComplete ? HiColors.attrSpeed : HiColors.brandPrimary),
                        ),
                      ),
                      if (e.grandSlamComplete) ...[
                        const SizedBox(height: HiSpace.md),
                        const Text('🏆 Grand Chelem complété — statut Ambassadeur débloqué !',
                            style: TextStyle(color: HiColors.attrSpeed, fontWeight: FontWeight.w700)),
                      ] else if (e.remaining.isNotEmpty) ...[
                        const SizedBox(height: HiSpace.md),
                        const Text('Il te reste :', style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: e.remaining
                              .map((name) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: HiColors.bgElevated2,
                                      borderRadius: BorderRadius.circular(HiRadius.pill),
                                    ),
                                    child: Text(name, style: const TextStyle(color: HiColors.textTertiary, fontSize: 11)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: HiSpace.md),
                // Classement mondial
                _statCard(
                  icon: Icons.public,
                  color: HiColors.brandPrimary,
                  title: 'Classement mondial',
                  value: e.globalRank != null ? '#${e.globalRank} / ${e.globalTotal}' : '—',
                  highlight: e.isTop100 ? 'Top 100 mondial 🌍' : null,
                ),
                const SizedBox(height: HiSpace.md),
                _statCard(
                  icon: Icons.workspace_premium,
                  color: HiColors.brandSecondaryText,
                  title: 'Statut Ambassadeur',
                  value: e.ambassador ? 'Débloqué ✓' : 'Verrouillé',
                  highlight: e.ambassador ? 'Tu représentes l’élite HYBRID INDEX' : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    String? highlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                Text(value, style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
                if (highlight != null)
                  Text(highlight, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
