import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/ui_state.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/hi_skeleton.dart';
import '../messaging/conversations_screen.dart';
import 'notification_settings_screen.dart';

/// Centre de notifications in-app : invitations de club en attente + déclencheurs d'engagement
/// évalués sur l'état courant + nouveaux messages. (L'envoi push FCM est prévu pour le mobile natif.)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  late Future<List<FeedItem>> _future;
  List<ClubInvite> _invites = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = ref.read(apiClientProvider).notificationsFeed();
    _loadInvites();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour au premier plan : on rafraîchit (le contexte a pu changer pendant l'absence).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refresh();
    }
  }

  /// Recharge feed + invitations et invalide le badge d'inbox (cloche). Sûr à appeler depuis
  /// le pull-to-refresh comme depuis le retour premier-plan.
  Future<void> _refresh() async {
    final feed = ref.read(apiClientProvider).notificationsFeed();
    setState(() => _future = feed);
    ref.invalidate(inboxBadgeProvider);
    ref.invalidate(unreadMessagesProvider);
    await Future.wait<void>([
      _loadInvites(),
      feed.then((_) {}).catchError((_) {}),
    ]);
  }

  Future<void> _loadInvites() async {
    try {
      final inv = await ref.read(apiClientProvider).myClubInvites();
      if (mounted) setState(() => _invites = inv);
    } catch (_) {/* réseau : on garde l'état courant */}
  }

  Future<void> _acceptInvite(ClubInvite inv) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).joinClub(inv.clubId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).notificationsJoinedClub(inv.clubName))));
      ref.invalidate(inboxBadgeProvider);
      await _loadInvites();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declineInvite(ClubInvite inv) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).declineClubInvite(inv.inviteId);
      ref.invalidate(inboxBadgeProvider);
      await _loadInvites();
    } catch (_) {/* best-effort */} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.notificationsTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: t.notificationsSettingsTooltip,
            icon: Icon(Icons.tune_rounded, color: HiColors.textTertiary),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: HiColors.brandPrimary,
          onRefresh: _refresh,
          child: FutureBuilder<List<FeedItem>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const HiListSkeleton(count: 6, itemHeight: 72);
              }
              if (snap.hasError) {
                // Scrollable pour permettre le pull-to-refresh même en erreur.
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    ErrorRetry(onRetry: _refresh),
                  ],
                );
              }
              final items = snap.data ?? [];
              final unread = ref.watch(unreadMessagesProvider).value ?? 0;

              // Ordre : invitations de club (action requise) → nouveaux messages → engagement.
              final widgets = <Widget>[
                for (final inv in _invites) _inviteCard(inv),
                if (unread > 0) _messagesCard(context, unread),
                for (final item in items) _tile(item),
              ];

              if (widgets.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Padding(
                      padding: const EdgeInsets.all(HiSpace.lg),
                      child: Text(t.notificationsEmpty,
                          textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textTertiary)),
                    ),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(HiSpace.lg),
                itemCount: widgets.length,
                separatorBuilder: (_, __) => const SizedBox(height: HiSpace.sm),
                itemBuilder: (_, i) => widgets[i],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Invitation à un club en attente → rejoindre / refuser directement depuis les notifications.
  Widget _inviteCard(ClubInvite inv) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.brandSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.brandSecondary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_rounded, color: HiColors.brandSecondaryText, size: 22),
              const SizedBox(width: HiSpace.md),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.notificationsClubInviteTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(t.notificationsClubInviteMembers(inv.clubName, inv.memberCount),
                          style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiColors.brandSecondary,
                    foregroundColor: HiColors.textOnBrand,
                  ),
                  onPressed: _busy ? null : () => _acceptInvite(inv),
                  child: Text(t.notificationsJoin),
                ),
              ),
              const SizedBox(width: HiSpace.sm),
              OutlinedButton(
                onPressed: _busy ? null : () => _declineInvite(inv),
                child: Text(t.notificationsDecline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Carte « nouveaux messages » → ouvre les conversations.
  Widget _messagesCard(BuildContext context, int unread) {
    final t = AppLocalizations.of(context);
    // a11y : carte cliquable → rôle bouton + libellé regroupant titre + corps.
    return Semantics(
      button: true,
      label: '${t.notificationsNewMessages(unread)}. ${t.notificationsNewMessagesBody}',
      child: ExcludeSemantics(
      child: InkWell(
      borderRadius: BorderRadius.circular(HiRadius.md),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversationsScreen()));
        if (!mounted) return;
        ref.invalidate(unreadMessagesProvider);
        ref.invalidate(inboxBadgeProvider);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(HiSpace.md),
        decoration: BoxDecoration(
          color: HiColors.brandPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(HiRadius.md),
          border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.forum_rounded, color: HiColors.brandPrimary, size: 22),
            const SizedBox(width: HiSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.notificationsNewMessages(unread),
                      style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(t.notificationsNewMessagesBody,
                      style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
          ],
        ),
      ),
    ),
    ),
    );
  }

  /// Résout (title, body) d'un item du feed. Priorité à key+params (localisé) ; repli sur les
  /// champs title/body hérités si l'API renvoie encore une phrase en dur (compat).
  (String, String) _resolve(FeedItem item) {
    final t = AppLocalizations.of(context);
    switch (item.key) {
      case 'week-almost-complete':
        return (t.feedWeekAlmostTitle, t.feedWeekAlmostBody(item.intParam('count'), item.intParam('goal')));
      case 'week-validated':
        return (t.feedWeekValidatedTitle, t.feedWeekValidatedBody(item.intParam('streak')));
      case 'next-rank-close':
        return (t.feedNextRankTitle(item.strParam('rank')), t.feedNextRankBody(item.intParam('points')));
      case 'rank-overtaken':
        final c = item.intParam('count', 1);
        return (t.feedRankOvertakenTitle(c), t.feedRankOvertakenBody);
      case 'wod-overtaken':
        final c = item.intParam('count', 1);
        return (t.feedWodOvertakenTitle(c), t.feedWodOvertakenBody);
      // Notifications sociales (si le back les expose un jour dans le feed in-app ; sinon délivrées
      // en push uniquement — cf. push_service.dart). On résout titre + corps localisés FR/EN.
      case 'post-kudos':
        return (t.notifPostKudos, t.notifPostKudosBody(item.intParam('count', 1)));
      case 'comment':
        return (t.notifComment, t.notifCommentBody(item.strParam('name')));
      case 'comment-kudos':
        return (t.notifCommentKudos, t.notifCommentKudosBody(item.intParam('count', 1)));
      case 'comment-reply':
        return (t.notifReply, t.notifReplyBody(item.strParam('name')));
      case 'mention':
        return (t.notifMention, t.notifMentionBody(item.strParam('name')));
      default:
        // Compat : item hérité avec phrases en dur, ou clé inconnue → on affiche ce qu'on a.
        return (item.title ?? item.key, item.body ?? '');
    }
  }

  Widget _tile(FeedItem item) {
    final (title, body) = _resolve(item);
    final color = item.priority == 'high'
        ? HiColors.brandPrimary
        : (item.priority == 'low' ? HiColors.textTertiary : HiColors.brandSecondary);
    // Tuile actionnable : si une route est fournie par l'API (ex. dépassement au classement → Ligue),
    // on rend la carte cliquable avec un chevron ; sinon elle reste informative.
    final hasRoute = _tabForRoute(item.route) != null;
    final card = Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_rounded, color: color, size: 22),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: 2),
                Text(body, style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              ],
            ),
          ),
          if (hasRoute) ...[
            const SizedBox(width: HiSpace.sm),
            Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
          ],
        ],
      ),
    );
    // a11y : carte info regroupée ; si actionnable (route) → annoncée comme bouton.
    if (!hasRoute) return MergeSemantics(child: card);
    return Semantics(
      button: true,
      label: '$title. $body',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(HiRadius.md),
          onTap: () => _openRoute(item.route!),
          child: card,
        ),
      ),
    );
  }

  /// Mappe la route logique de l'API vers l'onglet correspondant du HomeShell.
  /// 'league' et 'leaderboard' partagent l'onglet Classement/Ligue (index 3).
  int? _tabForRoute(String? route) {
    switch (route) {
      case 'league':
      case 'leaderboard':
        return 3;
      case 'community':
        return 2; // fil d'actualité (likes / commentaires / réponses / mentions)
      default:
        return null;
    }
  }

  /// Ouvre la zone ciblée : bascule l'onglet du HomeShell puis dépile jusqu'à l'accueil
  /// (NotificationsScreen est une route poussée → on revient au shell avec le bon onglet actif).
  void _openRoute(String route) {
    final tab = _tabForRoute(route);
    if (tab == null) return;
    ref.read(homeTabProvider.notifier).state = tab;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}
