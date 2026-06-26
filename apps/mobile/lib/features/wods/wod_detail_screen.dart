import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/rank_badge.dart';
import 'wod_format.dart';
import 'wod_result_entry_screen.dart';

/// Fiche WOD : paliers de référence (champion/intermédiaire/occasionnel) + classement + « Faire cette séance ».
class WodDetailScreen extends ConsumerStatefulWidget {
  final String wodId;
  final String wodName;

  /// Si fourni, un filtre « Mon club » devient disponible sur le classement de la séance.
  final String? clubId;
  final String? clubName;
  const WodDetailScreen({super.key, required this.wodId, required this.wodName, this.clubId, this.clubName});

  @override
  ConsumerState<WodDetailScreen> createState() => _WodDetailScreenState();
}

class _WodDetailScreenState extends ConsumerState<WodDetailScreen> {
  late String _sex;
  late Future<WodDetail> _detail;
  late Future<WodLeaderboard> _leaderboard;
  bool _clubScope = false;
  String _variant = 'rx'; // 'rx' (Rx) ou 'scaled' (allégé) — classements séparés

  @override
  void initState() {
    super.initState();
    _sex = ref.read(sessionProvider).sex ?? 'male';
    _clubScope = widget.clubId != null; // ouvert depuis un club → on montre le club par défaut
    _detail = ref.read(apiClientProvider).wodDetail(widget.wodId);
    _loadLeaderboard();
  }

  void _loadLeaderboard() {
    _leaderboard = ref.read(apiClientProvider).wodLeaderboard(
      widget.wodId,
      _sex,
      variant: _variant,
      clubId: _clubScope ? widget.clubId : null,
    );
  }

