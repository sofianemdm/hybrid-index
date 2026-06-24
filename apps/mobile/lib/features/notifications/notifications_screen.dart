import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../messaging/conversations_screen.dart';
import 'notification_settings_screen.dart';

/// Centre de notifications in-app : déclencheurs d'engagement évalués sur l'état courant.
/// (L'envoi push FCM est prévu pour la version mobile native.)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<FeedItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).notificationsFeed();
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
            final items = snap.data!;
            final unread = ref.watch(unreadMessagesProvider).value ?? 0;
            if (items.isEmpty && unread == 0) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text(t.notificationsEmpty,
                      textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textTertiary)),
                ),
              );
            }
            final hasMsg = unread > 0;
            return ListView.separated(
              padding: const EdgeInsets.all(HiSpace.lg),
              itemCount: items.length + (hasMsg ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: HiSpace.sm),
              itemBuilder: (_, i) {
                if (hasMsg && i == 0) return _messagesCard(context, unread);
                return _tile(items[i - (hasMsg ? 1 : 0)]);
              },
            );
          },
        ),
      ),
    );
  }

  /// Carte « nouveaux messages » en tête des notifications → ouvre les conversations.
  Widget _messagesCard(BuildContext context, int unread) {
    final t = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(HiRadius.md),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversationsScreen()));
        if (!mounted) return;
        ref.invalidate(unreadMessagesProvider);
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
