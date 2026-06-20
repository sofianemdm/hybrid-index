import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/rank_badge.dart';
import '../profile/public_profile_screen.dart';

/// Onglet Communauté : feed d'activité (PR, WODs, montées de rang, badges) + kudos.
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
        await api.unreact(a.id);
      } else {
        await api.react(a.id, emoji);
      }
      setState(_load);
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
                Padding(padding: const EdgeInsets.all(HiSpace.lg), child: Text('${snap.error}', style: const TextStyle(color: HiColors.error))),
              ]);
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(HiSpace.xl),
                  child: Column(children: [
                    Icon(Icons.groups_outlined, color: HiColors.textTertiary, size: 40),
                    SizedBox(height: HiSpace.md),
                    Text('Suis des athlètes pour voir leur activité, ou logue un WOD pour démarrer ton fil.',
                        textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                  ]),
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                const Text('Communauté',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.md),
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
        return '🏆 Nouveau PR — ${a.payload['wodName'] ?? 'un WOD'}';
      case 'wod_logged':
        return 'a fait ${a.payload['wodName'] ?? 'un WOD'}';
      case 'rank_up':
        return 'monte au rang ${HiLabels.rank(a.payload['rank']?.toString() ?? '')} 🎖️';
      case 'badge_unlocked':
        return 'badge débloqué : ${a.payload['name'] ?? ''}';
      case 'challenge_resolved':
        return 'a résolu un défi ⚔️';
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
          GestureDetector(
            onTap: a.isMe
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: a.actorUserId)),
                    ),
            child: Row(
              children: [
                Text(a.isMe ? 'Toi' : a.actorName,
                    style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                RankBadge(rank: a.actorRank, fontSize: 10),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(_message(a), style: const TextStyle(color: HiColors.textSecondary)),
          const SizedBox(height: HiSpace.sm),
          Row(
            children: [
              _kudos(a, '💪'),
              const SizedBox(width: 8),
              _kudos(a, '🔥'),
            ],
          ),
        ],
      ),
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
