import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/realtime_service.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_empty_state.dart';
import '../../widgets/rank_badge.dart';
import '../community/explore_screen.dart';
import 'chat_screen.dart';

/// Boîte de réception : liste des conversations privées (les plus récentes d'abord).
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  late Future<List<ConversationSummary>> _future;
  List<ConversationSummary>? _last; // dernier résultat connu (anti-flicker pendant le refresh auto)
  Timer? _poll;
  StreamSubscription<RealtimeEvent>? _rtSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Temps réel : tout DM (reçu OU envoyé sur un autre device) met à jour la liste IMMÉDIATEMENT.
    // Le message complet (Incrément 1) nous permet de patcher la conversation concernée SANS attendre
    // le REST (aperçu + non-lus + remontée en tête instantanés). On déclenche tout de même un refetch
    // léger en arrière-plan pour réconcilier (nom/avatar d'une toute nouvelle conversation, etc.).
    // Le polling ci-dessous reste le REPLI (si le WS n'est pas connecté).
    _rtSub = ref.read(realtimeServiceProvider).events.listen((e) {
      if (e is! DmReceived || !mounted) return;
      final patched = _patchLocally(e);
      // Réconciliation REST : indispensable si la conversation est inconnue localement (nouvelle),
      // sinon best-effort (le patch local a déjà donné l'instantanéité).
      if (!patched) {
        setState(_load);
      } else {
        _reconcileSilently();
      }
    });
    // Repli : auto-refresh RALENTI (10 s) — l'instantanéité est désormais portée par le WebSocket.
    // Si le WS est down (web/prod/réseau), ce poll assure quand même la livraison.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(_load);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _rtSub?.cancel();
    super.dispose();
  }

  void _load() => _future = ref.read(apiClientProvider).conversations();

  /// Patch LOCAL instantané de la conversation concernée par [e] à partir du message temps réel :
  /// met à jour l'aperçu (`lastBody`/`lastIsMine`), incrémente les non-lus (si le message n'est pas
  /// de moi) et remonte la conversation EN TÊTE — le tout sans REST. Renvoie `false` si la
  /// conversation est inconnue localement (nouvelle) ou si le message manque : l'appelant retombe
  /// alors sur un refetch complet.
  bool _patchLocally(DmReceived e) {
    final msg = e.message;
    if (msg == null) return false;
    final current = _last;
    if (current == null) return false;
    final idx = current.indexWhere((c) => c.id == e.conversationId);
    if (idx == -1) return false; // conversation absente de la liste → besoin d'un refetch

    final old = current[idx];
    final updated = ConversationSummary(
      id: old.id,
      otherUserId: old.otherUserId,
      otherName: old.otherName,
      otherRank: old.otherRank,
      otherIndex: old.otherIndex,
      otherAvatar: old.otherAvatar,
      lastBody: msg.body,
      lastIsMine: msg.isMine,
      // Un message reçu (non mien) ajoute un non-lu ; un message à moi (autre device) n'en ajoute pas.
      unread: msg.isMine ? old.unread : old.unread + 1,
    );
    final next = [updated, ...current.where((c) => c.id != old.id)];
    setState(() {
      _last = next;
      _future = Future.value(next); // le FutureBuilder reflète immédiatement la liste patchée
    });
    ref.invalidate(unreadMessagesProvider);
    return true;
  }

  /// Refetch REST silencieux (anti-flicker) pour réconcilier la liste après un patch local optimiste
  /// (corrige d'éventuels écarts : non-lus exacts, horodatage, conversations modifiées ailleurs).
  void _reconcileSilently() {
    if (mounted) setState(_load);
  }

  Future<void> _open(ConversationSummary c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(conversationId: c.id, otherUserId: c.otherUserId, otherName: c.otherName),
    ));
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.conversationsTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(_load);
            await _future;
          },
          child: FutureBuilder<List<ConversationSummary>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasData) _last = snap.data;
              // Skeleton uniquement au TOUT premier chargement (pas à chaque refresh auto de 3 s).
              if (snap.connectionState == ConnectionState.waiting && _last == null) {
                return const HiListSkeleton(count: 6, itemHeight: 64);
              }
              // Erreur affichée seulement si on n'a encore rien à montrer (sinon on garde la liste).
              if (snap.hasError && _last == null) {
                return ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(HiSpace.lg),
                    child: Text(messagingErrorMessage(t, snap.error!), style: HiType.body.copyWith(color: HiColors.error)),
                  ),
                ]);
              }
              final items = snap.data ?? _last ?? const <ConversationSummary>[];
              if (items.isEmpty) {
                return ListView(children: [
                  const SizedBox(height: 48),
                  HiEmptyState(
                    icon: Icons.forum_rounded,
                    title: t.conversationsTitle,
                    message: t.conversationsEmpty,
                    ctaLabel: t.communityTooltipSearch,
                    ctaIcon: Icons.search_rounded,
                    onCta: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExploreScreen()),
                    ),
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
    final t = AppLocalizations.of(context);
    final preview = c.lastBody == null ? '' : '${c.lastIsMine ? t.conversationsYouPrefix : ''}${c.lastBody}';
    // a11y : toute la ligne (nom + rang + aperçu + non-lus) lue en un seul bloc par le lecteur.
    return MergeSemantics(
      child: Card(
      color: HiColors.bgElevated,
      child: ListTile(
        leading: c.otherAvatar != null
            ? HiAvatar(config: c.otherAvatar!, rank: c.otherRank, size: 40)
            : CircleAvatar(
                radius: 20,
                backgroundColor: HiColors.bgBase,
                child: Text(
                  c.otherName.isNotEmpty ? c.otherName.characters.first.toUpperCase() : '?',
                  style: HiType.titleM.copyWith(color: HiColors.textPrimary),
                ),
              ),
        title: Row(children: [
          Flexible(
            child: Text(c.otherName,
                overflow: TextOverflow.ellipsis,
                style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          RankBadge(rank: c.otherRank, ovr: c.otherIndex, fontSize: 9),
        ]),
        subtitle: Text(preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        trailing: c.unread > 0
            ? Semantics(
                label: t.a11yUnreadCount(c.unread),
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: HiColors.brandPrimary, shape: BoxShape.circle),
                    child: Text('${c.unread}',
                        style: TextStyle(color: HiColors.textOnBrand, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              )
            : Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
        onTap: () => _open(c),
      ),
    ),
    );
  }
}
