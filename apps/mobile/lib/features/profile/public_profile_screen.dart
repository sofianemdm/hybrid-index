import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../community/comments_sheet.dart';
import '../community/feed_post_card.dart';
import '../messaging/chat_screen.dart';
import '../../data/wod_catalog.dart';
import '../wods/wod_format.dart';
import '../wods/wod_detail_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/share_links.dart';
import '../../theme/cosmetics.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/overlay_radar.dart';
import '../share/share_card_screen.dart';

/// Bouton Suivre / Suivi (toggle).
class _FollowButton extends ConsumerStatefulWidget {
  final String userId;
  final bool initial;
  const _FollowButton({required this.userId, required this.initial});

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  late bool _following = widget.initial;
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      if (_following) {
        await api.unfollowUser(widget.userId);
      } else {
        await api.followUser(widget.userId);
      }
      if (mounted) setState(() => _following = !_following);
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : AppLocalizations.of(context).commonGenericError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SizedBox(
      width: 200,
      child: _following
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(color: HiColors.strokeStrong),
                foregroundColor: HiColors.textSecondary,
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(t.publicProfileFollowing),
              onPressed: _busy ? null : _toggle,
            )
          : FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: HiColors.brandPrimary,
                foregroundColor: HiColors.textOnBrand,
              ),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: Text(t.publicProfileFollow),
              onPressed: _busy ? null : _toggle,
            ),
    );
  }
}

/// Bouton « Message » : visible seulement si l'échange est autorisé (lien social + même tranche d'âge).
class _DmButton extends ConsumerStatefulWidget {
  final String userId;
  final String name;
  const _DmButton({required this.userId, required this.name});

  @override
  ConsumerState<_DmButton> createState() => _DmButtonState();
}

class _DmButtonState extends ConsumerState<_DmButton> {
  late Future<DmEligibility> _elig;

  @override
  void initState() {
    super.initState();
    _elig = ref.read(apiClientProvider).canDm(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DmEligibility>(
      future: _elig,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final e = snap.data!;
        if (!e.allowed) {
          // On informe discrètement pourquoi le DM n'est pas possible (sauf cas "soi-même").
          // App 100 % publique : les seuls motifs honnêtes sont l'âge, le blocage, ou un compte
          // indisponible — jamais une restriction de « lien social ».
          if (e.reason == 'self') return const SizedBox.shrink();
          final t = AppLocalizations.of(context);
          final reason = e.reason == 'age'
              ? t.dmReasonAge
              : e.reason == 'blocked'
                  ? t.dmReasonBlocked
                  : t.dmReasonUnavailable;
          return SizedBox(
            width: 200,
            child: Text(reason,
                textAlign: TextAlign.center, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
          );
        }
        return SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: BorderSide(color: HiColors.brandPrimary),
              foregroundColor: HiColors.brandPrimary,
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(AppLocalizations.of(context).publicProfileMessage),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(otherUserId: widget.userId, otherName: widget.name),
            )),
          ),
        );
      },
    );
  }
}

/// Bouton « Inviter dans mon club » : choisit parmi les clubs où je suis membre.
class _InviteToClubButton extends ConsumerStatefulWidget {
  final String userId;
  const _InviteToClubButton({required this.userId});

  @override
  ConsumerState<_InviteToClubButton> createState() => _InviteToClubButtonState();
}

class _InviteToClubButtonState extends ConsumerState<_InviteToClubButton> {
  bool _busy = false;

