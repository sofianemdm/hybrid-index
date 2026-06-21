import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/rank_badge.dart';
import 'chat_screen.dart';

/// Boîte de réception : liste des conversations privées (les plus récentes d'abord).
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  late Future<List<ConversationSummary>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(apiClientProvider).conversations();

  Future<void> _open(ConversationSummary c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(conversationId: c.id, otherUserId: c.otherUserId, otherName: c.otherName),
    ));
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(_load),
          child: FutureBuilder<List<ConversationSummary>>(
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
                      Icon(Icons.forum_outlined, color: HiColors.textTertiary, size: 40),
                      const SizedBox(height: HiSpace.md),
                      Text('Aucune conversation. Écris à un athlète que tu suis (et qui te suit) '
                          'ou à un membre de ton club.',
                          textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                    ]),
                  ),
                ]);
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(HiSpace.sm, HiSpace.sm, HiSpace.sm, 96),
                children: items.map(_tile).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tile(ConversationSummary c) {
    final preview = c.lastBody == null ? '' : '${c.lastIsMine ? 'Toi : ' : ''}${c.lastBody}';
    return Card(
      color: HiColors.bgElevated,
      child: ListTile(
        title: Row(children: [
          Flexible(
            child: Text(c.otherName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          RankBadge(rank: c.otherRank, fontSize: 9),
        ]),
        subtitle: Text(preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: HiColors.textTertiary, fontSize: 13)),
        trailing: c.unread > 0
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: HiColors.brandPrimary, shape: BoxShape.circle),
                child: Text('${c.unread}',
                    style: TextStyle(color: HiColors.textOnBrand, fontSize: 11, fontWeight: FontWeight.w800)),
              )
            : Icon(Icons.chevron_right, color: HiColors.textTertiary),
        onTap: () => _open(c),
      ),
    );
  }
}
