import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../messaging/chat_screen.dart';
import '../../theme/cosmetics.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/index_ring.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/overlay_radar.dart';
import '../../widgets/rank_badge.dart';

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
          if (e.reason == 'self') return const SizedBox.shrink();
          return SizedBox(
            width: 200,
            child: Text(e.message,
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
              return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text('${snap.error}', textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.error)),
                ),
              );
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
                    const SizedBox(height: HiSpace.lg),
                    if (p.index != null)
                      IndexRing(value: p.index!.value, percentile: p.index!.percentile, size: 200)
                    else
                      Text(t.publicProfileNoIndex, style: HiType.body.copyWith(color: HiColors.textTertiary)),
                    const SizedBox(height: HiSpace.md),
                    RankBadge(rank: p.rank, ovr: p.index?.value, fontSize: 14),
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