  Future<void> _invite() async {
    setState(() => _busy = true);
    try {
      final clubs = await ref.read(apiClientProvider).myClubs();
      if (!mounted) return;
      if (clubs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).publicProfileInviteNoClub)));
        return;
      }
      final club = clubs.length == 1
          ? clubs.first
          : await showModalBottomSheet<ClubSummary>(
              context: context,
              backgroundColor: HiColors.bgElevated,
              builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.all(HiSpace.md),
                    child: Text(AppLocalizations.of(context).publicProfileInviteInto,
                        style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                  ),
                  ...clubs.map((c) => ListTile(
                        leading: Icon(Icons.groups_rounded, color: HiColors.brandPrimary),
                        title: Text(c.name, style: HiType.body.copyWith(color: HiColors.textPrimary)),
                        onTap: () => Navigator.of(context).pop(c),
                      )),
                ]),
              ),
            );
      if (club == null || !mounted) return;
      await ref.read(apiClientProvider).inviteToClub(club.id, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).publicProfileInviteSent(club.name))));
      }
    } catch (e) {
      // Message SPÉCIFIQUE (ex. « Cette personne est déjà membre du club. ») au lieu du générique.
      if (mounted) {
        final msg = e is ApiException ? e.message : AppLocalizations.of(context).commonGenericError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          side: BorderSide(color: HiColors.strokeStrong),
          foregroundColor: HiColors.textSecondary,
        ),
        icon: const Icon(Icons.group_add, size: 18),
        label: Text(AppLocalizations.of(context).publicProfileInviteToClub),
        onPressed: _busy ? null : _invite,
      ),
    );
  }
}

