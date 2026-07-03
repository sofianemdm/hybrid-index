import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/hi_button.dart';
import '../wods/wod_format.dart';
import 'mention_suggestions.dart';

/// Composer un post : message texte OU partage d'une perf (résultat de séance).
/// Pas de photo pour l'instant (livré sans, branché plus tard).
class PostComposerScreen extends ConsumerStatefulWidget {
  /// [clubId]/[clubName] : le post est publié dans le FIL DE CE CLUB (entrée « Publier dans le club »).
  final String? clubId;
  final String? clubName;
  const PostComposerScreen({super.key, this.clubId, this.clubName});

  @override
  ConsumerState<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends ConsumerState<PostComposerScreen> {
  final _body = TextEditingController();
  bool _perfMode = false;
  MyResult? _selected;
  List<MyResult>? _results;
  bool _busy = false;

  /// Vivier de pseudos pour l'autocomplétion @ (les athlètes que je suis). Chargé une fois,
  /// best-effort : un échec réseau désactive simplement l'autocomplete (la saisie libre reste OK).
  List<AthleteSummary> _mentionPool = const [];

  @override
  void initState() {
    super.initState();
    _loadMentionPool();
  }

  Future<void> _loadMentionPool() async {
    try {
      final f = await ref.read(apiClientProvider).following();
      if (mounted) setState(() => _mentionPool = f);
    } catch (_) {/* autocomplete indisponible : saisie libre + rendu cliquable conservés */}
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    if (_results != null) return;
    final r = await ref.read(apiClientProvider).myResults();
    if (mounted) setState(() => _results = r);
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final body = _body.text.trim();
    if (_perfMode) {
      if (_selected == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.composerPickPerf)));
        return;
      }
    } else if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.composerWriteMessage)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).createPost(
            kind: _perfMode ? 'perf_share' : 'text',
            body: body,
            wodResultId: _perfMode ? _selected!.id : null,
            clubId: widget.clubId,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.commonGenericError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      // En mode club, le titre nomme le fil de destination (clair : on ne poste pas dans le fil global).
      appBar: AppBar(
          title: Text(widget.clubName == null ? t.composerTitle : '${t.composerTitle} · ${widget.clubName}'),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HiSpace.lg),
          children: [
            Row(children: [
              _modeChip(t.composerModeMessage, false),
              const SizedBox(width: 8),
              _modeChip(t.composerModePerf, true),
            ]),
            const SizedBox(height: HiSpace.lg),
            if (_perfMode) ...[
              _perfPicker(),
              const SizedBox(height: HiSpace.md),
              Text(t.composerCaptionLabel, style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              const SizedBox(height: 6),
            ],
            // Autocomplétion @ : suggestions au-dessus du champ quand on tape `@pseudo`.
            MentionSuggestionStrip(
              controller: _body,
              candidates: mentionCandidates(_body, _mentionPool),
            ),
            TextField(
              controller: _body,
              maxLines: _perfMode ? 2 : 6,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _perfMode ? t.composerHintPerf : t.composerHintText,
                helperText: t.composerMentionHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: HiSpace.md),
            HiButton(label: t.composerPublish, loading: _busy, onPressed: _busy ? null : _submit),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool perf) {
    final active = _perfMode == perf;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _perfMode = perf);
          if (perf) _loadResults();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? HiColors.brandGradient : null,
            color: active ? null : HiColors.bgElevated2,
            borderRadius: BorderRadius.circular(HiRadius.pill),
          ),
          child: Text(label,
              style: HiType.bodyStrong.copyWith(
                  color: active ? HiColors.textOnBrand : HiColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _perfPicker() {
    final t = AppLocalizations.of(context);
    if (_results == null) {
      return const HiListSkeleton(count: 3, itemHeight: 56, padding: EdgeInsets.all(16));
    }
    if (_results!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(HiSpace.md),
        decoration: BoxDecoration(
          color: HiColors.bgElevated,
          borderRadius: BorderRadius.circular(HiRadius.md),
          border: Border.all(color: HiColors.strokeSubtle),
        ),
        child: Text(t.composerNoResults,
            style: HiType.body.copyWith(color: HiColors.textTertiary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.composerPickPerfLabel, style: HiType.caption.copyWith(color: HiColors.textSecondary)),
        const SizedBox(height: 6),
        ..._results!.take(20).map((r) {
          final sel = _selected?.id == r.id;
          return GestureDetector(
            onTap: () => setState(() => _selected = r),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: 12),
              decoration: BoxDecoration(
                color: sel ? HiColors.brandPrimary.withValues(alpha: 0.12) : HiColors.bgElevated,
                borderRadius: BorderRadius.circular(HiRadius.md),
                border: Border.all(color: sel ? HiColors.brandPrimary : HiColors.strokeSubtle),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(r.wodName,
                      overflow: TextOverflow.ellipsis,
                      style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                ),
                Text(formatWodResult(r.rawResult, r.scoreType, wodId: r.wodId, roundsLabel: AppLocalizations.of(context).wodFormatRounds),
                    style: HiType.numericM.copyWith(color: HiColors.brandPrimary)),
                if (r.subScore != null)
                  Text('  ${r.subScore} pts', style: HiType.caption.copyWith(color: HiColors.textTertiary)),
              ]),
            ),
          );
        }),
      ],
    );
  }
}
