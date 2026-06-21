import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
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
    if (sex == _sex) return;
    setState(() {
      _sex = sex;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, HiSpace.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Classement',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
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
                  return const Center(child: CircularProgressIndicator());
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
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: e.userId)),
      ),
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: e.isMe ? HiColors.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('#${e.position}',
                style: TextStyle(
                    color: e.position <= 3 ? HiColors.brandPrimary : HiColors.textTertiary,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(
              e.isMe ? '${e.displayName}  (toi)' : e.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: HiColors.textPrimary,
                fontWeight: e.isMe ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          RankBadge(rank: e.rank, fontSize: 11),
          const SizedBox(width: HiSpace.md),
          Text('${e.value}',
              style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontFeatures: const [])),
        ],
      ),
      ),
    );
  }
}
