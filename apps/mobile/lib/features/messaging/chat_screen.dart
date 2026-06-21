import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/rank_badge.dart';

/// Fil de discussion 1‑à‑1. Ouvert soit via une conversation existante, soit en démarrant
/// une nouvelle conversation avec [otherUserId] (le 1er message la crée côté serveur).
class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  final String otherUserId;
  final String otherName;
  const ChatScreen({super.key, this.conversationId, required this.otherUserId, required this.otherName});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _convId;
  List<DmMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _convId = widget.conversationId;
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_convId == null) {
      setState(() => _loading = false); // nouvelle conversation : rien à charger encore
      return;
    }
    try {
      final c = await ref.read(apiClientProvider).conversationMessages(_convId!);
      if (mounted) {
        setState(() {
          _messages = c.messages;
          _loading = false;
        });
        _jumpToEnd();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final api = ref.read(apiClientProvider);
      _convId = await api.sendMessage(widget.otherUserId, text);
      _input.clear();
      final c = await api.conversationMessages(_convId!);
      if (mounted) {
        setState(() => _messages = c.messages);
        _jumpToEnd();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _body()),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: HiColors.error)));
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HiSpace.xl),
          child: Text('Démarre la conversation avec ${widget.otherName} 👋',
              textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(HiSpace.lg),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(_messages[i]),
    );
  }

  Widget _bubble(DmMessage m) {
    final mine = m.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          gradient: mine ? HiColors.brandGradient : null,
          color: mine ? null : HiColors.bgElevated,
          borderRadius: BorderRadius.circular(HiRadius.md),
          border: mine ? null : Border.all(color: HiColors.strokeSubtle),
        ),
        child: Text(m.body,
            style: TextStyle(color: mine ? HiColors.textOnBrand : HiColors.textPrimary)),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(HiSpace.md, 8, HiSpace.md, 12),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        border: Border(top: BorderSide(color: HiColors.strokeSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(hintText: 'Écris un message…', counterText: ''),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _sending
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.brandPrimary))
                : Icon(Icons.send, color: HiColors.brandPrimary),
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

/// Carte d'en-tête réutilisable (nom + rang) — pas strictement nécessaire mais garde la cohérence.
class ChatPeerHeader extends StatelessWidget {
  final String name;
  final String rank;
  const ChatPeerHeader({super.key, required this.name, required this.rank});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        RankBadge(rank: rank, fontSize: 10),
      ]);
}
