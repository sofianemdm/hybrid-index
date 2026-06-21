import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
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
  late Future<List<WodLeaderboardEntry>> _leaderboard;
  bool _clubScope = false;

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
    return Scaffold(
      appBar: AppBar(title: Text(widget.wodName), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<WodDetail>(
          future: _detail,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
            final d = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
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
                                style: TextStyle(color: HiColors.attribute(a), fontSize: 11, fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: HiSpace.lg),
                _sexToggle(),
                const SizedBox(height: HiSpace.md),
                if (d.levels(_sex) != null) _tierCard(d) else Text('Paliers non disponibles pour cette séance.', style: TextStyle(color: HiColors.textTertiary)),
                const SizedBox(height: HiSpace.lg),
                Text('Classement', style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                if (widget.clubId != null) ...[
                  const SizedBox(height: HiSpace.sm),
                  _clubScopeToggle(),
                ],
                const SizedBox(height: HiSpace.sm),
                _leaderboardSection(d.scoreType),
                const SizedBox(height: HiSpace.lg),
                HiButton(label: 'Faire cette séance', onPressed: () => _doWod(d.scoreType)),
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
        _segment('Hommes', 'male'),
        const SizedBox(width: 8),
        _segment('Femmes', 'female'),
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
              style: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
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
          _tierRow('🏆 Champion', t.champion, d.scoreType, HiColors.attrSpeed),
          Divider(color: HiColors.strokeSubtle),
          _tierRow('Intermédiaire', t.intermediate, d.scoreType, HiColors.textSecondary),
          Divider(color: HiColors.strokeSubtle),
          _tierRow('Occasionnel', t.occasional, d.scoreType, HiColors.textTertiary),
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
                  Text('Toi : ', style: TextStyle(color: HiColors.textSecondary)),
                  Text(formatWodResult(d.myBestRaw!, d.scoreType),
                      style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w800)),
                  if (d.myBestSubScore != null)
                    Text('  ·  ${d.myBestSubScore} pts', style: TextStyle(color: HiColors.textTertiary)),
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
          Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
          Text(formatWodResult(value, scoreType),
              style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _clubScopeToggle() {
    return Row(
      children: [
        _scopeChip('🌍 Tous', false),
        const SizedBox(width: 8),
        _scopeChip('👥 ${widget.clubName ?? "Mon club"}', true),
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
            style: TextStyle(
                color: active ? HiColors.textOnBrand : HiColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }

  Widget _leaderboardSection(String scoreType) {
    return FutureBuilder<List<WodLeaderboardEntry>>(
      future: _leaderboard,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) return Text('${snap.error}', style: TextStyle(color: HiColors.error));
        final entries = snap.data!;
        if (entries.isEmpty) {
          return Text('Sois le premier à poster un résultat 💪', style: TextStyle(color: HiColors.textTertiary));
        }
        return Column(
          children: entries.map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              color: e.isMe ? HiColors.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('#${e.position}',
                        style: TextStyle(
                            color: e.position <= 3 ? HiColors.brandPrimary : HiColors.textTertiary,
                            fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(e.isMe ? '${e.displayName} (toi)' : e.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: HiColors.textPrimary, fontWeight: e.isMe ? FontWeight.w800 : FontWeight.w500)),
                  ),
                  RankBadge(rank: e.rank, fontSize: 10),
                  const SizedBox(width: HiSpace.sm),
                  Text(formatWodResult(e.rawResult, scoreType),
                      style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
