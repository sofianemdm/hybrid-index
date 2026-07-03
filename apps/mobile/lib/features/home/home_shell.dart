import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart' show apiOffline;
import '../../data/session.dart';
import '../../data/ui_state.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_ambient_background.dart';
import '../../widgets/hi_nav_icons.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../log/log_wod_screen.dart';
import '../messaging/realtime_banner.dart';
import '../community/community_tab.dart';
import '../wods/wod_tab.dart';
import '../wods/wod_builder_screen.dart';
import 'home_screen.dart';

/// Index des onglets de la coquille (ordre de l'IndexedStack ci-dessous). Nommés pour éviter
/// les nombres magiques dispersés dans le code (ex. le tap « rival » qui bascule sur le Classement).
const int kHomeTabIndex = 0;
const int kSessionsTabIndex = 1;
const int kCommunityTabIndex = 2;
const int kLeaderboardTabIndex = 3;

/// Coquille principale : Accueil / Classement + bouton central « Logger une séance ».
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // L'onglet actif vit dans homeTabProvider (partagé) pour pouvoir y revenir depuis ailleurs.

  /// Carte de choix bien visible (dialogue centré « Ajouter une séance »).
  Widget _choiceCard(BuildContext ctx,
      {required IconData icon, required String title, required String subtitle, required String value}) {
    return Material(
      color: HiColors.bgElevated2,
      borderRadius: BorderRadius.circular(HiRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(HiRadius.md),
        onTap: () => Navigator.of(ctx).pop(value),
        child: Container(
          padding: const EdgeInsets.all(HiSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HiRadius.md),
            border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.45), width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HiColors.brandPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(HiRadius.sm),
                ),
                child: Icon(icon, color: HiColors.brandPrimary),
              ),
              const SizedBox(width: HiSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: HiColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLog() async {
    final t = AppLocalizations.of(context);
    // Bottom-sheet (et plus un Dialog centré) : plus pouce-friendly, rayon héros + poignée.
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HiRadius.xxl)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.sm, HiSpace.lg, HiSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poignée (grabber) : signale « ça se tire vers le bas ».
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: HiSpace.md),
                  decoration: BoxDecoration(
                    color: HiColors.strokeStrong,
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                  ),
                ),
              ),
              Text(t.homeAddSessionTitle,
                  textAlign: TextAlign.center,
                  style: HiType.titleM.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w800)),
              const SizedBox(height: HiSpace.lg),
              _choiceCard(ctx,
                  icon: Icons.timer_outlined,
                  title: t.homeAddQuickTitle,
                  subtitle: t.homeAddQuickSubtitle,
                  value: 'log'),
              const SizedBox(height: HiSpace.md),
              _choiceCard(ctx,
                  icon: Icons.build,
                  title: t.homeBuildSessionTitle,
                  subtitle: t.homeBuildSessionSubtitle,
                  value: 'build'),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final route = choice == 'build'
        ? MaterialPageRoute<bool>(builder: (_) => const WodBuilderScreen())
        : MaterialPageRoute<bool>(builder: (_) => const LogWodScreen());
    final changed = await Navigator.of(context).push<bool>(route);
    if (changed == true || choice == 'build') {
      ref.invalidate(myProfileProvider);
      ref.invalidate(completionPlanProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tab = ref.watch(homeTabProvider);
    return HiAmbientBackground(
      heroHalo: true,
      child: Scaffold(
      // Le fond vit dans HiAmbientBackground (dégradé ambiant) → Scaffold transparent.
      backgroundColor: Colors.transparent,
      extendBody: true, // le contenu glisse sous la barre translucide
      body: Stack(
        children: [
          // 4 onglets (Progression sortie de la barre → accessible via la carte Index de l'Accueil).
          // _LazyIndexedStack : un onglet n'est CONSTRUIT qu'à sa première visite (démarrage à
          // froid ~4× moins de travail : plus de fetch Communauté/Classement avant d'en avoir
          // besoin) et ses animations sont GELÉES quand il est caché (TickerMode) — le reflet de
          // la carte joueur ne consomme plus rien depuis les autres onglets. L'état des onglets
          // visités est CONSERVÉ (même comportement perçu qu'IndexedStack).
          _LazyIndexedStack(
            index: tab,
            builders: const [HomeScreen.new, WodTab.new, CommunityTab.new, LeaderboardScreen.new],
          ),
          // Observateur temps réel (sans rendu) : affiche le bandeau « Nouveau message de X » quand
          // un DM arrive hors de la conversation ouverte. Monté ici → vivant sur tous les onglets.
          const RealtimeBanner(),
          // Bandeau « hors ligne » : visible quand une lecture a été servie depuis le cache local
          // (réseau indisponible). Disparaît seul au premier appel réussi.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: apiOffline,
              builder: (context, offline, _) => offline
                  ? Container(
                      color: HiColors.warn.withValues(alpha: 0.92),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 14, color: Colors.black87),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context).offlineBanner,
                              style: HiType.caption.copyWith(color: Colors.black87, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _notchedNav(t),
      ),
    );
  }

  /// Barre de navigation (4 onglets + bouton « + » central). Le bouton est dessiné DANS la barre,
  /// centré par `Center` sur toute la largeur (= centre exact de l'écran) — plus de FAB ni d'encoche
  /// dont le placement dépendait de la géométrie du Scaffold. Centrage garanti, indépendant des items.
  Widget _notchedNav(AppLocalizations t) {
    // Glyphes PROPRIÉTAIRES (hi_nav_icons.dart) : éclair, haltère, anneau de groupe, podium.
    final tabs = <(HiNavGlyph, String, int)>[
      (HiNavGlyph.bolt, t.navHome, kHomeTabIndex),
      (HiNavGlyph.dumbbell, t.navSessions, kSessionsTabIndex),
      (HiNavGlyph.community, t.navCommunity, kCommunityTabIndex),
      (HiNavGlyph.podium, t.navLeaderboard, kLeaderboardTabIndex),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HiSpace.md, 0, HiSpace.md, HiSpace.sm),
        child: SizedBox(
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // La barre : 4 onglets égaux + un espace central pour le bouton.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(HiRadius.pill),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: 64,
                      color: HiColors.bgElevated2.withValues(alpha: 0.86),
                      child: Row(
                        children: [
                          Expanded(child: _navItem(tabs[0])),
                          Expanded(child: _navItem(tabs[1])),
                          const SizedBox(width: 68), // emplacement du bouton central
                          Expanded(child: _navItem(tabs[2])),
                          Expanded(child: _navItem(tabs[3])),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bouton « + » central : `Center` sur toute la largeur ⇒ exactement au milieu de l'écran,
              // légèrement surélevé au-dessus de la barre.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: t.homeAddSessionTitle,
                    child: Tooltip(
                      message: t.homeAddSessionTitle,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HiHaptics.tap();
                          _openLog();
                        },
                        child: ExcludeSemantics(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: HiColors.brandPrimary,
                              boxShadow: HiShadow.glowBrand(0.4),
                              border: Border.all(color: HiColors.bgBase, width: 3),
                            ),
                            child: Icon(Icons.add_rounded, color: HiColors.textOnBrand, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem((HiNavGlyph, String, int) tab) {
    final i = tab.$3;
    final active = ref.watch(homeTabProvider) == i;
    final color = active ? HiColors.brandPrimary : HiColors.textTertiary;
    return Semantics(
      label: tab.$2,
      selected: active,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HiHaptics.tap();
          ref.read(homeTabProvider.notifier).state = i;
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.0 : 0.9,
              duration: HiMotion.fast,
              curve: Curves.easeOut,
              child: HiNavIcon(glyph: tab.$1, active: active, color: color, size: 23),
            ),
            const SizedBox(height: 2),
            Text(tab.$2,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: HiType.navLabel.copyWith(
                    color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// IndexedStack PARESSEUX : chaque enfant n'est construit qu'à sa première sélection, puis
/// conservé (état/scroll intacts). Les enfants non visibles sont sous TickerMode(enabled:false)
/// → toutes leurs animations (reflets, shimmers) s'arrêtent tant qu'ils sont cachés.
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.builders});

  final int index;
  final List<Widget Function({Key? key})> builders;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<bool> _built = List<bool>.filled(widget.builders.length, false);

  @override
  Widget build(BuildContext context) {
    _built[widget.index] = true;
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: _built[i] ? widget.builders[i]() : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
