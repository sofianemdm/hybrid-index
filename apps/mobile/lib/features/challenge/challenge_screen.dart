import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/rank_badge.dart';
import '../wods/wod_format.dart';
import '../wods/wod_result_entry_screen.dart';

/// Bannière compacte (accueil) : annonce le défi de la semaine, tap → ChallengeScreen.
class ChallengeBanner extends ConsumerWidget {
  const ChallengeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<WeeklyChallenge>(
      future: ref.read(apiClientProvider).currentChallenge(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final c = snap.data!;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengeScreen())),
          child: Container(
            margin: const EdgeInsets.only(bottom: HiSpace.md),
            padding: const EdgeInsets.all(HiSpace.md),
            decoration: BoxDecoration(
              gradient: HiColors.brandGradient,
              borderRadius: BorderRadius.circular(HiRadius.md),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(width: HiSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DÉFI DE LA SEMAINE · ${c.theme.toUpperCase()}',
                          style: TextStyle(color: HiColors.textOnBrand.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(c.wodName,
                          style: TextStyle(color: HiColors.textOnBrand, fontSize: 17, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: HiColors.textOnBrand),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Défi de la semaine : le WOD imposé + compte à rebours + classement de la semaine.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key});

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  late Future<WeeklyChallenge> _challenge;
  late String _sex;
  late Future<List<WodLeaderboardEntry>> _board;

  @override
  void initState() {
    super.initState();
    _sex = ref.read(sessionProvider).sex ?? 'male';
    _challenge = ref.read(apiClientProvider).currentChallenge();
    _loadBoard();
  }

  void _loadBoard() => _board = ref.read(apiClientProvider).challengeLeaderboard(_sex);

  String _countdown(String endsAtIso) {
    final end = DateTime.tryParse(endsAtIso);
    if (end == null) return '';
    final d = end.toUtc().difference(DateTime.now().toUtc());
    if (d.isNegative) return 'Terminé';
    if (d.inDays >= 1) return 'Plus que ${d.inDays} j ${d.inHours % 24} h';
    return 'Plus que ${d.inHours} h ${d.inMinutes % 60} min';
  }

  Future<void> _doChallenge(WeeklyChallenge c) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => WodResultEntryScreen(wodId: c.wodId, wodName: c.wodName, scoreType: c.scoreType),
    ));
    if (changed == true && mounted) setState(_loadBoard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Défi de la semaine'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<WeeklyChallenge>(
          future: _challenge,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
            final c = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                _hero(c),
                const SizedBox(height: HiSpace.md),
                HiButton(label: 'Faire le défi 🔥', onPressed: () => _doChallenge(c)),
                const SizedBox(height: HiSpace.lg),
                Row(children: [_tab('Hommes', 'male'), const SizedBox(width: 8), _tab('Femmes', 'female')]),
                const SizedBox(height: HiSpace.md),
                Text('Classement du défi', style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: HiSpace.sm),
                _boardSection(c.scoreType),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(WeeklyChallenge c) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        gradient: HiColors.brandGradient,
        borderRadius: BorderRadius.circular(HiRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(HiRadius.pill)),
              child: Text(c.theme.toUpperCase(),
                  style: TextStyle(color: HiColors.textOnBrand, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
            const Spacer(),
            Text(_countdown(c.endsAt), style: TextStyle(color: HiColors.textOnBrand, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: HiSpace.md),
          Text(c.wodName,
              style: TextStyle(color: HiColors.textOnBrand, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
          if (c.prescription != null) ...[
            const SizedBox(height: 4),
            Text(c.prescription!.format,
                style: TextStyle(color: HiColors.textOnBrand.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: HiSpace.sm),
          Text('Tout le monde se mesure sur cette séance cette semaine. Donne tout 💪',
              style: TextStyle(color: HiColors.textOnBrand.withValues(alpha: 0.85), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _tab(String label, String sex) {
    final active = _sex == sex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _sex = sex;
          _loadBoard();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? HiColors.brandGradient : null,
            color: active ? null : HiColors.bgElevated2,
            borderRadius: BorderRadius.circular(HiRadius.pill),
          ),
          child: Text(label,
              style: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _boardSection(String scoreType) {
    return FutureBuilder<List<WodLeaderboardEntry>>(
      future: _board,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) return Text('${snap.error}', style: TextStyle(color: HiColors.error));
        final entries = snap.data!;
        if (entries.isEmpty) {
          return Text('Sois le premier à relever le défi cette semaine 🔥', style: TextStyle(color: HiColors.textTertiary));
        }
        return Column(
          children: entries.map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              color: e.isMe ? HiColors.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
              child: Row(children: [
                SizedBox(
                  width: 32,
                  child: Text('#${e.position}',
                      style: TextStyle(
                          color: e.position <= 3 ? HiColors.brandPrimary : HiColors.textTertiary, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Text(e.isMe ? '${e.displayName} (toi)' : e.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HiColors.textPrimary, fontWeight: e.isMe ? FontWeight.w800 : FontWeight.w500)),
                ),
                RankBadge(rank: e.rank, fontSize: 10),
                const SizedBox(width: HiSpace.sm),
                Text(formatWodResult(e.rawResult, scoreType),
                    style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}
