import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/rank_badge.dart';
import '../wods/wod_detail_screen.dart';
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
        final t = AppLocalizations.of(context);
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
                      Text(t.challengeBannerLabel(c.theme.toUpperCase()),
                          style: HiType.overline.copyWith(color: HiColors.textOnBrand.withValues(alpha: 0.9))),
                      const SizedBox(height: 2),
                      Text(c.wodName,
                          style: HiType.titleM.copyWith(color: HiColors.textOnBrand, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: HiColors.textOnBrand),
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
    final t = AppLocalizations.of(context);
    final end = DateTime.tryParse(endsAtIso);
    if (end == null) return '';
    final d = end.toUtc().difference(DateTime.now().toUtc());
    if (d.isNegative) return t.challengeEnded;
    if (d.inDays >= 1) return t.challengeCountdownDays(d.inDays, d.inHours % 24);
    return t.challengeCountdownHours(d.inHours, d.inMinutes % 60);
  }

  Future<void> _doChallenge(WeeklyChallenge c) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => WodResultEntryScreen(
        wodId: c.wodId,
        wodName: c.wodName,
        scoreType: c.scoreType,
        // Échelle Rx/Allégé dérivée de la prescription du back (poids non vide) — source unique.
        scalable: c.prescription?.weights.isNotEmpty ?? false,
      ),
    ));
    if (changed == true && mounted) setState(_loadBoard);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.challengeTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<WeeklyChallenge>(
          future: _challenge,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: HiType.body.copyWith(color: HiColors.error)));
            final c = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                _hero(c),
                if (c.prescription != null) ...[
                  const SizedBox(height: HiSpace.md),
                  _whatToDo(c.prescription!),
                ],
                const SizedBox(height: HiSpace.md),
                HiButton(label: t.challengeDoIt, onPressed: () => _doChallenge(c)),
                const SizedBox(height: HiSpace.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: Text(t.challengeDetails),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: c.wodId, wodName: c.wodName)),
                  ),
                ),
                const SizedBox(height: HiSpace.lg),
                Row(children: [_tab(t.leagueMen, 'male'), const SizedBox(width: 8), _tab(t.leagueWomen, 'female')]),
                const SizedBox(height: HiSpace.md),
                Text(t.challengeLeaderboard, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.sm),
                _boardSection(c.scoreType, c.wodId),
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
                  style: HiType.overline.copyWith(color: HiColors.textOnBrand)),
            ),
            const Spacer(),
            Text(_countdown(c.endsAt), style: HiType.caption.copyWith(color: HiColors.textOnBrand, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: HiSpace.md),
          Text(c.wodName,
              style: HiType.titleL.copyWith(color: HiColors.textOnBrand, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
          if (c.prescription != null) ...[
            const SizedBox(height: 4),
            Text(c.prescription!.format,
                style: HiType.body.copyWith(color: HiColors.textOnBrand.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: HiSpace.sm),
          Text(AppLocalizations.of(context).challengeHeroTagline,
              style: HiType.caption.copyWith(color: HiColors.textOnBrand.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _whatToDo(WodPrescription p) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).challengeWhatToDo,
              style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
          if (p.summary != null && p.summary!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.summary!, style: HiType.caption.copyWith(color: HiColors.textSecondary, height: 1.4)),
          ],
          const SizedBox(height: HiSpace.sm),
          ...p.blocks.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 64,
                    child: Text(b.reps,
                        style: HiType.bodyStrong.copyWith(color: HiColors.brandPrimary, fontWeight: FontWeight.w800)),
                  ),
                  Expanded(
                    child: Text(b.detail != null && b.detail!.isNotEmpty ? '${b.movement} · ${b.detail}' : b.movement,
                        style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
                  ),
                ]),
              )),
          const SizedBox(height: HiSpace.sm),
          Row(children: [
            Icon(Icons.flag_outlined, size: 14, color: HiColors.brandPrimary),
            const SizedBox(width: 6),
            Expanded(child: Text(p.scoringNote, style: HiType.caption.copyWith(color: HiColors.textTertiary))),
          ]),
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
              style: HiType.label.copyWith(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _boardSection(String scoreType, String wodId) {
    return FutureBuilder<List<WodLeaderboardEntry>>(
      future: _board,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: HiColors.brandPrimary)));
        }
        if (snap.hasError) return Text('${snap.error}', style: HiType.body.copyWith(color: HiColors.error));
        final entries = snap.data!;
        if (entries.isEmpty) {
          return Text(AppLocalizations.of(context).challengeBeFirst, style: HiType.body.copyWith(color: HiColors.textTertiary));
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
                      style: HiType.label.copyWith(
                          color: e.position <= 3 ? HiColors.brandPrimary : HiColors.textTertiary, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Text(e.isMe ? AppLocalizations.of(context).challengeYouSuffix(e.displayName) : e.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: e.isMe ? FontWeight.w800 : FontWeight.w500)),
                ),
                RankBadge(rank: e.rank, ovr: e.index, fontSize: 10),
                const SizedBox(width: HiSpace.sm),
                Text(formatWodResult(e.rawResult, scoreType, wodId: wodId),
                    style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}
