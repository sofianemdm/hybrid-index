import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(ClubDetail d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(d.isOwner && d.memberCount > 1 ? 'Tu es le créateur' : 'Quitter le club ?',
            style: TextStyle(color: HiColors.textPrimary)),
        content: Text(
          d.isOwner && d.memberCount > 1
              ? 'Transfère d\'abord le club ou attends d\'être seul·e pour le quitter.'
              : 'Tu pourras le rejoindre à nouveau plus tard.',
          style: TextStyle(color: HiColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          if (!(d.isOwner && d.memberCount > 1))
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Quitter')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).leaveClub(d.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSeance(ClubDetail d) async {
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
              child: Text('Classement du club par séance',
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...wods.map((w) => ListTile(
                  leading: Text(w.isFlagship ? '⭐' : '•', style: const TextStyle(fontSize: 16)),
                  title: Text(w.name, style: TextStyle(color: HiColors.textPrimary)),
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
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<ClubDetail>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
            final d = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, 96),
              children: [
                Row(children: [
                  Icon(Icons.groups, color: HiColors.brandPrimary, size: 30),
                  const SizedBox(width: HiSpace.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name,
                          style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
                      Text('${d.memberCount} membre${d.memberCount > 1 ? 's' : ''}',
                          style: TextStyle(color: HiColors.textTertiary, fontSize: 13)),
                    ]),
                  ),
                ]),
                if (d.description != null && d.description!.isNotEmpty) ...[
                  const SizedBox(height: HiSpace.sm),
                  Text(d.description!, style: TextStyle(color: HiColors.textSecondary)),
                ],
                const SizedBox(height: HiSpace.md),
                if (!d.isMember)
                  HiButton(label: 'Rejoindre le club', loading: _busy, onPressed: _busy ? null : () => _join(d))
                else
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ProgressBoardScreen(clubId: d.id, clubName: d.name))),
                        icon: const Icon(Icons.local_fire_department, size: 18),
                        label: const Text('Progression'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickSeance(d),
                        icon: const Icon(Icons.leaderboard, size: 18),
                        label: const Text('Par séance'),
                      ),
                    ),
                  ]),
                const SizedBox(height: HiSpace.lg),
                Text('Classement du club (Hybrid Index)',
                    style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: HiSpace.sm),
                ...d.roster.map(_rosterRow),
                if (d.isMember) ...[
                  const SizedBox(height: HiSpace.lg),
                  TextButton(
                    onPressed: _busy ? null : () => _leave(d),
                    child: Text('Quitter le club', style: TextStyle(color: HiColors.error)),
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
                style: TextStyle(
                    color: e.position <= 3 ? HiColors.brandPrimary : HiColors.textTertiary,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(e.isMe ? '${e.displayName} (toi)' : e.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: HiColors.textPrimary, fontWeight: e.isMe ? FontWeight.w800 : FontWeight.w500)),
          ),
          if (e.role == 'owner')
            const Padding(padding: EdgeInsets.only(right: 6), child: Text('👑', style: TextStyle(fontSize: 13))),
          RankBadge(rank: e.rank, fontSize: 10),
          const SizedBox(width: HiSpace.sm),
          Text('${e.index}',
              style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w800)),
        ]),
      );
}
