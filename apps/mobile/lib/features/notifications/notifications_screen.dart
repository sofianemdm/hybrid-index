import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../messaging/conversations_screen.dart';
import 'notification_settings_screen.dart';

/// Centre de notifications in-app : invitations de club en attente + déclencheurs d'engagement
/// évalués sur l'état courant + nouveaux messages. (L'envoi push FCM est prévu pour le mobile natif.)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<FeedItem>> _future;
  List<ClubInvite> _invites = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).notificationsFeed();
    _loadInvites();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tu as rejoint ${inv.clubName} !')));
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
        child: FutureBuilder<List<FeedItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
            }
            if (snap.hasError) {
              return Center(child: Text('${snap.error}', style: HiType.body.copyWith(color: HiColors.error)));
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text(t.notificationsEmpty,
                      textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textTertiary)),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(HiSpace.lg),
              itemCount: widgets.length,
              separatorBuilder: (_, __) => const SizedBox(height: HiSpace.sm),
              itemBuilder: (_, i) => widgets[i],
            );
          },
        ),
      ),
    );
  }

  /// Invitation à un club en attente → rejoindre / refuser directement depuis les notifications.
  Widget _inviteCard(ClubInvite inv) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invitation à un club', style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${inv.clubName} · ${inv.memberCount} membre${inv.memberCount > 1 ? 's' : ''}',
                        style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                  ],
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
                  child: const Text('Rejoindre'),
                ),
              ),
              const SizedBox(width: HiSpace.sm),
              OutlinedButton(
                onPressed: _busy ? null : () => _declineInvite(inv),
                child: const Text('Refuser'),
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
    return InkWell(
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
    );
  }

  Widget _tile(FeedItem item) {
    final color = item.priority == 'high'
        ? HiColors.brandPrimary
        : (item.priority == 'low' ? HiColors.textTertiary : HiColors.brandSecondary);
    return Container(
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
                Text(item.title, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: 2),
                Text(item.body, style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
