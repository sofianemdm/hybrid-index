import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/hi_card.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/index_ring.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/social_proof_card.dart';
import '../../widgets/streak_chip.dart';
import 'grade_block.dart';
import 'rival_card.dart';
import 'weekly_recap_card.dart';
import '../avatar/avatar_editor_screen.dart';
import '../coach/coach_screen.dart';
import '../history/history_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../notifications/notifications_screen.dart';
import '../challenge/challenge_screen.dart';
import '../settings/settings_screen.dart';
import '../share/share_card_screen.dart';
import 'score_v2_banner.dart';

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
          ref.invalidate(streakProvider);
          ref.invalidate(weeklyRecapProvider);
          await ref.read(myProfileProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
          children: [
            const ScoreV2BannerLauncher(),
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
                    style: HiType.titleL.copyWith(color: HiColors.textPrimary),
                  ),
                ),
                // Flamme de série hebdomadaire (discrète, non bloquante).
                ref.watch(streakProvider).maybeWhen(
                      data: (s) => s == null ? const SizedBox.shrink() : StreakChip(streak: s),
                      orElse: () => const SizedBox.shrink(),
                    ),
                const SizedBox(width: HiSpace.xs),
                IconButton(
                  tooltip: 'Notifications',
                  icon: Icon(Icons.notifications_rounded, color: HiColors.textSecondary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                IconButton(
                  tooltip: 'Paramètres',
                  icon: Icon(Icons.settings_rounded, color: HiColors.textSecondary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HiSpace.md),
            profileAsync.when(
              loading: () => const HomeSkeleton(),
              error: (e, _) => _errorBox('$e'),
              data: (p) => p == null ? _errorBox('Profil indisponible.') : _content(context, ref, p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, Profile p) {
    final stale = p.radar.where((a) => a.unlocked && a.isStale).toList();
    return Column(
      children: [
        const ChallengeBanner(),
        // HÉROS : l'Index domine l'écran (264 + glow), le grade chevauche le bas de l'anneau.
        Center(child: IndexRing(value: p.index.value, percentile: p.index.percentile)),
        const SizedBox(height: HiSpace.md),
        GradeBlock(profile: p),
        const SizedBox(height: HiSpace.lg),
        // Rival amical (ou état meneur) — la comparaison sociale, ton bienveillant.
        if (p.leaguePosition != null) ...[
          RivalCard(
            rival: p.rival,
            leaguePosition: p.leaguePosition,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          const SizedBox(height: HiSpace.md),
        ],
        // Récap « Ta semaine » (affiché seulement s'il y a du contenu).
        ref.watch(weeklyRecapProvider).maybeWhen(
              data: (r) => r != null && r.hasContent
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: HiSpace.md),
                      child: WeeklyRecapCard(recap: r),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
        // Fraîcheur : incite au re-test sans culpabiliser (le score ne baisse jamais).
        if (stale.isNotEmpty) ...[
          _freshnessBanner(context, stale),
          const SizedBox(height: HiSpace.md),
        ],
        if (p.socialProof != null) ...[
          SocialProofCard(proof: p.socialProof!),
          const SizedBox(height: HiSpace.md),
        ],
        // Radar (touchable → coach de l'axe).
        HiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TON RADAR', style: HiType.overline.copyWith(color: HiColors.textSecondary)),
              const SizedBox(height: 2),
              Text('Touche une qualité pour voir les séances qui la boostent.',
                  style: HiType.caption.copyWith(color: HiColors.textTertiary)),
              const SizedBox(height: HiSpace.sm),
              RadarView(
                radar: p.radar,
                onTapAttribute: (attr) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CoachScreen(initialAttribute: attr)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HiSpace.lg),
        // CTA principal unique (un seul élément plein par écran de repos).
        HiButton(
          label: 'Coach — progresser sur un axe',
          icon: Icons.fitness_center_rounded,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CoachScreen()),
          ),
        ),
        const SizedBox(height: HiSpace.sm),
        // Actions secondaires discrètes (fantômes) sur une ligne.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HiGhostButton(
              label: 'Mon historique',
              icon: Icons.history_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
            const SizedBox(width: HiSpace.md),
            HiGhostButton(
              label: 'Partager ma carte',
              icon: Icons.ios_share_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShareCardScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Bandeau « fraîcheur » : un ou plusieurs axes datent → on propose un re-test, ton positif.
  Widget _freshnessBanner(BuildContext context, List<RadarAttribute> stale) {
    final names = stale.map((a) => HiLabels.attribute(a.attribute)).join(', ');
    final one = stale.length == 1;
    return HiCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CoachScreen(initialAttribute: stale.first.attribute)),
      ),
      child: Row(
        children: [
          Icon(Icons.update_rounded, color: HiColors.warn, size: 22),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(one ? 'Un axe à rafraîchir' : 'Des axes à rafraîchir',
                    style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$names : ta mesure date un peu. Un re-test peut la faire grimper.',
                    style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HiRadius.md),
      ),
      child: Text(message, style: TextStyle(color: HiColors.error)),
    );
  }
}

