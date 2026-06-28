import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/rank_badge.dart';
import '../leaderboard/progress_board_screen.dart';
import '../wods/wod_detail_screen.dart';

/// Fiche club : classement Index du club (roster) + filtres « club » sur la progression
/// et sur chaque séance. Le club ne crée PAS de nouvelle ligue : c'est une vue/un filtre.
class ClubDetailScreen extends ConsumerStatefulWidget {
  final String clubId;
  const ClubDetailScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen> {
  late Future<ClubDetail> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(apiClientProvider).clubDetail(widget.clubId);

  Future<void> _join(ClubDetail d) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).joinClub(d.id);
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonGenericError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(ClubDetail d) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(d.isOwner && d.memberCount > 1 ? t.clubDetailOwnerTitle : t.clubDetailLeaveTitle,
            style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        content: Text(
          d.isOwner && d.memberCount > 1
              ? t.clubDetailOwnerMessage
              : t.clubDetailLeaveMessage,
          style: HiType.body.copyWith(color: HiColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.clubDetailCancel)),
          if (!(d.isOwner && d.memberCount > 1))
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.clubDetailLeave)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).leaveClub(d.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonGenericError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSeance(ClubDetail d) async {
    final t = AppLocalizations.of(context);
    final catalog = await ref.read(apiClientProvider).wodsCatalog();
    if (!mounted) return;
    final wods = catalog.where((w) => !w.isCustom).toList()
      ..sort((a, b) => (b.isFlagship ? 1 : 0).compareTo(a.isFlagship ? 1 : 0));
    final chosen = await showModalBottomSheet<WodCatalogEntry>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(HiSpace.md),
              child: Text(t.clubDetailRankingBySeance,
                  style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
            ),
            ...wods.map((w) => ListTile(
                  leading: Text(w.isFlagship ? '⭐' : '•', style: const TextStyle(fontSize: 16)),
                  title: Text(w.name, style: HiType.body.copyWith(color: HiColors.textPrimary)),
                  onTap: () => Navigator.of(context).pop(w),
                )),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WodDetailScreen(wodId: chosen.id, wodName: chosen.name, clubId: d.id, clubName: d.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<ClubDetail>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
            }
            if (snap.hasError) return ErrorRetry(onRetry: () => setState(_load));
            final d = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, 96),
              children: [
                Row(children: [
                  Icon(Icons.groups_rounded, color: HiColors.brandPrimary, size: 30),
                  const SizedBox(width: HiSpace.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name,
                          style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
                      Text(t.clubDetailMembers(d.memberCount),
                          style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                    ]),
                  ),
                ]),
                if (d.description != null && d.description!.isNotEmpty) ...[
                  const SizedBox(height: HiSpace.sm),
                  Text(d.description!, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                ],
                const SizedBox(height: HiSpace.md),
                if (!d.isMember)
                  HiButton(label: t.clubDetailJoin, loading: _busy, onPressed: _busy ? null : () => _join(d))
                else
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ProgressBoardScreen(clubId: d.id, clubName: d.name))),
                        icon: const Icon(Icons.local_fire_department, size: 18),
                        label: Text(t.clubDetailProgression),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickSeance(d),
                        icon: const Icon(Icons.leaderboard, size: 18),
                        label: Text(t.clubDetailBySeance),
                      ),
                    ),
                  ]),
                const SizedBox(height: HiSpace.lg),
                Text(t.clubDetailRankingTitle,
                    style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.sm),
                ...d.roster.map(_rosterRow),
                if (d.isMember) ...[
                  const SizedBox(height: HiSpace.lg),
                  TextButton(
                    onPressed: _busy ? null : () => _leave(d),
                    child: Text(t.clubDetailLeaveButton, style: HiType.button.copyWith(color: HiColors.error)),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rosterRow(ClubRosterEntry e) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        color: e.isMe ? HiColors.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
        child: Row(children: [
          SizedBox(
            width: 32,
            child: Text('#${e.position}',
                style: HiType.label.copyWith(
                    color: e.position <= 3 ? HiColors.brandPrimary : HiColors.textTertiary,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(e.isMe ? AppLocalizations.of(context).clubDetailRosterMe(e.displayName) : e.displayName,
                overflow: TextOverflow.ellipsis,
                style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: e.isMe ? FontWeight.w800 : FontWeight.w500)),
          ),
          if (e.role == 'owner')
            const Padding(padding: EdgeInsets.only(right: 6), child: Text('👑', style: TextStyle(fontSize: 13))),
          RankBadge(ovr: e.index, fontSize: 10),
          const SizedBox(width: HiSpace.sm),
          Text('${e.index}',
              style: HiType.numericM.copyWith(color: HiColors.brandPrimary)),
        ]),
      );
}
