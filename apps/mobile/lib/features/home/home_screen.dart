import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/index_ring.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/rank_badge.dart';
import '../avatar/avatar_editor_screen.dart';
import '../coach/coach_screen.dart';
import '../history/history_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../share/share_card_screen.dart';

/// Accueil : Index courant, rang, radar. Tire-pour-rafraîchir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final session = ref.watch(sessionProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          await ref.read(myProfileProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AvatarEditorScreen()),
                  ),
                  child: ref.watch(avatarProvider).maybeWhen(
                        data: (a) => HiAvatar(
                          config: a,
                          rank: profileAsync.value?.index.rank ?? 'rookie',
                          size: 48,
                        ),
                        orElse: () => const SizedBox(width: 48, height: 48),
                      ),
                ),
                const SizedBox(width: HiSpace.sm),
                Expanded(
                  child: Text(
                    'Salut, ${session.user?.displayName ?? ''}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HiColors.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_none, color: HiColors.textTertiary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                IconButton(
                  tooltip: 'Paramètres',
                  icon: const Icon(Icons.settings_outlined, color: HiColors.textTertiary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HiSpace.md),
            profileAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _errorBox('$e'),
              data: (p) => p == null ? _errorBox('Profil indisponible.') : _content(context, ref, p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, Profile p) {
    return Column(
      children: [
        Center(child: IndexRing(value: p.index.value, percentile: p.index.percentile, size: 220)),
        const SizedBox(height: HiSpace.md),
        Center(child: RankBadge(rank: p.index.rank, fontSize: 15)),
        const SizedBox(height: HiSpace.lg),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: HiColors.strokeStrong),
            foregroundColor: HiColors.brandPrimary,
          ),
          icon: const Icon(Icons.fitness_center),
          label: const Text('Coach — progresser sur un axe'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CoachScreen()),
          ),
        ),
        const SizedBox(height: HiSpace.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: HiColors.strokeStrong),
            foregroundColor: HiColors.textPrimary,
          ),
          icon: const Icon(Icons.ios_share),
          label: const Text('Partager ma carte'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShareCardScreen()),
          ),
        ),
        const SizedBox(height: HiSpace.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: HiColors.strokeStrong),
            foregroundColor: HiColors.textPrimary,
          ),
          icon: const Icon(Icons.history),
          label: const Text('Mon historique de WODs'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
        ),
        const SizedBox(height: HiSpace.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(HiSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ton radar',
                    style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: HiSpace.sm),
                RadarView(radar: p.radar),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HiRadius.md),
      ),
      child: Text(message, style: const TextStyle(color: HiColors.error)),
    );
  }
}