  Future<void> _doWod(String scoreType) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WodResultEntryScreen(wodId: widget.wodId, wodName: widget.wodName, scoreType: scoreType),
      ),
    );
    if (changed == true && mounted) {
      setState(() {
        _detail = ref.read(apiClientProvider).wodDetail(widget.wodId);
        _loadLeaderboard();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.wodName), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<WodDetail>(
          future: _detail,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: HiType.body.copyWith(color: HiColors.error)));
            final d = snap.data!;
            final challenge = _challengeCard(d);
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                if (challenge != null) ...[challenge, const SizedBox(height: HiSpace.lg)],
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: d.targetAttributes
                      .map((a) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: HiColors.attribute(a).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(HiRadius.pill),
                            ),
                            child: Text(HiLabels.attribute(a),
                                style: HiType.caption.copyWith(color: HiColors.attribute(a), fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: HiSpace.lg),
                Text(t.wodDetailReferenceTimes, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: 2),
                Text(t.wodDetailReferenceTimesCaption, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                const SizedBox(height: HiSpace.sm),
                _sexToggle(),
                const SizedBox(height: HiSpace.md),
                if (d.levels(_sex) != null) _tierCard(d) else Text(t.wodDetailNoTiers, style: HiType.body.copyWith(color: HiColors.textTertiary)),
                const SizedBox(height: HiSpace.lg),
                if (d.myHistory.isNotEmpty) ...[
                  _mesPrestations(d),
                  const SizedBox(height: HiSpace.lg),
                ],
                Text(t.wodDetailLeaderboard, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                if (widget.clubId != null) ...[
                  const SizedBox(height: HiSpace.sm),
                  _clubScopeToggle(),
                ],
                const SizedBox(height: HiSpace.sm),
                _leaderboardSection(d.scoreType),
                const SizedBox(height: HiSpace.lg),
                HiButton(label: t.wodDetailDoThisWorkout, onPressed: () => _doWod(d.scoreType)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sexToggle() {
    return Row(
      children: [
        _segment(AppLocalizations.of(context).wodDetailMen, 'male'),
        const SizedBox(width: 8),
        _segment(AppLocalizations.of(context).wodDetailWomen, 'female'),
      ],
    );
  }

  Widget _segment(String label, String sex) {
    final active = _sex == sex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _sex = sex;
          _loadLeaderboard();
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
              style: HiType.body.copyWith(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _tierCard(WodDetail d) {
    final t = d.levels(_sex)!;
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Column(
        children: [
          if (_wr(d) case final wr?) _wrRow(wr) else _tierRow(AppLocalizations.of(context).wodDetailTierChampion, t.champion, d.scoreType, HiColors.attrSpeed),
          Divider(color: HiColors.strokeSubtle),
          _tierRow(AppLocalizations.of(context).wodDetailTierIntermediate, t.intermediate, d.scoreType, HiColors.textSecondary),
          Divider(color: HiColors.strokeSubtle),
          _tierRow(AppLocalizations.of(context).wodDetailTierBeginner, t.occasional, d.scoreType, HiColors.textTertiary),
          if (d.myBestRaw != null) ...[
            const SizedBox(height: HiSpace.sm),
            Container(
              padding: const EdgeInsets.all(HiSpace.sm),
              decoration: BoxDecoration(
                color: HiColors.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(HiRadius.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppLocalizations.of(context).wodDetailYou, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                  Text(formatWodResult(d.myBestRaw!, d.scoreType, wodId: widget.wodId),
                      style: HiType.body.copyWith(color: HiColors.brandPrimary, fontWeight: FontWeight.w800)),
                  if (d.myBestSubScore != null)
                    Text('  ·  ${AppLocalizations.of(context).wodDetailPoints(d.myBestSubScore!)}', style: HiType.body.copyWith(color: HiColors.textTertiary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tierRow(String label, num value, String scoreType, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: HiType.body.copyWith(color: color, fontWeight: FontWeight.w600))),
          Text(formatWodResult(value, scoreType, wodId: widget.wodId),
              style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _fmtCap(int sec) {
    if (sec % 60 == 0) return AppLocalizations.of(context).wodDetailMinutes(sec ~/ 60);
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Carte « Le défi » : énoncé concret de la séance + poids liés au sexe sélectionné.
  /// Null si la séance n'a pas de prescription (WOD custom).
  Widget? _challengeCard(WodDetail d) {
    final p = d.prescription;
    if (p == null || p.blocks.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.lg),
        border: Border.all(color: HiColors.strokeStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).wodDetailChallenge,
              style: HiType.titleM.copyWith(color: HiColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: HiSpace.sm),
          Wrap(
            spacing: HiSpace.sm,
            runSpacing: HiSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(gradient: HiColors.brandGradient, borderRadius: BorderRadius.circular(HiRadius.pill)),
                child: Text(p.format,
                    style: HiType.caption.copyWith(color: HiColors.textOnBrand, fontWeight: FontWeight.w700)),
              ),
              if (p.timeCapSec != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: HiColors.strokeStrong),
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timer_rounded, size: 13, color: HiColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).wodDetailCap(_fmtCap(p.timeCapSec!)),
                        style: HiType.caption.copyWith(color: HiColors.textSecondary, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ),
          if (p.summary != null && p.summary!.isNotEmpty) ...[
            const SizedBox(height: HiSpace.md),
            Text(p.summary!, style: HiType.body.copyWith(color: HiColors.textSecondary)),
          ],
          const SizedBox(height: HiSpace.md),
          ...p.blocks.map(_blockRow),
          if (p.weights.isNotEmpty) ...[
            Divider(color: HiColors.strokeSubtle, height: HiSpace.lg),
            Text(AppLocalizations.of(context).wodDetailLoads,
                style: HiType.overline.copyWith(color: HiColors.textSecondary)),
            const SizedBox(height: HiSpace.sm),
            ...p.weights.map(_weightRow),
          ],
          const SizedBox(height: HiSpace.md),
          Container(
            padding: const EdgeInsets.all(HiSpace.sm),
            decoration: BoxDecoration(
              color: HiColors.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(HiRadius.sm),
            ),
            child: Row(children: [
              Icon(Icons.flag_rounded, size: 15, color: HiColors.brandPrimary),
              const SizedBox(width: HiSpace.sm),
              Expanded(
                child: Text(p.scoringNote,
                    style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _blockRow(WodBlock b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88, // assez large pour « 42-30-18 » ; softWrap:false ⇒ jamais coupé en « 1 / 8 »
            child: Text(b.reps,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: HiType.body.copyWith(color: HiColors.brandPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.movement,
                    style: HiType.body.copyWith(color: HiColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                if (b.detail != null && b.detail!.isNotEmpty)
                  Text(b.detail!, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weightRow(WodWeight w) {
    final rx = w.rx(_sex);
    final scaled = w.scaled(_sex);
    String fmt(num v) => v % 1 == 0 ? '${v.toInt()} ${w.unit}' : '$v ${w.unit}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w.movement, style: HiType.label.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: AppLocalizations.of(context).wodDetailRx, style: TextStyle(color: HiColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
              TextSpan(text: fmt(rx), style: TextStyle(color: HiColors.brandPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              TextSpan(text: '   ·   ', style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
              TextSpan(text: AppLocalizations.of(context).wodDetailLight, style: TextStyle(color: HiColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
              TextSpan(text: fmt(scaled), style: TextStyle(color: HiColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              if (w.note != null && w.note!.isNotEmpty)
                TextSpan(text: '  (${w.note})', style: TextStyle(color: HiColors.textTertiary, fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _clubScopeToggle() {
    return Row(
      children: [
        _scopeChip(AppLocalizations.of(context).wodDetailScopeAll, false),
        const SizedBox(width: 8),
        _scopeChip('👥 ${widget.clubName ?? AppLocalizations.of(context).wodDetailMyClub}', true),
      ],
    );
  }

  Widget _scopeChip(String label, bool club) {
    final active = _clubScope == club;
    return GestureDetector(
      onTap: () => setState(() {
        _clubScope = club;
        _loadLeaderboard();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? HiColors.brandGradient : null,
          color: active ? null : HiColors.bgElevated2,
          borderRadius: BorderRadius.circular(HiRadius.pill),
        ),
        child: Text(label,
            style: HiType.caption.copyWith(
                color: active ? HiColors.textOnBrand : HiColors.textSecondary,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// Meilleure référence (record en priorité) pour le sexe sélectionné, ou null.
  WodReference? _wr(WodDetail d) {
    WodReference? best;
    for (final r in d.references) {
      if (r.sex != _sex) continue;
      if (best == null || (r.tier == 'record' && best.tier != 'record')) best = r;
    }
    return best;
  }

  /// Ligne « World Record » dans le tableau des temps de référence (vrai athlète + temps).
  Widget _wrRow(WodReference r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.tier == 'record' ? AppLocalizations.of(context).wodDetailWorldRecord : AppLocalizations.of(context).wodDetailElite,
                    style: HiType.body.copyWith(color: HiColors.attrSpeed, fontWeight: FontWeight.w800)),
                if (r.athlete != null && r.athlete!.isNotEmpty)
                  Text(r.athlete!, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
              ],
            ),
          ),
          Text(r.note, textAlign: TextAlign.right, style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _mesPrestations(WodDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).wodDetailMyPerformances, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        const SizedBox(height: HiSpace.sm),
        Container(
          decoration: BoxDecoration(
            color: HiColors.bgElevated,
            borderRadius: BorderRadius.circular(HiRadius.md),
            border: Border.all(color: HiColors.strokeSubtle),
          ),
          child: Column(
            children: [
              for (var i = 0; i < d.myHistory.length; i++) ...[
                if (i > 0) Divider(height: 1, color: HiColors.strokeSubtle),
                _histRow(d.myHistory[i], d.scoreType),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _histRow(WodHistoryEntry h, String scoreType) {
    final p = h.performedAt;
    final date = p.length >= 10 ? '${p.substring(8, 10)}/${p.substring(5, 7)}/${p.substring(2, 4)}' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(date, style: HiType.caption.copyWith(color: HiColors.textTertiary))),
          Expanded(
            child: Text(formatWodResult(h.rawResult, scoreType, wodId: widget.wodId),
                style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
          if (!h.rxCompliant)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(widget.wodId == 'hyrox_solo' ? 'Open' : 'Scaled', style: HiType.caption.copyWith(color: HiColors.textTertiary)),
            ),
          if (h.subScore != null)
            Text(AppLocalizations.of(context).wodDetailPoints(h.subScore!), style: HiType.body.copyWith(color: HiColors.brandPrimary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _leaderboardSection(String scoreType) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sélecteur Rx / Scaled (classements séparés, UX-07) — recharge le classement à la bascule.
        Padding(
          padding: const EdgeInsets.only(bottom: HiSpace.sm),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'rx', label: Text(t.wodDetailVariantRx)),
              ButtonSegment(value: 'scaled', label: Text(t.wodDetailVariantScaled)),
            ],
            selected: {_variant},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _variant = s.first;
              _loadLeaderboard();
            }),
          ),
        ),
        FutureBuilder<WodLeaderboard>(
          future: _leaderboard,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: HiColors.brandPrimary)));
            }
            if (snap.hasError) return Text('${snap.error}', style: HiType.body.copyWith(color: HiColors.error));
            final lb = snap.data!;
            if (lb.entries.isEmpty) {
              return Text(t.wodDetailLeaderboardEmpty, style: HiType.body.copyWith(color: HiColors.textTertiary));
            }
            return Column(
              children: [
                ...lb.entries.map((e) => _lbRow(e.position, e.displayName, e.rank, e.index, e.rawResult, scoreType, e.isMe)),
                // « Toi #N » épinglé quand je suis hors du top affiché (UX-06).
                if (lb.me != null && !lb.meInEntries) ...[
                  Divider(color: HiColors.strokeSubtle),
                  _lbRow(lb.me!.position, t.wodDetailYouShort, 'rookie', null, lb.me!.rawResult, scoreType, true),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _lbRow(int position, String name, String rank, int? index, num rawResult, String scoreType, bool isMe) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: isMe ? HiColors.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#$position',
                style: HiType.body.copyWith(
                    color: position <= 3 ? HiColors.brandPrimary : HiColors.textTertiary, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(isMe ? t.wodDetailLeaderboardYou(name) : name,
                overflow: TextOverflow.ellipsis,
                style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: isMe ? FontWeight.w800 : FontWeight.w500)),
          ),
          if (index != null) ...[
            RankBadge(rank: rank, ovr: index, fontSize: 10),
            const SizedBox(width: HiSpace.sm),
          ],
          Text(formatWodResult(rawResult, scoreType, wodId: widget.wodId),
              style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
