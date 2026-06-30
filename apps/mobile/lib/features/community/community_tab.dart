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
import 'comments_sheet.dart';
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

  // PAGINATION CLIENT : le serveur renvoie un fil FINI borné (FEED_LIMIT, cf. social.service.ts,
  // décision « pas de scroll infini »). On ne construit pas toutes les cartes d'un coup : le
  // ListView.builder est paresseux et on n'expose qu'une fenêtre qui grandit au scroll.
  static const int _pageSize = 15;
  int _visibleCount = _pageSize;

  /// Portée du fil : 'all' = fil GLOBAL (toute la communauté, défaut), 'following' = mes suivis + moi.
  String _scope = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _visibleCount = _pageSize; // tout rechargement repart de la première page
    _future = ref.read(apiClientProvider).feed(scope: _scope).then((list) {
      _items = list;
      return list;
    });
  }

  /// Bascule entre fil global et fil des suivis → rechargement complet.
  void _setScope(String scope) {
    if (_scope == scope) return;
    HiHaptics.tap();
    setState(() {
      _scope = scope;
      _load();
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
    // Actions DESTRUCTIVES (suppression, blocage) → on demande confirmation avant d'exécuter
    // (un tap dans une feuille ne doit pas suffire à supprimer ou bloquer).
    if (action == 'delete') {
      final ok = await _confirmDestructive(
        title: t.communityDeleteConfirmTitle,
        body: t.communityDeleteConfirmBody,
        confirmLabel: t.commonDelete,
      );
      if (!ok || !mounted) return;
    } else if (action == 'block') {
      final ok = await _confirmDestructive(
        title: t.communityBlockConfirmTitle,
        body: t.communityBlockConfirmBody,
        confirmLabel: t.communityBlockConfirmAction,
      );
      if (!ok || !mounted) return;
    }
    try {
      final api = ref.read(apiClientProvider);
      if (action == 'delete') {
        await api.deletePost(a.id);
        if (mounted) {
          setState(() => _items.removeWhere((x) => x.id == a.id));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.communityPostDeleted)));
        }
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

  /// Dialogue de confirmation pour une action destructive (suppression / blocage). Renvoie `true`
  /// si l'utilisateur confirme. Le bouton de confirmation est en rouge (HiColors.error).
  Future<bool> _confirmDestructive({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final t = AppLocalizations.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(title, style: TextStyle(color: HiColors.textPrimary)),
        content: Text(body, style: TextStyle(color: HiColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.commonCancel, style: TextStyle(color: HiColors.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: TextStyle(color: HiColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  /// Ouvre le fil de commentaires d'un post → met à jour le compteur de la carte au retour (delta).
  Future<void> _openComments(FeedActivity a) async {
    HiHaptics.tap();
    final delta = await showCommentsSheet(context, post: a);
    if (delta != 0 && mounted) {
      setState(() => a.commentCount = (a.commentCount + delta).clamp(0, 1 << 30));
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
              final following = _scope == 'following';
              return ListView(
                padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
                children: [
                  // L'en-tête (avec le sélecteur Tout/Suivis) reste visible pour pouvoir changer de portée.
                  _header(t),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: HiSpace.xl),
                    child: Column(children: [
                      Icon(Icons.groups_outlined, color: HiColors.textTertiary, size: 40),
                      const SizedBox(height: HiSpace.md),
                      Text(following ? t.communityEmptyFollowing : t.communityEmpty,
                          textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                      const SizedBox(height: HiSpace.md),
                      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                        if (following)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: HiColors.brandPrimary, foregroundColor: HiColors.textOnBrand),
                            onPressed: () => _setScope('all'),
                            icon: const Icon(Icons.public, size: 18),
                            label: Text(t.communityScopeAll),
                          )
                        else
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: HiColors.brandPrimary, foregroundColor: HiColors.textOnBrand),
                            onPressed: _openComposer,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(t.communityPublish),
                          ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
                          icon: const Icon(Icons.search, size: 18),
                          label: Text(t.communityTooltipSearch),
                        ),
                      ]),
                    ]),
                  ),
                ],
              );
            }
            // En-tête (titre + actions) puis cartes du fil. ListView.builder PARESSEUX : seules les
            // cartes visibles sont construites, et on n'expose qu'une fenêtre (_visibleCount) qui
            // grandit quand on approche du bas (pagination client sur le fil fini du serveur).
            final shown = items.length < _visibleCount ? items.length : _visibleCount;
            final hasMore = shown < items.length;
            return NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (hasMore && n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
                  // Approche du bas → on étend la fenêtre (frame suivante pour éviter setState en build).
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _visibleCount < _items.length) {
                      setState(() => _visibleCount = (_visibleCount + _pageSize).clamp(0, _items.length));
                    }
                  });
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
                // +1 en-tête, +1 indicateur « charge la suite » s'il reste des cartes.
                itemCount: 1 + (discoverMode ? 1 : 0) + shown + (hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == 0) return _header(t);
                  var idx = i - 1;
                  if (discoverMode) {
                    if (idx == 0) return _discoverHeader(t);
                    idx -= 1;
                  }
                  if (idx < shown) {
                    final a = items[idx];
                    return a.isDiscover ? _discoverCard(a) : _card(a);
                  }
                  // Sentinelle de chargement en bas tant qu'il reste des cartes à révéler.
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: HiSpace.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// En-tête du fil : titre + actions (messages, publier, clubs, recherche) + sélecteur Tout/Suivis.
  Widget _header(AppLocalizations t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(t.communityTitle, style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
              ),
              Badge.count(
                count: ref.watch(unreadMessagesProvider).value ?? 0,
                isLabelVisible: (ref.watch(unreadMessagesProvider).value ?? 0) > 0,
                backgroundColor: HiColors.error,
                child: IconButton(
                  tooltip: t.communityTooltipMessages,
                  icon: Icon(Icons.forum_outlined, color: HiColors.textTertiary),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversationsScreen()));
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
            const SizedBox(height: HiSpace.xs),
            _scopeSelector(t),
          ],
        ),
      );

  /// Sélecteur de portée du fil : « Tout » (global) / « Suivis ». Segment compact façon pilule.
  Widget _scopeSelector(AppLocalizations t) {
    Widget seg(String value, String label) {
      final active = _scope == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setScope(value),
          child: Semantics(
            button: true,
            selected: active,
            label: label,
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? HiColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(HiRadius.pill),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: active ? HiColors.textOnBrand : HiColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.pill),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(children: [
        seg('all', t.communityScopeAll),
        seg('following', t.communityScopeFollowing),
      ]),
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
          Row(children: [
            _kudos(a),
            // Les commentaires ne s'appliquent qu'aux posts d'athlètes (pas aux events auto).
            if (a.isPost) ...[
              const SizedBox(width: HiSpace.sm),
              _commentButton(a),
            ],
          ]),
        ],
      ),
    );
  }

  /// Bouton commentaire (💬) avec compteur → ouvre le fil de commentaires du post.
  Widget _commentButton(FeedActivity a) {
    final t = AppLocalizations.of(context);
    final count = a.commentCount;
    return Semantics(
      button: true,
      label: t.commentsTitle,
      value: count > 0 ? '$count' : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => _openComments(a),
          child: Tooltip(
            message: t.commentsTitle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: HiTap.minTarget),
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HiColors.bgElevated2,
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                    border: Border.all(color: HiColors.strokeSubtle),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.mode_comment_outlined, size: 15, color: HiColors.textSecondary),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Text('$count',
                          style: TextStyle(color: HiColors.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
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
