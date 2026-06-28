import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/rank_badge.dart';
import '../profile/public_profile_screen.dart';

/// Traduit un code d'erreur serveur de la messagerie (ou une `ApiException`) en message
/// utilisateur localisé. On n'affiche JAMAIS `Text('$e')` brut : chaque code connu a sa copie.
String messagingErrorMessage(AppLocalizations t, Object error) {
  if (error is ApiException) {
    switch (error.code) {
      case 'RATE_LIMITED':
        return t.messagingErrorRateLimited;
      case 'DM_NOT_ALLOWED':
      case 'FORBIDDEN':
        return t.messagingErrorNotAllowed;
      case 'NOT_FOUND':
        return t.messagingErrorNotFound;
      case 'VALIDATION_ERROR':
        return t.messagingErrorTooLong;
      case 'NETWORK':
        return t.messagingErrorNetwork;
      default:
        return t.messagingErrorGeneric;
    }
  }
  return t.messagingErrorGeneric;
}

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

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _convId;
  List<DmMessage> _messages = [];
  // Messages envoyés de façon optimiste (en cours / échoués) pas encore confirmés par le serveur.
  final List<DmMessage> _pending = [];
  AvatarConfig? _otherAvatar;
  String _otherRank = 'rookie';
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _convId = widget.conversationId;
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Suspend le polling en arrière-plan (économie batterie/réseau) et le relance au retour.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _pollMessages(); // rattrape immédiatement ce qu'on a manqué
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    // Polling léger : tant que le fil est ouvert ET au premier plan, on récupère les nouveaux
    // messages reçus. Pas de websocket pour l'instant ; 3 s = livraison quasi-instantanée.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _pollMessages());
  }

  /// Liste affichée = messages serveur + messages optimistes en attente/échec (à la fin).
  List<DmMessage> get _visible => [..._messages, ..._pending];

  /// Rafraîchit silencieusement les messages (n'affiche ni spinner ni erreur ; n'écrase pas une
  /// saisie en cours). Met à jour la pastille de non-lus globale au passage.
  Future<void> _pollMessages() async {
    if (_convId == null || _sending) return;
    try {
      final c = await ref.read(apiClientProvider).conversationMessages(_convId!);
      if (!mounted) return;
      // On rafraîchit si le nombre de messages change OU si un accusé de lecture a évolué
      // (pour faire passer « Envoyé » → « Lu » sur mon dernier message).
      if (_serverStateChanged(c.messages)) {
        setState(() => _messages = c.messages);
        _jumpToEnd();
        ref.invalidate(unreadMessagesProvider);
      }
    } catch (_) {
      // silencieux — simple tentative de rafraîchissement
    }
  }

  bool _serverStateChanged(List<DmMessage> next) {
    if (next.length != _messages.length) return true;
    for (var i = 0; i < next.length; i++) {
      if (next[i].id != _messages[i].id || next[i].readAt != _messages[i].readAt) return true;
    }
    return false;
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
          _otherAvatar = c.otherAvatar;
          _otherRank = c.otherRank;
          _loading = false;
        });
        _jumpToEnd();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mounted ? messagingErrorMessage(AppLocalizations.of(context), e) : null;
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
    _input.clear();
    await _deliver(text);
  }

  /// Envoi optimiste : affiche le message immédiatement en état `pending`, puis le confirme
  /// (`sent`) ou le marque `failed` si l'API rejette. Réutilisé par le retry.
  Future<void> _deliver(String text, {String? replaceId}) async {
    final myId = ref.read(sessionProvider).user?.id ?? '';
    final pendingId = replaceId ?? 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = DmMessage(
      id: pendingId,
      senderId: myId,
      body: text,
      createdAt: DateTime.now().toIso8601String(),
      isMine: true,
      status: DmSendStatus.pending,
    );
    setState(() {
      _pending.removeWhere((m) => m.id == pendingId);
      _pending.add(optimistic);
      _sending = true;
    });
    _jumpToEnd();
    try {
      final api = ref.read(apiClientProvider);
      _convId = await api.sendMessage(widget.otherUserId, text);
      HiHaptics.success();
      final c = await api.conversationMessages(_convId!);
      if (mounted) {
        setState(() {
          _messages = c.messages; // vérité serveur
          _otherAvatar = c.otherAvatar;
          _otherRank = c.otherRank;
          _pending.removeWhere((m) => m.id == pendingId); // l'optimiste est désormais côté serveur
        });
        _jumpToEnd();
      }
    } catch (e) {
      // Échec d'envoi : on garde le message en état `failed` (réessayable au tap), pas de perte.
      if (mounted) {
        HiHaptics.error();
        setState(() {
          final i = _pending.indexWhere((m) => m.id == pendingId);
          if (i != -1) _pending[i] = _pending[i].copyWith(status: DmSendStatus.failed);
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _retry(DmMessage m) {
    if (_sending || m.status != DmSendStatus.failed) return; // pas de renvoi concurrent
    _deliver(m.body, replaceId: m.id);
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PublicProfileScreen(userId: widget.otherUserId),
    ));
  }

  Future<void> _confirmBlock() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(t.chatBlockConfirmTitle(widget.otherName), style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        content: Text(t.chatBlockConfirmBody, style: HiType.body.copyWith(color: HiColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.chatBlockCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HiColors.error, foregroundColor: HiColors.textOnBrand),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.chatBlockConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).blockUser(widget.otherUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.chatBlocked(widget.otherName))));
      Navigator.of(context).pop(); // sortir de la conversation
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messagingErrorMessage(t, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: InkWell(
          onTap: _openProfile,
          child: Row(
            children: [
              if (_otherAvatar != null)
                HiAvatar(config: _otherAvatar!, rank: _otherRank, size: 32)
              else
                CircleAvatar(
                  radius: 16,
                  backgroundColor: HiColors.bgElevated,
                  child: Text(
                    widget.otherName.isNotEmpty ? widget.otherName.characters.first.toUpperCase() : '?',
                    style: HiType.caption.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(widget.otherName,
                    overflow: TextOverflow.ellipsis,
                    style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: HiColors.textSecondary),
            color: HiColors.bgElevated,
            onSelected: (v) {
              if (v == 'profile') _openProfile();
              if (v == 'block') _confirmBlock();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(children: [
                  Icon(Icons.person_outline_rounded, size: 18, color: HiColors.textSecondary),
                  const SizedBox(width: 10),
                  Text(t.chatViewProfile, style: HiType.body.copyWith(color: HiColors.textPrimary)),
                ]),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(children: [
                  Icon(Icons.block_rounded, size: 18, color: HiColors.error),
                  const SizedBox(width: 10),
                  Text(t.chatBlock, style: HiType.body.copyWith(color: HiColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
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
    if (_loading) return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
    if (_error != null) return Center(child: Text(_error!, style: HiType.body.copyWith(color: HiColors.error)));
    final items = _visible;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HiSpace.xl),
          child: Text(AppLocalizations.of(context).chatStartConversation(widget.otherName),
              textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textTertiary)),
        ),
      );
    }
    // Index du dernier message ENVOYÉ par moi (pour n'afficher l'accusé que sur celui-ci).
    int lastMineIdx = -1;
    for (var i = 0; i < items.length; i++) {
      if (items[i].isMine) lastMineIdx = i;
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(HiSpace.lg),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        final prev = i == 0 ? null : items[i - 1];
        final showSep = _needsDaySeparator(prev, m);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showSep) _daySeparator(m),
            _bubble(m, isLastMine: i == lastMineIdx),
          ],
        );
      },
    );
  }

  bool _needsDaySeparator(DmMessage? prev, DmMessage cur) {
    final curDay = _dayOf(cur.createdAt);
    if (curDay == null) return false;
    if (prev == null) return true;
    final prevDay = _dayOf(prev.createdAt);
    return prevDay == null || prevDay != curDay;
  }

  /// Jour local (yyyy-mm-dd) d'un timestamp ISO, ou null si non parsable.
  String? _dayOf(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;
    return '${dt.year}-${dt.month}-${dt.day}';
  }

  Widget _daySeparator(DmMessage m) {
    final t = AppLocalizations.of(context);
    final dt = DateTime.tryParse(m.createdAt)?.toLocal();
    String label;
    if (dt == null) {
      label = '';
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(day).inDays;
      if (diff == 0) {
        label = t.chatToday;
      } else if (diff == 1) {
        label = t.chatYesterday;
      } else {
        label = MaterialLocalizations.of(context).formatMediumDate(dt);
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: HiColors.bgElevated,
            borderRadius: BorderRadius.circular(HiRadius.pill),
            border: Border.all(color: HiColors.strokeSubtle),
          ),
          child: Text(label, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        ),
      ),
    );
  }

  String _timeLabel(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(dt),
        alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat);
  }

  Widget _bubble(DmMessage m, {required bool isLastMine}) {
    final t = AppLocalizations.of(context);
    final mine = m.isMine;
    final failed = m.status == DmSendStatus.failed;
    final pending = m.status == DmSendStatus.pending;

    final bubble = Semantics(
      button: failed,
      // Bulle en échec : tapable pour renvoyer → annoncée comme bouton « Renvoyer ».
      label: failed ? t.a11yRetryMessage : null,
      child: GestureDetector(
      onTap: failed ? () => _retry(m) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          gradient: mine && !failed ? HiColors.brandGradient : null,
          color: failed ? HiColors.error.withValues(alpha: 0.14) : (mine ? null : HiColors.bgElevated),
          borderRadius: BorderRadius.circular(HiRadius.md),
          border: mine && !failed ? null : Border.all(color: failed ? HiColors.error : HiColors.strokeSubtle),
        ),
        child: Opacity(
          opacity: pending ? 0.7 : 1,
          child: Text(m.body, style: HiType.body.copyWith(color: mine && !failed ? HiColors.textOnBrand : HiColors.textPrimary)),
        ),
      ),
    ),
    );

    // Méta sous la bulle : heure + (pour mon dernier message) statut d'envoi / accusé de lecture.
    final metaParts = <String>[];
    final time = _timeLabel(m.createdAt);
    if (time.isNotEmpty && !failed && !pending) metaParts.add(time);
    String? status;
    if (mine) {
      if (failed) {
        status = t.chatStatusFailed;
      } else if (pending) {
        status = t.chatStatusSending;
      } else if (isLastMine) {
        status = m.isRead ? t.chatStatusRead : t.chatStatusSent;
      }
    }
    // Pour les messages reçus, seule l'heure est affichée (pas de statut d'envoi).
    final metaColor = failed ? HiColors.error : HiColors.textTertiary;
    // a11y : heure + statut d'envoi regroupés → lus en une phrase. L'icône de statut (check/
    // done_all/schedule/error) est purement redondante avec le libellé texte → exclue.
    final meta = MergeSemantics(
      child: Padding(
      padding: EdgeInsets.only(top: 2, bottom: 4, left: mine ? 0 : 4, right: mine ? 4 : 0),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metaParts.isNotEmpty) Text(metaParts.join(' '), style: HiType.caption.copyWith(color: metaColor, fontSize: 11)),
          if (metaParts.isNotEmpty && status != null) ExcludeSemantics(child: Text('  ·  ', style: HiType.caption.copyWith(color: metaColor, fontSize: 11))),
          if (status != null) ...[
            ExcludeSemantics(
              child: failed
                  ? Icon(Icons.error_outline_rounded, size: 12, color: HiColors.error)
                  : pending
                      ? Icon(Icons.schedule_rounded, size: 12, color: metaColor)
                      : Icon(m.isRead ? Icons.done_all_rounded : Icons.check_rounded, size: 13, color: m.isRead ? HiColors.brandPrimary : metaColor),
            ),
            const SizedBox(width: 3),
            Text(status, style: HiType.caption.copyWith(color: failed ? HiColors.error : metaColor, fontSize: 11)),
          ],
        ],
      ),
    ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [bubble, meta],
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
            // Entrée = envoyer ; Maj+Entrée = nouvelle ligne (champ multi-lignes).
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _send();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                decoration: InputDecoration(hintText: AppLocalizations.of(context).chatHint, counterText: ''),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: AppLocalizations.of(context).a11ySend,
            icon: _sending
                ? ExcludeSemantics(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.brandPrimary)))
                : Icon(Icons.send_rounded, color: HiColors.brandPrimary, semanticLabel: AppLocalizations.of(context).a11ySend),
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
        Text(name, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        const SizedBox(width: 8),
        RankBadge(rank: rank, fontSize: 10),
      ]);
}
