import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/rank_badge.dart';
import '../profile/public_profile_screen.dart';
import 'progress_board_screen.dart';
import '../league/league_screen.dart';

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
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, HiSpace.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(t.leaderboardTitle, style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
            ),
          ),
          // Explication claire de ce qu'est la Ligue dès l'arrivée sur la page.
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: HiColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(t.leaderboardIntro,
                      style: HiType.caption.copyWith(color: HiColors.textSecondary, height: 1.35)),
                ),
              ],
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
              label: Text(t.leaderboardWeeklyProgress),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProgressBoardScreen()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.sm),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: HiColors.brandSecondary,
                foregroundColor: HiColors.textOnBrand,
              ),
              icon: const Icon(Icons.military_tech_rounded),
              label: const Text('Ligue du mois'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeagueScreen()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
            child: Row(
              children: [
                _tab(t.leaderboardMen, 'male'),
                const SizedBox(width: 8),
                _tab(t.leaderboardWomen, 'female'),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.leaderboard_rounded, color: HiColors.textTertiary, size: 40),
                          const SizedBox(height: HiSpace.md),
                          Text(t.leaderboardUnavailable,
                              textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                          const SizedBox(height: HiSpace.md),
                          TextButton(onPressed: () => setState(_load), child: Text(t.leaderboardRetry)),
                        ],
                      ),
                    ),
                  );
                }
                final lb = snap.data!;
                if (lb.entries.isEmpty) {
                  return Center(
                      child: Text(t.leaderboardEmpty, style: TextStyle(color: HiColors.textTertiary)));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_load);
                    await _future; // l'indicateur reste jusqu'à l'arrivée réelle des données
                  },
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
                e.isMe ? AppLocalizations.of(context).leaderboardYou(e.displayName) : e.displayName,
                overflow: TextOverflow.ellipsis,
                style: (e.isMe ? HiType.bodyStrong : HiType.body).copyWith(color: HiColors.textPrimary),
              ),
            ),
            RankBadge(rank: e.rank, ovr: e.value, fontSize: 11),
            const SizedBox(width: HiSpace.md),
            Text('${e.value}', style: HiType.numericM.copyWith(color: HiColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
