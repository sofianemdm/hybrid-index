import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/rank_badge.dart';
import '../profile/public_profile_screen.dart';
import 'progress_board_screen.dart';

/// Classement public par ligue (Hommes / Femmes), trié par HYBRID INDEX.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  late String _sex;
  bool _manual = false; // l'utilisateur a choisi un onglet manuellement → on ne le force plus.
  late Future<Leaderboard> _future;

  @override
  void initState() {
    super.initState();
    _sex = ref.read(sessionProvider).sex ?? 'male';
    _load();
  }

  void _load() {
    _future = ref.read(apiClientProvider).leaderboard(_sex, limit: 100);
  }

  void _switch(String sex) {
    _manual = true;
    if (sex == _sex) return;
    setState(() {
      _sex = sex;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ouvre par défaut l'onglet du sexe de l'utilisateur (le sexe de session peut n'arriver
    // qu'après le 1er build). On ne force plus dès que l'utilisateur a choisi un onglet.
    if (!_manual) {
      final s = ref.watch(sessionProvider).sex;
      if (s != null && s != _sex) {
        _sex = s;
        _load();
      }
    }
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, HiSpace.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Classement', style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.sm),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(color: HiColors.brandPrimary.withValues(alpha: 0.5)),
                foregroundColor: HiColors.brandPrimary,
              ),
              icon: const Icon(Icons.local_fire_department),
              label: const Text('Progression de la semaine (par effort)'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProgressBoardScreen()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
            child: Row(
              children: [
                _tab('Hommes', 'male'),
                const SizedBox(width: 8),
                _tab('Femmes', 'female'),
              ],
            ),
          ),
          const SizedBox(height: HiSpace.md),
          Expanded(
            child: FutureBuilder<Leaderboard>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, 96),
                    itemCount: 10,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, __) => const HiSkeleton(height: 44, radius: HiRadius.sm),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(HiSpace.lg),
                      child: Text('${snap.error}',
                          textAlign: TextAlign.center, style: TextStyle(color: HiColors.error)),
                    ),
                  );
                }
                final lb = snap.data!;
                if (lb.entries.isEmpty) {
                  return Center(
                      child: Text('Aucun athlète pour l’instant.', style: TextStyle(color: HiColors.textTertiary)));
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(_load),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, 96),
                    itemCount: lb.entries.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: HiColors.strokeSubtle),
                    itemBuilder: (_, i) => _row(lb.entries[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, String sex) {
    final active = _sex == sex;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switch(sex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? HiColors.brandGradient : null,
            color: active ? null : HiColors.bgElevated2,
            borderRadius: BorderRadius.circular(HiRadius.pill),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _row(LeaderboardEntry e) {
    final podium = e.position <= 3;
    final posColor = podium ? HiColors.rank(e.position == 1 ? 'gold' : e.position == 2 ? 'silver' : 'bronze') : HiColors.textTertiary;
    return InkWell(
      borderRadius: BorderRadius.circular(HiRadius.sm),
      onTap: () {
        HiHaptics.tap();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: e.userId)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: e.isMe ? HiColors.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(HiRadius.sm),
          border: e.isMe ? Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: podium
                  ? Icon(Icons.workspace_premium_rounded, color: posColor, size: 22)
                  : Text('#${e.position}', style: HiType.numericM.copyWith(color: posColor, fontSize: 16)),
            ),
            Expanded(
              child: Text(
                e.isMe ? '${e.displayName}  (toi)' : e.displayName,
                overflow: TextOverflow.ellipsis,
                style: (e.isMe ? HiType.bodyStrong : HiType.body).copyWith(color: HiColors.textPrimary),
              ),
            ),
            RankBadge(rank: e.rank, fontSize: 11),
            const SizedBox(width: HiSpace.md),
            Text('${e.value}', style: HiType.numericM.copyWith(color: HiColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
