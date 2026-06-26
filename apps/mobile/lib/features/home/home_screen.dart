import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/projection.dart';
import '../../data/session.dart';
import '../../data/ui_state.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/hi_card.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/index_ring.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/radar_insight.dart';
import '../../widgets/social_proof_card.dart';
import '../../widgets/streak_chip.dart';
import 'grade_block.dart';
import 'rival_card.dart';
import 'weekly_recap_card.dart';
import '../avatar/dice_avatar_screen.dart';
import '../coach/coach_screen.dart';
import '../coach/sessions_by_attribute_screen.dart';
import '../history/history_screen.dart';
import '../progression/progression_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../share/share_card_screen.dart';

/// Accueil : Index courant, rang, radar. Tire-pour-rafraîchir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
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
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DiceAvatarScreen()),
                  ),
                  child: ref.watch(avatarProvider).maybeWhen(
                        data: (a) => Hero(
                          tag: 'me-avatar',
                          child: HiAvatar(
                            config: a,
                            rank: profileAsync.value?.index.rank ?? 'rookie',
                            size: 48,
                          ),
                        ),
                        orElse: () => const SizedBox(width: 48, height: 48),
                      ),
                ),
                const SizedBox(width: HiSpace.sm),
                Expanded(
                  child: Text(
                    t.homeGreeting(session.user?.displayName ?? ''),
                    style: HiType.titleL.copyWith(color: HiColors.textPrimary),
                  ),
                ),
                // Flamme de série hebdomadaire (discrète, non bloquante).
                ref.watch(streakProvider).maybeWhen(
                      data: (s) => s == null ? const SizedBox.shrink() : StreakChip(streak: s),
                      orElse: () => const SizedBox.shrink(),
                    ),
                const SizedBox(width: HiSpace.xs),
                Badge.count(
                  count: ref.watch(unreadMessagesProvider).value ?? 0,
                  isLabelVisible: (ref.watch(unreadMessagesProvider).value ?? 0) > 0,
                  backgroundColor: HiColors.error,
                  child: IconButton(
                    tooltip: t.homeNotifications,
                    icon: Icon(Icons.notifications_rounded, color: HiColors.textSecondary),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                      ref.invalidate(unreadMessagesProvider); // maj pastille au retour
                    },
                  ),
                ),
                IconButton(
                  tooltip: t.homeSettings,
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
              data: (p) => p == null ? _errorBox(t.homeProfileUnavailable) : _content(context, ref, p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, Profile p) {
    final t = AppLocalizations.of(context);
    final stale = p.radar.where((a) => a.unlocked && a.isStale).toList();
    return Column(
      children: [
        // HÉROS : l'Index domine l'écran (264 + glow), le grade chevauche le bas de l'anneau
        // (translation négative → on lit « Index + grade » comme un seul bloc).
        // Tap sur l'Index → écran Progression (courbe + radar + badges). La Progression vit désormais
        // dans le header de l'Accueil (pattern Strava), plus dans la barre d'onglets (4 onglets).
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            // Enveloppée dans un Scaffold+AppBar : la Progression n'est plus un corps d'onglet (qui
            // fournissait le Scaffold) mais une route poussée → il lui faut son propre cadre + retour.
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(t.navProgress), backgroundColor: Colors.transparent, elevation: 0),
                body: const ProgressionScreen(),
              ),
            ),
          ),
          child: Column(children: [
            Center(child: IndexRing(value: p.index.value, percentile: p.index.percentile)),
            Transform.translate(offset: const Offset(0, -10), child: GradeBlock(profile: p)),
          ]),
        ),
        // Projection motivante (« à ce rythme, X+ dans N sem ») — seulement si tendance positive.
        ref.watch(indexHistoryProvider).maybeWhen(
              data: (h) {
                final proj = projectIndex(h, p.index.value);
                if (proj == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: HiSpace.md),
                  child: _projectionChip(proj, t),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        const SizedBox(height: HiSpace.lg),
        // Rival amical (ou état meneur) — la comparaison sociale, ton bienveillant.
        if (p.leaguePosition != null) ...[
          RivalCard(
            rival: p.rival,
            leaguePosition: p.leaguePosition,
            // Bascule sur l'onglet Classement (index 4 du HomeShell) plutôt que de pousser
            // LeaderboardScreen en route : cet écran n'a pas de Scaffold (c'est un corps d'onglet),
            // le pousser donnait un écran blanc. cf. home_shell.dart (IndexedStack).
            onTap: () => ref.read(homeTabProvider.notifier).state = 3,
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
              Text(t.homeRadarTitle, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
              const SizedBox(height: 2),
              Text(t.homeRadarHint,
                  style: HiType.caption.copyWith(color: HiColors.textTertiary)),
              const SizedBox(height: HiSpace.sm),
              RadarView(
                radar: p.radar,
                onTapAttribute: (attr) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SessionsByAttributeScreen(attribute: attr)),
                ),
              ),
              const SizedBox(height: HiSpace.md),
              RadarInsight(radar: p.radar),
            ],
          ),
        ),
        const SizedBox(height: HiSpace.lg),
        // CTA principal unique (un seul élément plein par écran de repos).
        HiButton(
          label: t.homeCoachCta,
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
              label: t.homeHistory,
              icon: Icons.history_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
            const SizedBox(width: HiSpace.md),
            HiGhostButton(
              label: t.homeShareCard,
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
    final t = AppLocalizations.of(context);
    final names = stale.map((a) => HiLabels.attribute(a.attribute)).join(', ');
    final one = stale.length == 1;
    return HiCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SessionsByAttributeScreen(attribute: stale.first.attribute)),
      ),
      child: Row(
        children: [
          Icon(Icons.update_rounded, color: HiColors.warn, size: 22),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(one ? t.homeFreshnessTitleOne : t.homeFreshnessTitleMany,
                    style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: 2),
                Text(t.homeFreshnessBody(names),
                    style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
        ],
      ),
    );
  }

  /// Chip de projection (« À ce rythme : 80+ dans ~3 sem »).
  Widget _projectionChip(IndexProjection proj, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: 10),
      decoration: BoxDecoration(
        color: HiColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: HiColors.success, size: 18),
          const SizedBox(width: HiSpace.sm),
          Expanded(
            child: Text(t.homeProjection(proj.targetGrade, proj.weeks),
                style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
          ),
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

