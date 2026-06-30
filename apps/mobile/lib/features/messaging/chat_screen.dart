import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/realtime_service.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_skeleton.dart';
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
  StreamSubscription<RealtimeEvent>? _rtSub;
  // Pagination « charger les messages précédents » (scroll vers le haut).
  bool _hasMore = false;
  String? _nextBefore;
  bool _loadingMore = false;
  // Indicateur de saisie de l'autre (éphémère, non persisté). Affiché tant que des signaux
  // arrivent ; éteint par [_typingOff] après ~3 s sans nouveau signal.
  bool _otherTyping = false;
  Timer? _typingOff;
  // Débounce du canal MONTANT : on n'émet « typing » qu'au plus une fois toutes les ~2 s tant que
  // l'utilisateur tape (évite d'inonder le WS à chaque touche).
  DateTime? _lastTypingSent;
  // Un message est arrivé en temps réel alors que l'utilisateur lisait l'historique (pas en bas) :
  // on N'AUTO-SCROLLE PAS (on ne l'arrache pas à sa lecture) et on affiche une pastille « nouveau
  // message » qui, au tap, le ramène en bas. Remise à false dès qu'il revient en bas.
  bool _newBelow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _convId = widget.conversationId;
    // Signale au reste de l'app que CETTE conversation est à l'écran → le bandeau in-app temps réel
    // ne s'affichera pas pour ses messages (ils apparaissent déjà directement dans le fil ci-dessous).
    if (_convId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(activeConversationProvider.notifier).state = _convId;
      });
    }
    _scroll.addListener(_onScroll);
    _load();
    _startPolling();
    // Temps réel (on ne réagit qu'aux events de LA conversation ouverte ; les autres sont ignorés) :
    // - DmReceived avec message → APPEND DIRECT (zéro REST). Sans message → repli `_pollMessages`.
    // - ReadReceipt : le destinataire a lu → mes bulles passent « Envoyé » → « Lu » sans attendre.
    // - TypingSignal : l'autre écrit → on affiche l'indicateur, éteint après ~3 s sans signal.
    _rtSub = ref.read(realtimeServiceProvider).events.listen((e) {
      if (_convId == null) return;
      switch (e) {
        case DmReceived(:final conversationId, :final message) when conversationId == _convId:
          if (message != null) {
            _appendRealtime(message);
          } else {
            _pollMessages(); // ancienne trame sans contenu : repli refetch
          }
        case ReadReceipt(:final conversationId) when conversationId == _convId:
          _markAllMineRead();
        case TypingSignal(:final conversationId) when conversationId == _convId:
          _onOtherTyping();
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // On quitte le chat → plus aucune conversation « active » (les futurs DM repassent par le bandeau).
    // `_convId` peut être resté null jusqu'au 1er envoi : on n'efface que si on l'avait posé.
    final active = ref.read(activeConversationProvider);
    if (active != null && active == _convId) {
      ref.read(activeConversationProvider.notifier).state = null;
    }
    _poll?.cancel();
    _typingOff?.cancel();
    _rtSub?.cancel();
    _input.dispose();
    _scroll.removeListener(_onScroll);
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
    // Repli RALENTI (5 s) : l'instantanéité est portée par le WebSocket (un DM déclenche un poll
    // immédiat). Si le WS est down (web/prod/réseau), ce poll assure quand même la livraison.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollMessages());
  }

  /// Liste affichée = messages serveur + messages optimistes en attente/échec (à la fin).
  List<DmMessage> get _visible => [..._messages, ..._pending];

  /// Rafraîchit silencieusement les messages (n'affiche ni spinner ni erreur ; n'écrase pas une
  /// saisie en cours). Met à jour la pastille de non-lus globale au passage.
  Future<void> _pollMessages() async {
    if (_convId == null || _sending || _loadingMore) return;
    // Le poll ne récupère QUE la page la plus récente. Si l'utilisateur a remonté l'historique
    // (chargé des pages antérieures et pas revenu en bas), on ne remplace pas la liste : cela
    // écraserait l'historique chargé et le téléporterait. On ne poll « activement » que près du bas.
    final atBottom = _isNearBottom();
    if (!atBottom) return;
    try {
      final c = await ref.read(apiClientProvider).conversationMessages(_convId!);
      if (!mounted) return;
      // On rafraîchit si le nombre de messages change OU si un accusé de lecture a évolué
      // (pour faire passer « Envoyé » → « Lu » sur mon dernier message).
      if (_serverStateChanged(c.messages)) {
        setState(() {
          _messages = c.messages;
          _hasMore = c.hasMore;
          _nextBefore = c.nextBefore;
        });
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

  /// AJOUT DIRECT d'un message reçu en temps réel (Incrément 1) — aucun round-trip REST.
  ///
  /// - DÉDUP PAR ID : si le message est déjà présent (poll/optimiste déjà confirmé) on l'ignore.
  /// - RÉCONCILIATION OPTIMISTE : un de MES messages qui revient par le WS (multi-device) retire la
  ///   bulle optimiste `tmp_…` correspondante (même corps, statut en attente) pour éviter le doublon.
  /// - ORDRE : insertion stable triée par (`createdAt`, `id`) — le serveur garantit déjà cet ordre,
  ///   mais on l'impose côté client pour rester robuste aux trames hors séquence.
  /// - SCROLL : auto-scroll en bas SEULEMENT si l'utilisateur y est déjà ; sinon pastille `_newBelow`.
  /// - LU : un message reçu (non mien) marque la conversation comme consultée (pastille inbox à jour).
  void _appendRealtime(DmMessage incoming) {
    if (!mounted) return;
    // Déjà connu (poll ou send REST a déjà inséré la vérité serveur) → rien à faire.
    if (_messages.any((m) => m.id == incoming.id)) return;

    final wasAtBottom = _isNearBottom();
    setState(() {
      // Si c'est mon propre message (autre device / écho serveur), purger l'optimiste équivalent.
      if (incoming.isMine) {
        final i = _pending.indexWhere(
          (p) => p.id.startsWith('tmp_') && p.body == incoming.body && p.status != DmSendStatus.failed,
        );
        if (i != -1) _pending.removeAt(i);
      }
      _insertSorted(incoming);
      if (!incoming.isMine && !wasAtBottom) _newBelow = true;
    });

    // L'utilisateur est en bas (ou vient d'envoyer) → on colle au dernier message.
    if (wasAtBottom) _jumpToEnd();
    // MARQUAGE LU (comme avant) : si l'utilisateur REGARDE la conversation (en bas), le message
    // reçu doit passer « lu » côté serveur. On déclenche un marquage léger SANS écraser le fil
    // (le contenu est déjà affiché par l'append direct ; cet appel sert UNIQUEMENT à poser le
    // `readAt` serveur + rafraîchir la pastille globale). Hors bas, on laisse non-lu (pastille).
    if (!incoming.isMine && wasAtBottom) {
      _markConversationRead();
    } else {
      // Compteur global possiblement à jour (nouveau non-lu) → on resynchronise la pastille.
      ref.invalidate(unreadMessagesProvider);
    }
  }

  /// Marque la conversation comme lue côté serveur (le backend pose `readAt` sur la page récente à
  /// chaque lecture). On NE remplace PAS `_messages` ici : l'append direct fait déjà foi pour
  /// l'affichage ; on se contente d'aligner les accusés de lecture + la pastille globale. Best-effort.
  Future<void> _markConversationRead() async {
    if (_convId == null) return;
    try {
      final c = await ref.read(apiClientProvider).conversationMessages(_convId!);
      if (!mounted) return;
      // On réaligne discrètement les `readAt` si le serveur en a posé de nouveaux, sans casser
      // l'ordre déjà en place (même ensemble d'ids attendu sur la page courante).
      if (_serverStateChanged(c.messages) && _isNearBottom()) {
        setState(() {
          _messages = c.messages;
          _hasMore = c.hasMore;
          _nextBefore = c.nextBefore;
        });
      }
      ref.invalidate(unreadMessagesProvider);
    } catch (_) {
      // silencieux : le marquage « lu » est best-effort, le repli polling rattrapera.
    }
  }

  /// Insère [m] dans `_messages` en respectant l'ordre (`createdAt`, `id`). Liste quasi triée et
  /// petite (page courante) → un parcours linéaire suffit largement.
  void _insertSorted(DmMessage m) {
    var idx = _messages.length;
    for (var i = 0; i < _messages.length; i++) {
      if (_compareMessages(m, _messages[i]) < 0) {
        idx = i;
        break;
      }
    }
    _messages.insert(idx, m);
  }

  /// Ordre stable : d'abord `createdAt` (ISO comparable lexicographiquement à précision égale),
  /// puis `id` comme départage déterministe (aligné sur le tri backend).
  int _compareMessages(DmMessage a, DmMessage b) {
    final byDate = a.createdAt.compareTo(b.createdAt);
    if (byDate != 0) return byDate;
    return a.id.compareTo(b.id);
  }

  /// Lecture temps réel : à réception d'un `ReadReceipt`, on marque localement comme lus TOUS mes
  /// messages encore non lus (le serveur a posé leur `readAt` à l'ouverture par l'autre). Évite
  /// d'attendre le poll et fonctionne même si l'utilisateur n'est pas en bas du fil (le poll, lui,
  /// ne rafraîchit que près du bas). No-op si rien à changer (pas de setState inutile).
  void _markAllMineRead() {
    final now = DateTime.now().toIso8601String();
    var changed = false;
    final updated = _messages.map((m) {
      if (m.isMine && !m.isRead) {
        changed = true;
        return m.copyWith(readAt: now);
      }
      return m;
    }).toList();
    if (changed && mounted) setState(() => _messages = updated);
  }

  /// Affiche l'indicateur « l'autre écrit » et (ré)arme l'extinction à ~3 s sans nouveau signal.
  void _onOtherTyping() {
    if (!mounted) return;
    if (!_otherTyping) setState(() => _otherTyping = true);
    _typingOff?.cancel();
    _typingOff = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _otherTyping = false);
    });
  }

  /// Canal MONTANT débounce : signale ma saisie au serveur au plus une fois toutes les ~2 s tant
  /// que je tape (le serveur relaie à l'autre). N'émet rien si le champ est vide.
  void _onInputChanged(String value) {
    if (value.trim().isEmpty) return;
    final now = DateTime.now();
    if (_lastTypingSent != null && now.difference(_lastTypingSent!) < const Duration(seconds: 2)) {
      return;
    }
    _lastTypingSent = now;
    if (_convId != null) ref.read(realtimeServiceProvider).sendTyping(_convId!);
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
          _hasMore = c.hasMore;
          _nextBefore = c.nextBefore;
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

  /// L'utilisateur est-il (quasi) en bas du fil ? Sert à décider de coller au bas sur nouveau
  /// message reçu (poll) sans interrompre la relecture de l'historique. Seuil = ~120 px.
  /// Avant le 1er layout (pas de clients), on considère « en bas » (cas du chargement initial).
  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    final p = _scroll.position;
    return p.maxScrollExtent - p.pixels < 120;
  }

  /// Détecte le scroll vers le HAUT (proche de l'offset 0) pour charger la page antérieure, et
  /// éteint la pastille « nouveau message » dès que l'utilisateur revient (quasi) en bas du fil.
  void _onScroll() {
    if (_newBelow && _isNearBottom() && mounted) setState(() => _newBelow = false);
    if (!_scroll.hasClients || !_hasMore || _loadingMore) return;
    if (_scroll.position.pixels <= 80) _loadMore();
  }

  /// « Charger les messages précédents » : récupère la page ANTÉRIEURE (curseur `_nextBefore`) et
  /// la PRÉPEND, en préservant la position de lecture (on compense le saut de hauteur introduit).
  Future<void> _loadMore() async {
    if (_convId == null || !_hasMore || _loadingMore || _nextBefore == null) return;
    setState(() => _loadingMore = true);
    final beforeExtent = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final beforePixels = _scroll.hasClients ? _scroll.position.pixels : 0.0;
    try {
      final c = await ref.read(apiClientProvider).conversationMessages(_convId!, before: _nextBefore);
      if (!mounted) return;
      setState(() {
        _messages = [...c.messages, ..._messages]; // prépend les plus anciens
        _hasMore = c.hasMore;
        _nextBefore = c.nextBefore;
      });
      // Préserver la position : après l'ajout en tête, maxScrollExtent grandit ; on décale les
      // pixels du même delta pour que le message qui était sous les yeux ne bouge pas.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final delta = _scroll.position.maxScrollExtent - beforeExtent;
        _scroll.jumpTo((beforePixels + delta).clamp(0.0, _scroll.position.maxScrollExtent));
      });
    } catch (_) {
      // silencieux : pas de page chargée, l'utilisateur peut réessayer en re-scrollant.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
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
      // Première conversation créée à l'envoi : on la marque « active » pour que le bandeau in-app
      // n'apparaisse pas sur ses propres messages (réception multi-device / écho serveur).
      ref.read(activeConversationProvider.notifier).state = _convId;
      HiHaptics.success();
      final c = await api.conversationMessages(_convId!);
      if (mounted) {
        setState(() {
          _messages = c.messages; // vérité serveur (page la plus récente)
          _otherAvatar = c.otherAvatar;
          _otherRank = c.otherRank;
          _hasMore = c.hasMore;
          _nextBefore = c.nextBefore;
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
            Expanded(
              child: Stack(
                children: [
                  _body(),
                  // Pastille « nouveau message » : visible seulement si un DM est arrivé pendant que
                  // l'utilisateur lisait l'historique (pas en bas). Tap → retour en bas + extinction.
                  if (_newBelow)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Center(child: _newBelowPill(t)),
                    ),
                ],
              ),
            ),
            _typingIndicator(),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const HiListSkeleton(count: 6, itemHeight: 48);
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
    // Un en-tête de chargement « messages précédents » occupe l'index 0 quand il reste de l'historique.
    final hasHeader = _hasMore || _loadingMore;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(HiSpace.lg),
      itemCount: items.length + (hasHeader ? 1 : 0),
      itemBuilder: (context, rawIndex) {
        if (hasHeader && rawIndex == 0) return _loadMoreHeader();
        final i = hasHeader ? rawIndex - 1 : rawIndex;
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

  /// En-tête de liste : indicateur « charger les messages précédents » (tap ou scroll vers le haut).
  Widget _loadMoreHeader() {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _loadMore,
                child: Text(t.chatLoadOlder,
                    style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              ),
      ),
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

  /// Ligne « X est en train d'écrire… » (éphémère). Réserve sa hauteur en permanence pour éviter
  /// que le composer ne saute quand l'indicateur apparaît/disparaît.
  Widget _typingIndicator() {
    final t = AppLocalizations.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: _otherTyping
          ? Padding(
              key: const ValueKey('typing'),
              padding: const EdgeInsets.only(left: HiSpace.lg, right: HiSpace.lg, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.chatTyping(widget.otherName),
                  style: HiType.caption.copyWith(color: HiColors.textTertiary, fontStyle: FontStyle.italic),
                ),
              ),
            )
          : const SizedBox(key: ValueKey('no-typing'), height: 0, width: double.infinity),
    );
  }

  /// Pastille flottante « nouveau message » (tap → bas du fil). Apparaît quand un DM arrive en
  /// temps réel alors qu'on lit l'historique, pour ne pas téléporter l'utilisateur sans son accord.
  Widget _newBelowPill(AppLocalizations t) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HiRadius.pill),
        onTap: () {
          if (mounted) setState(() => _newBelow = false);
          _jumpToEnd();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: HiColors.brandPrimary,
            borderRadius: BorderRadius.circular(HiRadius.pill),
            boxShadow: HiShadow.glowBrand(0.35),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward_rounded, size: 16, color: HiColors.textOnBrand),
              const SizedBox(width: 6),
              Text(t.chatNewMessage,
                  style: HiType.caption.copyWith(color: HiColors.textOnBrand, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
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
                onChanged: _onInputChanged,
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
