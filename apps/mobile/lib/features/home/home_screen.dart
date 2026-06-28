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
import '../../widgets/radar_view.dart';
import '../../widgets/radar_insight.dart';
import '../../widgets/social_proof_card.dart';
import '../../widgets/streak_chip.dart';
import '../../widgets/bug_report.dart';
import '../../widgets/error_retry.dart';
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
                Semantics(
                  button: true,
                  label: t.a11yHomeEditAvatar,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DiceAvatarScreen()),
                    ),
                    child: ExcludeSemantics(
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
                  ),
                ),
                const SizedBox(width: HiSpace.sm),
                Expanded(
                  child: Builder(builder: (_) {
                    // Sans nom : on évite « Salut, » avec une virgule orpheline → salutation générique.
                    final name = session.user?.displayName.trim() ?? '';
                    return Text(
                      name.isEmpty ? t.homeGreetingNoName : t.homeGreeting(name),
                      style: HiType.titleL.copyWith(color: HiColors.textPrimary),
                    );
                  }),
                ),
                // Flamme de série hebdomadaire (discrète, non bloquante).
                ref.watch(streakProvider).maybeWhen(
                      data: (s) => s == null ? const SizedBox.shrink() : StreakChip(streak: s),
                      orElse: () => const SizedBox.shrink(),
                    ),
                const SizedBox(width: HiSpace.xs),
                Badge.count(
                  // Boîte de réception : messages non lus + invitations de club (auto-rafraîchie).
                  count: ref.watch(inboxBadgeProvider).value ?? 0,
                  isLabelVisible: (ref.watch(inboxBadgeProvider).value ?? 0) > 0,
                  backgroundColor: HiColors.error,
                  child: IconButton(
                    tooltip: t.homeNotifications,
                    icon: Icon(Icons.notifications_rounded, color: HiColors.textSecondary),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                      ref.invalidate(unreadMessagesProvider); // maj pastille au retour
                      ref.invalidate(inboxBadgeProvider);
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
            _betaBanner(context),
            const SizedBox(height: HiSpace.md),
            profileAsync.when(
              loading: () => const HomeSkeleton(),
              // Jamais d'exception brute à l'écran : ErrorRetry (message localisé + « Réessayer »).
              error: (e, _) => ErrorRetry(
                onRetry: () async {
                  ref.invalidate(myProfileProvider);
                  await ref.read(myProfileProvider.future);
                },
              ),
              data: (p) => p == null
                  ? ErrorRetry(
                      message: t.homeProfileUnavailable,
                      onRetry: () async {
                        ref.invalidate(myProfileProvider);
                        await ref.read(myProfileProvider.future);
                      },
                    )
                  : _content(context, ref, p),
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
        Semantics(
          button: true,
          label: t.a11yHomeViewProgression,
          child: GestureDetector(
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
            // ESSAI : carte joueur à la place du rond Index (réversible si ça ne plaît pas).
            // La PlayerCard a une largeur FIXE (360px). Dans un slot étroit (~312px sur 360dp,
            // moins sur 320dp) elle se faisait rogner → FittedBox(scaleDown) la réduit pour
            // qu'elle tienne TOUJOURS dans la largeur dispo, sans jamais l'agrandir au-delà de
            // sa taille native. Aligné en haut pour éviter tout saut vertical.
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                // RepaintBoundary : isole le repaint du sheen animé de la carte du reste de l'accueil
                // (le reflet en boucle ne re-peint plus le ListView entier à chaque frame).
                child: RepaintBoundary(
                  child: PlayerCard(
                    profile: p,
                    name: ref.watch(sessionProvider).user?.displayName ?? '',
                    sex: ref.watch(sessionProvider).sex,
                    avatar: ref.watch(avatarProvider).value,
                    badges: ref.watch(cardBadgesProvider).value ?? const [],
                  ),
                ),
              ),
            ),
          ]),
        ),
        ),
        // Encart « Index estimé » + plan de complétion : la PlayerCard montre l'OVR/grade mais ne
        // dit PLUS que l'Index est une estimation ni quelles séances faire pour le révéler. On le
        // réintroduit SOUS la carte, uniquement tant que l'Index est incomplet/estimé (le widget
        // se masque tout seul sinon → SizedBox.shrink).
        if (p.index.radarCoverage < 6 || p.index.isEstimated) ...[
          const SizedBox(height: HiSpace.md),
          EstimationBlock(profile: p),
        ],
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
    return Semantics(
      button: true,
      child: MergeSemantics(
        child: HiCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SessionsByAttributeScreen(attribute: stale.first.attribute)),
          ),
          child: Row(
            children: [
              ExcludeSemantics(child: Icon(Icons.update_rounded, color: HiColors.warn, size: 22)),
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
              ExcludeSemantics(child: Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }

  /// Chip de projection (« À ce rythme : 80+ dans ~3 sem »).
  Widget _projectionChip(IndexProjection proj, AppLocalizations t) {
    return Semantics(
      label: t.homeProjection(proj.targetGrade, proj.weeks),
      container: true,
      child: ExcludeSemantics(
        child: Container(
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
        ),
      ),
    );
  }

  /// Bandeau bêta compact : tap → feuille d'info (prévient des bugs et invite à les signaler).
  Widget _betaBanner(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: t.homeBetaBanner,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HiRadius.md),
          onTap: () => _showBetaInfo(context),
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: 10),
              decoration: BoxDecoration(
                color: HiColors.warn.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(HiRadius.md),
                border: Border.all(color: HiColors.warn.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.science_outlined, size: 18, color: HiColors.warn),
                  const SizedBox(width: HiSpace.sm),
                  Expanded(
                    child: Text(t.homeBetaBanner,
                        style: HiType.caption.copyWith(color: HiColors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: HiColors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBetaInfo(BuildContext context) {
    final t = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(HiRadius.xxl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, HiSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science_rounded, color: HiColors.warn),
                  const SizedBox(width: HiSpace.sm),
                  Expanded(child: Text(t.homeBetaTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary))),
                ],
              ),
              const SizedBox(height: HiSpace.sm),
              Text(t.homeBetaBody, style: HiType.body.copyWith(color: HiColors.textSecondary, height: 1.45)),
              const SizedBox(height: HiSpace.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiColors.brandPrimary,
                    foregroundColor: HiColors.textOnBrand,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.bug_report_rounded, size: 18),
                  label: Text(t.bugReportTitle),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    showBugReportSheet(context);
                  },
                ),
              ),
              const SizedBox(height: HiSpace.xs),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(t.commonGotIt, style: TextStyle(color: HiColors.textTertiary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

