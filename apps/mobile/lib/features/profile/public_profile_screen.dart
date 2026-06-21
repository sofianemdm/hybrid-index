import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
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
    return SizedBox(
      width: 200,
      child: _following
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(color: HiColors.strokeStrong),
                foregroundColor: HiColors.textSecondary,
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Suivi'),
              onPressed: _busy ? null : _toggle,
            )
          : FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: HiColors.brandPrimary,
                foregroundColor: HiColors.textOnBrand,
              ),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Suivre'),
              onPressed: _busy ? null : _toggle,
            ),
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
            const SnackBar(content: Text('Crée d\'abord un club pour inviter.')));
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
                    child: Text('Inviter dans…',
                        style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                  ...clubs.map((c) => ListTile(
                        leading: Icon(Icons.groups, color: HiColors.brandPrimary),
                        title: Text(c.name, style: TextStyle(color: HiColors.textPrimary)),
                        onTap: () => Navigator.of(context).pop(c),
                      )),
                ]),
              ),
            );
      if (club == null || !mounted) return;
      await ref.read(apiClientProvider).inviteToClub(club.id, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation envoyée à « ${club.name} »')));
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
        label: const Text('Inviter dans mon club'),
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
    final future = ref.read(apiClientProvider).publicProfile(userId);
    final mine = ref.watch(myProfileProvider).value;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<PublicProfile>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text('${snap.error}', textAlign: TextAlign.center, style: TextStyle(color: HiColors.error)),
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
                    Text(p.displayName,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${HiLabels.goal(p.goal)} · ${p.position != null ? '#${p.position} de sa ligue' : '—'}',
                        style: TextStyle(color: HiColors.textSecondary)),
                    const SizedBox(height: HiSpace.lg),
                    if (p.index != null)
                      IndexRing(value: p.index!.value, percentile: p.index!.percentile, size: 200)
                    else
                      Text('Pas encore d’Index.', style: TextStyle(color: HiColors.textTertiary)),
                    const SizedBox(height: HiSpace.md),
                    RankBadge(rank: p.rank, fontSize: 14),
                    if (!p.isMe) ...[
                      const SizedBox(height: HiSpace.md),
                      _FollowButton(userId: p.userId, initial: p.isFollowing),
                      const SizedBox(height: HiSpace.sm),
                      _InviteToClubButton(userId: p.userId),
                    ],
                    const SizedBox(height: HiSpace.lg),
                    if (mine != null && p.index != null) _compareCard(mine, p),
                    const SizedBox(height: HiSpace.md),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(HiSpace.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mine != null ? 'Comparaison' : 'Son radar',
                                style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: HiSpace.sm),
                            if (mine != null)
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
          Icon(ahead ? Icons.trending_up : Icons.trending_down,
              color: ahead ? HiColors.success : HiColors.error),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Text(
              ahead
                  ? 'Tu es devant de ${diff.abs()} points (toi ${mine.index.value} · lui ${other.index!.value}).'
                  : 'Il te devance de ${diff.abs()} points (toi ${mine.index.value} · lui ${other.index!.value}).',
              style: TextStyle(color: HiColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
