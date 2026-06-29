import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/timeago.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/rank_badge.dart';
import '../clubs/clubs_screen.dart';
import '../messaging/conversations_screen.dart';
import '../profile/public_profile_screen.dart';
import '../wods/wod_detail_screen.dart';
import '../wods/wod_format.dart';
import 'explore_screen.dart';
import 'post_composer_screen.dart';

/// Onglet Communauté : feed d'activité (PR, séances, montées de rang, badges) + kudos unifié 👏.
class CommunityTab extends ConsumerStatefulWidget {
  const CommunityTab({super.key});

  @override
  ConsumerState<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<CommunityTab> {
  late Future<List<FeedActivity>> _future;
  // Copie locale mutable du fil → retrait optimiste (blocage), toggle kudos et suivi en place.
  List<FeedActivity> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(apiClientProvider).feed().then((list) {
      _items = list;
      return list;
    });
  }

  // --- Kudos unifié : un seul applaudissement par item, toggle optimiste sans refetch ni saut de scroll. ---
  Future<void> _toggleKudos(FeedActivity a) async {
    HiHaptics.tap();
    final had = a.hasKudoed;
    void apply(bool on) {
      a.hasKudoed = on;
      a.kudos = (a.kudos + (on ? 1 : -1)).clamp(0, 1 << 30);
    }

    setState(() => apply(!had));
    try {
      final api = ref.read(apiClientProvider);
      if (had) {
        await api.unreact(a.id, isPost: a.isPost);
      } else {
        await api.react(a.id, isPost: a.isPost);
      }
    } catch (e) {
      if (mounted) {
        setState(() => apply(had)); // échec → on annule la modif optimiste
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonGenericError)));
      }
    }
  }

  Future<void> _openComposer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostComposerScreen()),
    );
    if (created == true && mounted) setState(_load);
  }

  /// Suivre l'athlète suggéré (carte « Découvrir ») → on le retire du repli (il alimentera le vrai fil).
  Future<void> _follow(FeedActivity a) async {
    HiHaptics.tap();
    try {
      await ref.read(apiClientProvider).followUser(a.actorUserId);
      if (mounted) setState(() => _items.removeWhere((x) => x.actorUserId == a.actorUserId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonGenericError)));
    }
  }

  /// Menu d'une carte d'autrui (events ET posts) : Signaler, Bloquer, et Supprimer si c'est mon post.
  Future<void> _cardMenu(FeedActivity a) async {
    final t = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (a.isMe && a.isPost)
            ListTile(
              leading: Icon(Icons.delete_outline, color: HiColors.error),
              title: Text(t.communityPostDelete, style: TextStyle(color: HiColors.error)),
              onTap: () => Navigator.of(context).pop('delete'),
            )
          else ...[
            if (a.isPost)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: HiColors.textSecondary),
                title: Text(t.communityPostReport, style: TextStyle(color: HiColors.textPrimary)),
                onTap: () => Navigator.of(context).pop('report'),
              ),
            ListTile(
              leading: Icon(Icons.block, color: HiColors.error),
              title: Text(t.communityPostBlock, style: TextStyle(color: HiColors.error)),
              onTap: () => Navigator.of(context).pop('block'),
            ),
          ],
        ]),
      ),
    );
    if (action == null || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      if (action == 'delete') {
        await api.deletePost(a.id);
        if (mounted) setState(() => _items.removeWhere((x) => x.id == a.id));
      } else if (action == 'report') {
        await api.reportPost(a.id, 'inappropriate');
        // Le post signalé disparaît immédiatement de MON fil (auto-masquage côté back aussi).
        if (mounted) {
          setState(() => _items.removeWhere((x) => x.id == a.id));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.communityReportSent)));
        }
      } else if (action == 'block') {
        await api.blockUser(a.actorUserId);
        // On retire toutes les activités de l'auteur bloqué du fil.
        if (mounted) {
          setState(() => _items.removeWhere((x) => x.actorUserId == a.actorUserId));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.communityUserBlocked)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonGenericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _future;
        },
        child: FutureBuilder<List<FeedActivity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.md, HiSpace.lg, 96),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: HiSpace.md),
                itemBuilder: (_, __) => const HiSkeleton(height: 96, radius: HiRadius.lg),
              );
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: HiSpace.xl),
                  child: ErrorRetry(onRetry: () => setState(_load)),
                ),
              ]);
            }
            final items = _items;
            final discoverMode = items.isNotEmpty && items.every((a) => a.isDiscover);
            if (items.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(HiSpace.xl),
                  child: Column(children: [
                    Icon(Icons.groups_outlined, color: HiColors.textTertiary, size: 40),
                    const SizedBox(height: HiSpace.md),
                    Text(t.communityEmpty,
                        textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                    const SizedBox(height: HiSpace.md),
                    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: HiColors.brandPrimary, foregroundColor: HiColors.textOnBrand),
                        onPressed: _openComposer,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(t.communityPublish),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
                        icon: const Icon(Icons.search, size: 18),
                        label: Text(t.communityTooltipSearch),
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
                    child: Text(t.communityTitle,
                        style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
                  ),
                  Badge.count(
                    count: ref.watch(unreadMessagesProvider).value ?? 0,
                    isLabelVisible: (ref.watch(unreadMessagesProvider).value ?? 0) > 0,
                    backgroundColor: HiColors.error,
                    child: IconButton(
                      tooltip: t.communityTooltipMessages,
                      icon: Icon(Icons.forum_outlined, color: HiColors.textTertiary),
                      onPressed: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const ConversationsScreen()));
                        ref.invalidate(unreadMessagesProvider); // maj de la pastille au retour
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: t.communityTooltipPublish,
                    icon: Icon(Icons.edit_outlined, color: HiColors.brandPrimary),
                    onPressed: _openComposer,
                  ),
                  IconButton(
                    tooltip: t.communityTooltipClubs,
                    icon: Icon(Icons.groups, color: HiColors.textTertiary),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClubsScreen())),
                  ),
                  IconButton(
                    tooltip: t.communityTooltipSearch,
                    icon: Icon(Icons.search, color: HiColors.textTertiary),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
                  ),
                ]),
                const SizedBox(height: HiSpace.sm),
                if (discoverMode) _discoverHeader(t),
                ...items.map((a) => a.isDiscover ? _discoverCard(a) : _card(a)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Bandeau « Découvrir » affiché quand on ne suit personne (le fil est rempli par le top de la ligue).
  Widget _discoverHeader(AppLocalizations t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.communityDiscoverTitle,
              style: HiType.titleM.copyWith(color: HiColors.textPrimary, fontSize: 16)),
          const SizedBox(height: 2),
          Text(t.communityDiscoverSubtitle, style: HiType.body.copyWith(color: HiColors.textTertiary, fontSize: 13)),
        ]),
      );

  String _message(FeedActivity a) {
    final t = AppLocalizations.of(context);
    switch (a.type) {
      case 'pr':
        return t.communityMsgPr(a.payload['wodName']?.toString() ?? t.communityWorkoutFallback);
      case 'wod_logged':
        return t.communityMsgWodLogged(a.payload['wodName']?.toString() ?? t.communityWorkoutFallback);
      case 'rank_up':
        return t.communityMsgRankUp(HiLabels.rank(a.payload['rank']?.toString() ?? ''));
      case 'badge_unlocked':
        return t.communityMsgBadge(a.payload['name']?.toString() ?? '');
      case 'member_joined':
        return t.communityMsgMemberJoined(a.payload['index']?.toString() ?? '—');
      case 'post_text':
        return a.payload['body']?.toString() ?? '';
      case 'post_perf':
        return t.communityMsgPostPerf(a.payload['wodName']?.toString() ?? t.communityWorkoutFallback);
      default:
        return t.communityMsgDefault;
    }
  }

  /// Mini-avatar de l'acteur (repli neutre si aucun avatar).
  Widget _avatar(FeedActivity a) => HiAvatar(
        config: a.actorAvatar ?? const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1),
        rank: a.actorRank,
        size: 34,
      );

  Widget _card(FeedActivity a) {
    final t = AppLocalizations.of(context);
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
              _avatar(a),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: a.isMe
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: a.actorUserId)),
                          ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(a.actorName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          RankBadge(rank: a.actorRank, ovr: a.actorIndex, fontSize: 10),
                        ],
                      ),
                      if (a.createdAt != null)
                        Text(timeAgo(t, a.createdAt!),
                            style: HiType.caption.copyWith(color: HiColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              // Menu (Signaler / Bloquer) sur TOUTE carte d'autrui ; + Supprimer sur mes posts.
              if (!a.isMe || a.isPost)
                GestureDetector(
                  onTap: () => _cardMenu(a),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.more_horiz, size: 18, color: HiColors.textTertiary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
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
          _kudos(a),
        ],
      ),
    );
  }

  /// Carte « athlète à suivre » du repli Découvrir : avatar + nom + grade + bouton Suivre.
  Widget _discoverCard(FeedActivity a) {
    final t = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: HiSpace.sm),
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          _avatar(a),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: a.actorUserId))),
              child: Row(
                children: [
                  Flexible(
                    child: Text(a.actorName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  RankBadge(rank: a.actorRank, ovr: a.actorIndex, fontSize: 10),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HiColors.brandPrimary,
              foregroundColor: HiColors.textOnBrand,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => _follow(a),
            child: Text(t.communityFollow),
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
    return (id, a.payload['wodName']?.toString() ?? AppLocalizations.of(context).communityWorkoutFallback);
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
              '${formatWodResult(raw, scoreType, wodId: a.payload['wodId']?.toString(), roundsLabel: AppLocalizations.of(context).wodFormatRounds)}'
              '${a.payload['subScore'] is num ? '  ·  ${a.payload['subScore']}/100' : ''}',
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

  /// Bouton kudos UNIQUE (👏) avec compteur — toggle façon Strava. Désactivé sur mes propres activités.
  Widget _kudos(FeedActivity a) {
    final t = AppLocalizations.of(context);
    final active = a.hasKudoed;
    final count = a.kudos;
    // a11y : bouton « kudos » nommé, état coché, compteur lu ; cible tactile garantie ≥ 48dp.
    return Semantics(
      button: !a.isMe,
      toggled: active,
      enabled: !a.isMe,
      label: t.communityKudosTooltip,
      value: count > 0 ? '$count' : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: a.isMe ? null : () => _toggleKudos(a),
          child: Tooltip(
            message: t.communityKudosTooltip,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: HiTap.minTarget),
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? HiColors.brandPrimary.withValues(alpha: 0.15) : HiColors.bgElevated2,
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                    border:
                        Border.all(color: active ? HiColors.brandPrimary.withValues(alpha: 0.5) : HiColors.strokeSubtle),
                  ),
                  child: Text('👏 ${count > 0 ? count : ''}'.trim(),
                      style: TextStyle(
                          color: active ? HiColors.brandPrimary : HiColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