/// Profil public d'un autre athlète (tout est public) + comparaison avec le mien.
class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final future = ref.read(apiClientProvider).publicProfile(userId);
    final mine = ref.watch(myProfileProvider).value;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<PublicProfile>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.all(HiSpace.lg),
                children: const [
                  Center(child: HiSkeleton.circle(96)),
                  SizedBox(height: HiSpace.lg),
                  HiSkeleton(height: 24, width: 180, radius: HiRadius.sm),
                  SizedBox(height: HiSpace.lg),
                  HiSkeleton(height: 220, radius: HiRadius.lg),
                  SizedBox(height: HiSpace.md),
                  HiSkeleton(height: 96, radius: HiRadius.lg),
                ],
              );
            }
            if (snap.hasError) {
              return const ErrorRetry();
            }
            final p = snap.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(HiSpace.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    // Avatar évolutif + cosmétiques débloqués (IC-03 / G-03).
                    if (p.avatar != null) ...[
                      HiAvatar(
                        config: p.avatar!,
                        rank: p.rank,
                        size: 96,
                        cosmetics: CosmeticSet(p.activeCosmetics),
                      ),
                      const SizedBox(height: HiSpace.md),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(p.displayName,
                              textAlign: TextAlign.center,
                              style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
                        ),
                        if (p.isConfirmed) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified_rounded, size: 20, color: HiColors.brandPrimary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${HiLabels.goal(p.goal)} · ${p.position != null ? (p.isMe ? t.publicProfileLeaguePositionMine(p.position!) : t.publicProfileLeaguePosition(p.position!)) : '—'}',
                        style: HiType.body.copyWith(color: HiColors.textSecondary)),
                    // Clubs de l'athlète : visibles sur le profil public.
                    if (p.clubs.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_rounded, size: 16, color: HiColors.textTertiary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(p.clubs.join(' · '),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: HiType.body.copyWith(color: HiColors.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: HiSpace.lg),
                    // CARTE JOUEUR complète (demande humaine 03/07) à la place de l'ancien anneau
                    // Index : on voit l'athlète comme sur l'Accueil. Construite depuis les données
                    // publiques (index + radar + avatar) ; pas de badges exposés pour autrui.
                    if (p.index != null)
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: ExcludeSemantics(
                            child: RepaintBoundary(
                              child: PlayerCard(
                                profile: Profile(index: p.index!, radar: p.radar),
                                name: p.displayName,
                                sex: p.sex,
                                avatar: p.avatar,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(t.publicProfileNoIndex, style: HiType.body.copyWith(color: HiColors.textTertiary)),
                    const SizedBox(height: HiSpace.xs),
                    // Partage externe du profil (lien profond /profil/:id) — aussi pour SON propre profil.
                    TextButton.icon(
                      onPressed: () => Share.share(t.shareProfileMessage(p.displayName, profileLink(p.userId))),
                      icon: Icon(Icons.share_rounded, size: 18, color: HiColors.textSecondary),
                      label: Text(t.shareTooltip, style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                    ),
                    // Partage de la carte joueur (image type FIFA) — sa propre carte OU celle de
                    // l'athlète consulté (dès qu'il a un Index), via l'écran dédié.
                    if (p.index != null) ...[
                      const SizedBox(height: HiSpace.xs),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: HiColors.brandPrimary.withValues(alpha: 0.5)),
                          foregroundColor: HiColors.brandPrimary,
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: Text(p.isMe ? t.homeShareCard : t.shareCardShareCtaOther),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => p.isMe
                                ? const ShareCardScreen()
                                : ShareCardScreen(
                                    otherProfile: Profile(index: p.index!, radar: p.radar),
                                    otherName: p.displayName,
                                    otherSex: p.sex,
                                    otherAvatar: p.avatar,
                                  ),
                          ),
                        ),
                      ),
                    ],
                    if (!p.isMe) ...[
                      const SizedBox(height: HiSpace.md),
                      _FollowButton(userId: p.userId, initial: p.isFollowing),
                      const SizedBox(height: HiSpace.sm),
                      _DmButton(userId: p.userId, name: p.displayName),
                      const SizedBox(height: HiSpace.sm),
                      _InviteToClubButton(userId: p.userId),
                    ],
                    const SizedBox(height: HiSpace.lg),
                    if (!p.isMe && mine != null && p.index != null) _compareCard(mine, p),
                    const SizedBox(height: HiSpace.md),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(HiSpace.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                p.isMe
                                    ? t.publicProfileYourRadar
                                    : (mine != null ? t.publicProfileComparison : t.publicProfileTheirRadar),
                                style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                            const SizedBox(height: HiSpace.sm),
                            if (mine != null && !p.isMe)
                              OverlayRadar(mine: mine.radar, other: p.radar)
                            else
                              RadarView(radar: p.radar),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: HiSpace.lg),
                    // Historique de séances de l'athlète, juste sous son radar.
                    _SessionHistory(userId: p.userId),
                    const SizedBox(height: HiSpace.lg),
                    // « Mur » de l'athlète : ses publications (réutilise la carte du fil Communauté).
                    _ProfileWall(userId: p.userId, isMe: p.isMe),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _compareCard(Profile mine, PublicProfile other) {
    final diff = mine.index.value - other.index!.value;
    final ahead = diff >= 0;
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: (ahead ? HiColors.success : HiColors.error).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ahead ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: ahead ? HiColors.success : HiColors.error),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Builder(builder: (context) {
              final t = AppLocalizations.of(context);
              return Text(
                ahead
                    ? t.publicProfileCompareAhead(diff.abs(), mine.index.value, other.index!.value)
                    : t.publicProfileCompareBehind(diff.abs(), mine.index.value, other.index!.value),
                style: HiType.body.copyWith(color: HiColors.textPrimary),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// « Mur » d'un athlète : la liste de SES publications, sous son profil. Réutilise la carte de post
/// partagée (FeedPostCard) — donc le même rendu, le même toggle kudos optimiste et l'ouverture des
/// commentaires que le fil Communauté, sans dupliquer cette logique.
///
/// Comme le mur vit DANS le SingleChildScrollView du profil, on ne fait PAS de scroll interne : on
/// affiche les posts en colonne (shrinkWrap) et on pagine via un bouton « Voir plus » explicite.
class _ProfileWall extends ConsumerStatefulWidget {
  const _ProfileWall({required this.userId, required this.isMe});
  final String userId;
  final bool isMe;

  @override
  ConsumerState<_ProfileWall> createState() => _ProfileWallState();
}

class _ProfileWallState extends ConsumerState<_ProfileWall> {
  final List<FeedActivity> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasError = false;
  String? _cursor;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final page = await ref.read(apiClientProvider).userPosts(widget.userId);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(apiClientProvider).userPosts(widget.userId, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  /// Appel réseau du kudos (le toggle optimiste apply/rollback est dans FeedPostCard).
  Future<bool> _kudosNetwork(FeedActivity a, bool wantOn) async {
    try {
      final api = ref.read(apiClientProvider);
      if (wantOn) {
        await api.react(a.id, isPost: a.isPost);
      } else {
        await api.unreact(a.id, isPost: a.isPost);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openComments(FeedActivity a) async {
    final delta = await showCommentsSheet(context, post: a);
    if (delta != 0 && mounted) {
      setState(() => a.commentCount = (a.commentCount + delta).clamp(0, 1 << 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.profileWallTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        const SizedBox(height: HiSpace.sm),
        if (_loading)
          const Column(children: [
            HiSkeleton(height: 96, radius: HiRadius.lg),
            SizedBox(height: HiSpace.sm),
            HiSkeleton(height: 96, radius: HiRadius.lg),
          ])
        else if (_hasError)
          ErrorRetry(onRetry: _loadFirst)
        else if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HiSpace.lg),
            child: Center(
              child: Text(widget.isMe ? t.profileWallEmptyMine : t.profileWallEmpty,
                  textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textTertiary)),
            ),
          )
        else ...[
          for (final a in _items)
            FeedPostCard(
              key: ValueKey(a.id),
              activity: a,
              onToggleKudos: _kudosNetwork,
              onOpenComments: a.isPost ? _openComments : null,
            ),
          if (_hasMore)
            Center(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(HiSpace.md),
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: Text(t.commonSeeMore, style: TextStyle(color: HiColors.brandPrimary)),
                    ),
            ),
        ],
      ],
    );
  }
}

/// Historique de séances PUBLIC d'un athlète, affiché sous son radar (ses derniers résultats loggés).
class _SessionHistory extends ConsumerStatefulWidget {
  final String userId;
  const _SessionHistory({required this.userId});
  @override
  ConsumerState<_SessionHistory> createState() => _SessionHistoryState();
}

class _SessionHistoryState extends ConsumerState<_SessionHistory> {
  late Future<List<WodResultItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).publicResults(widget.userId);
  }

  WodCatalogItem? _catalog(String wodId) {
    for (final w in wodCatalog) {
      if (w.id == wodId) return w;
    }
    return null;
  }

  /// Nom : priorité au nom RÉEL envoyé par l'api (couvre les WODs hors catalogue — Ligue,
  /// séances retirées : fini les « league_sprint_ladder » bruts). Catalogue en repli.
  String _name(WodResultItem r) {
    if (r.wodId == 'run_free_distance') return AppLocalizations.of(context).historyRun;
    final api = r.wodName;
    if (api != null && api.isNotEmpty) return api;
    return _catalog(r.wodId)?.name ?? r.wodId;
  }

  String _formatResult(WodResultItem r) {
    final type = r.scoreType ??
        _catalog(r.wodId)?.scoreType ??
        (r.wodId == 'run_free_distance' ? 'time' : 'reps');
    if (type == 'time') return formatDuration(r.rawResult.round());
    if (type == 'load') return '${r.rawResult.round()} kg';
    if (type == 'distance') return '${r.rawResult.round()} m';
    return '${r.rawResult.round()} reps';
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.publicProfileHistoryTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
            const SizedBox(height: HiSpace.sm),
            FutureBuilder<List<WodResultItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const HiListSkeleton(count: 3, itemHeight: 56);
                }
                if (snap.hasError) {
                  return Text(t.commonGenericError, style: HiType.caption.copyWith(color: HiColors.textTertiary));
                }
                final items = snap.data ?? const <WodResultItem>[];
                if (items.isEmpty) {
                  return Text(t.publicProfileHistoryEmpty, style: HiType.body.copyWith(color: HiColors.textTertiary));
                }
                return Column(children: [for (final r in items) _row(r)]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(WodResultItem r) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: r.wodId, wodName: _name(r))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HiSpace.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name(r),
                      style: HiType.body.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${_formatResult(r)} · ${_date(r.performedAt)}',
                      style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                ],
              ),
            ),
            if (r.subScore != null)
              Text('${r.subScore}', style: HiType.numericM.copyWith(color: HiColors.brandPrimary)),
          ],
        ),
      ),
    );
  }
}
