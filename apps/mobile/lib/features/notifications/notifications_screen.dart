import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
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
            if (items.isEmpty) {
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
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: HiSpace.sm),
              itemBuilder: (_, i) => _tile(items[i]),
            );
          },
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
