import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../challenge/challenge_screen.dart';
import '../endgame/endgame_screen.dart';

/// Progression : défi de la semaine + Grand Chelem + badges débloqués.
class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  late Future<List<BadgeModel>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(apiClientProvider).badges();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<BadgeModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text('${snap.error}', style: TextStyle(color: HiColors.error)),
                ),
              ]);
            }
            final badges = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                Text('Progression',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.md),
                const ChallengeBanner(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: HiColors.strokeStrong),
                    foregroundColor: HiColors.attrSpeed,
                  ),
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Endgame — Grand Chelem & rang mondial'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EndgameScreen()),
                  ),
                ),
                const SizedBox(height: HiSpace.lg),
                Text('Badges (${badges.where((b) => b.unlocked).length}/${badges.length})',
                    style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: HiSpace.sm),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: badges.map(_badgeTile).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
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
                    style: TextStyle(color: HiColors.textTertiary, fontSize: 11, height: 1.1)),
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
