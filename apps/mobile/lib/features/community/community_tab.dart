import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/rank_badge.dart';
import '../clubs/clubs_screen.dart';
import '../messaging/conversations_screen.dart';
import '../profile/public_profile_screen.dart';
import '../wods/wod_detail_screen.dart';
import '../wods/wod_format.dart';
import 'explore_screen.dart';
import 'post_composer_screen.dart';

/// Onglet Communauté : feed d'activité (PR, séances, montées de rang, badges) + kudos.
class CommunityTab extends ConsumerStatefulWidget {
  const CommunityTab({super.key});

  @override
  ConsumerState<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<CommunityTab> {
  late Future<List<FeedActivity>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(apiClientProvider).feed();
  }

  Future<void> _react(FeedActivity a, String emoji) async {
    try {
      final api = ref.read(apiClientProvider);
      if (a.myReactions.contains(emoji)) {
        await api.unreact(a.id, isPost: a.isPost);
      } else {
        await api.react(a.id, emoji, isPost: a.isPost);
      }
      setState(_load);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openComposer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostComposerScreen()),
    );
    if (created == true && mounted) setState(_load);
  }

  Future<void> _postMenu(FeedActivity a) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (a.isMe)
            ListTile(
              leading: Icon(Icons.delete_outline, color: HiColors.error),
              title: Text('Supprimer', style: TextStyle(color: HiColors.error)),
              onTap: () => Navigator.of(context).pop('delete'),
            )
          else
            ListTile(
              leading: Icon(Icons.flag_outlined, color: HiColors.textSecondary),
              title: Text('Signaler', style: TextStyle(color: HiColors.textPrimary)),
              onTap: () => Navigator.of(context).pop('report'),
            ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      if (action == 'delete') {
        await api.deletePost(a.id);
      } else if (action == 'report') {
        await api.reportPost(a.id, 'inappropriate');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci, signalement envoyé.')));
        }
      }
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<FeedActivity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(padding: const EdgeInsets.all(HiSpace.lg), child: Text('${snap.error}', style: TextStyle(color: HiColors.error))),
              ]);
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(HiSpace.xl),
                  child: Column(children: [
                    Icon(Icons.groups_outlined, color: HiColors.textTertiary, size: 40),
                    const SizedBox(height: HiSpace.md),
                    Text('Suis des athlètes pour voir leur activité, ou logue une séance pour démarrer ton fil.',
                        textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                    const SizedBox(height: HiSpace.md),
                    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: HiColors.brandPrimary, foregroundColor: HiColors.textOnBrand),
                        onPressed: _openComposer,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Publier'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClubsScreen())),
                        icon: const Icon(Icons.groups, size: 18),
                        label: const Text('Explorer les clubs'),
                      ),
                    ]),
                  ]),
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                Row(children: [
                  Expanded(
                    child: Text('Communauté',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                  ),
                  IconButton(
                    tooltip: 'Messages',
                    icon: Icon(Icons.forum_outlined, color: HiColors.textTertiary),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversationsScreen())),
                  ),
                  IconButton(
                    tooltip: 'Publier',
                    icon: Icon(Icons.edit_outlined, color: HiColors.brandPrimary),
                    onPressed: _openComposer,
                  ),
                  IconButton(
                    tooltip: 'Clubs',
                    icon: Icon(Icons.groups, color: HiColors.textTertiary),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClubsScreen())),
                  ),
                  IconButton(
                    tooltip: 'Rechercher',
                    icon: Icon(Icons.search, color: HiColors.textTertiary),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
                  ),
                ]),
                const SizedBox(height: HiSpace.sm),
                ...items.map(_card),
              ],
            );
          },
        ),
      ),
    );
  }

  String _message(FeedActivity a) {
    switch (a.type) {
      case 'pr':
        return '🏆 Nouveau PR — ${a.payload['wodName'] ?? 'une séance'}';
      case 'wod_logged':
        return 'a fait ${a.payload['wodName'] ?? 'une séance'}';
      case 'rank_up':
        return 'monte au rang ${HiLabels.rank(a.payload['rank']?.toString() ?? '')} 🎖️';
      case 'badge_unlocked':
        return 'badge débloqué : ${a.payload['name'] ?? ''}';
      case 'member_joined':
        return 'vient de nous rejoindre avec un HYBRID INDEX de ${a.payload['index'] ?? '—'} 👋';
      case 'post_text':
        return a.payload['body']?.toString() ?? '';
      case 'post_perf':
        return '💪 a partagé sa perf — ${a.payload['wodName'] ?? 'une séance'}';
      default:
        return 'nouvelle activité';
    }
  }

  Widget _card(FeedActivity a) {
    return Container(
      margin: const EdgeInsets.only(bottom: HiSpace.sm),
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: a.isMe
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: a.actorUserId)),
                          ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(a.isMe ? 'Toi' : a.actorName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      RankBadge(rank: a.actorRank, fontSize: 10),
                    ],
                  ),
                ),
              ),
              if (a.isPost)
                GestureDetector(
                  onTap: () => _postMenu(a),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.more_horiz, size: 18, color: HiColors.textTertiary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Builder(builder: (context) {
            final target = _seanceTarget(a);
            final text = Text(_message(a),
                style: TextStyle(
                  color: target != null ? HiColors.brandPrimary : HiColors.textSecondary,
                ));
            if (target == null) return text;
            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WodDetailScreen(wodId: target.$1, wodName: target.$2))),
              child: text,
            );
          }),
          if (a.type == 'post_perf') ...[
            const SizedBox(height: 4),
            _perfLine(a),
          ],
          const SizedBox(height: HiSpace.sm),
          Row(
            children: [
              _kudos(a, '❤️'),
              const SizedBox(width: 8),
              _kudos(a, '💪'),
              const SizedBox(width: 8),
              _kudos(a, '🔥'),
            ],
          ),
        ],
      ),
    );
  }

  /// (wodId, nom) si l'activité référence une séance (PR / séance loggée / partage de perf) → ouvre son classement.
  (String, String)? _seanceTarget(FeedActivity a) {
    if (a.type != 'pr' && a.type != 'wod_logged' && a.type != 'post_perf') return null;
    final id = a.payload['wodId']?.toString();
    if (id == null || id.isEmpty) return null;
    return (id, a.payload['wodName']?.toString() ?? 'Séance');
  }

  /// Ligne « perf » d'un post de partage : résultat formaté (+ légende optionnelle).
  Widget _perfLine(FeedActivity a) {
    final raw = a.payload['rawResult'];
    final scoreType = a.payload['scoreType']?.toString();
    final caption = a.payload['body']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (raw is num && scoreType != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: HiColors.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(HiRadius.pill),
            ),
            child: Text(
              '${formatWodResult(raw, scoreType)}'
              '${a.payload['subScore'] is num ? '  ·  ${a.payload['subScore']} pts' : ''}',
              style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w800),
            ),
          ),
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: HiColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _kudos(FeedActivity a, String emoji) {
    final count = a.reactions[emoji] ?? 0;
    final active = a.myReactions.contains(emoji);
    return GestureDetector(
      onTap: a.isMe ? null : () => _react(a, emoji),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? HiColors.brandPrimary.withValues(alpha: 0.15) : HiColors.bgElevated2,
          borderRadius: BorderRadius.circular(HiRadius.pill),
          border: Border.all(color: active ? HiColors.brandPrimary.withValues(alpha: 0.5) : HiColors.strokeSubtle),
        ),
        child: Text('$emoji ${count > 0 ? count : ''}'.trim(),
            style: TextStyle(color: active ? HiColors.brandPrimary : HiColors.textSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
