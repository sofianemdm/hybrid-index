import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import 'month_format.dart';

/// Construit l'ordinal localisé d'un rang (FR : 1er / Ne ; EN : 1st/2nd/3rd/4th… avec les
/// exceptions 11-13 et 21-23). ICU `plural` de gen-l10n ne sait pas exprimer les ordinaux
/// (pas de cas `=N` arbitraires), donc on le calcule ici puis on l'injecte dans la clé
/// `leagueRevealRankOrdinal` qui n'est plus qu'un passe-plat `{ordinal}`.
extension LeagueRevealOrdinalX on AppLocalizations {
  String rankOrdinal(int rank) => leagueRevealRankOrdinal(_ordinalFor(localeName, rank));
}

String _ordinalFor(String localeName, int rank) {
  final isFr = localeName.toLowerCase().startsWith('fr');
  if (isFr) {
    return rank == 1 ? '1er' : '${rank}e';
  }
  // EN : suffixe selon les deux derniers chiffres (11-13 → th), sinon selon le dernier chiffre.
  final mod100 = rank % 100;
  final mod10 = rank % 10;
  String suffix;
  if (mod100 >= 11 && mod100 <= 13) {
    suffix = 'th';
  } else if (mod10 == 1) {
    suffix = 'st';
  } else if (mod10 == 2) {
    suffix = 'nd';
  } else if (mod10 == 3) {
    suffix = 'rd';
  } else {
    suffix = 'th';
  }
  return '$rank$suffix';
}

/// REVEAL de fin de saison de Ligue : podium top 3 stylisé + « Tu finis Ne » + delta de mouvement.
/// Présenté UNE fois par saison close (la gestion du « déjà vu » est faite par l'appelant via
/// shared_preferences). Animation sobre et respectueuse de reduce-motion.
class LeagueRevealSheet extends StatefulWidget {
  final LeagueLastResult result;
  const LeagueRevealSheet({super.key, required this.result});

  /// Ouvre le reveal en plein écran (dialog modal). À n'appeler que si la saison n'a pas été vue.
  static Future<void> show(BuildContext context, LeagueLastResult result) {
    HiHaptics.celebrate();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: HiMotion.base,
      pageBuilder: (ctx, _, __) => LeagueRevealSheet(result: result),
      transitionBuilder: (ctx, anim, _, child) {
        // reduce-motion : on conserve le fondu (peu de mouvement), sans translation.
        final reduce = MediaQuery.maybeDisableAnimationsOf(ctx) ?? false;
        final fade = FadeTransition(opacity: anim, child: child);
        if (reduce) return fade;
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<LeagueRevealSheet> createState() => _LeagueRevealSheetState();
}

class _LeagueRevealSheetState extends State<LeagueRevealSheet> {
  /// Mois localisé « Juin 2026 » dérivé de monthKey "2026-06" (sûr ; repli sur le brut).
  String _monthLabel(BuildContext context) {
    return formatMonthKey(widget.result.monthKey, Localizations.localeOf(context).toString());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final violet = HiColors.brandSecondary;
    final podium = widget.result.podium;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HiSpace.lg),
            child: Container(
              padding: const EdgeInsets.all(HiSpace.lg),
              decoration: BoxDecoration(
                // Fond OPAQUE : la teinte violette est pré-mélangée sur le fond élevé (au lieu d'un
                // violet à 30 % d'alpha qui laissait transparaître le contenu de l'écran derrière).
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(violet.withValues(alpha: 0.30), HiColors.bgElevated2),
                    HiColors.bgElevated2,
                  ],
                ),
                borderRadius: BorderRadius.circular(HiRadius.md),
                border: Border.all(color: violet.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_rounded, color: HiColors.accentVictory, size: 26),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          t.leagueRevealTitle(_monthLabel(context)),
                          textAlign: TextAlign.center,
                          style: HiType.titleL.copyWith(color: HiColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HiSpace.sm),
                  Text(
                    t.leagueRevealPodium,
                    textAlign: TextAlign.center,
                    style: HiType.caption.copyWith(
                      color: HiColors.brandSecondaryText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: HiSpace.md),
                  if (podium.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: HiSpace.md),
                      child: Text(
                        t.leagueStandingsEmpty,
                        textAlign: TextAlign.center,
                        style: HiType.body.copyWith(color: HiColors.textTertiary),
                      ),
                    )
                  else
                    _Podium(podium: podium),
                  const SizedBox(height: HiSpace.lg),
                  _myLine(t),
                  const SizedBox(height: HiSpace.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiColors.brandSecondary,
                        foregroundColor: HiColors.textOnBrand,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(t.leagueRevealClose),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _myLine(AppLocalizations t) {
    final r = widget.result;
    if (!r.participated) {
      return Column(
        children: [
          Text(t.leagueRevealNotRanked,
              textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textSecondary)),
          const SizedBox(height: 4),
          Text(t.leagueRevealNewSeason,
              textAlign: TextAlign.center,
              style: HiType.caption.copyWith(color: HiColors.brandSecondaryText)),
        ],
      );
    }
    final rank = r.myFinalRank!;
    final ordinal = t.rankOrdinal(rank);
    final movementLabel = _movementLabel(t);
    return Column(
      children: [
        Text(
          t.leagueRevealYouFinished(ordinal),
          textAlign: TextAlign.center,
          style: HiType.titleL.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w900),
        ),
        if (movementLabel != null) ...[
          const SizedBox(height: 6),
          Text(
            movementLabel,
            textAlign: TextAlign.center,
            style: HiType.caption.copyWith(color: HiColors.brandSecondaryText, fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 4),
        Text(t.leaguePts(r.myTotalPoints ?? 0),
            textAlign: TextAlign.center,
            style: HiType.numericM.copyWith(color: HiColors.textSecondary)),
      ],
    );
  }

  /// Mouvement de POSITION au classement vs le mois précédent (2 ligues simples par sexe,
  /// AUCUNE division). Le backend renvoie "promoted"/"relegated"/"stay" : on l'interprète
  /// uniquement comme « tu as gagné / perdu des places » ou « tu es resté stable ».
  String? _movementLabel(AppLocalizations t) {
    switch (widget.result.myMovement) {
      case 'promoted':
        return t.leagueRevealMovedUp;
      case 'relegated':
        return t.leagueRevealMovedDown;
      case 'stay':
        return t.leagueRevealStable;
      default:
        return null; // null → première saison / pas de comparaison possible
    }
  }
}

/// Podium 3 colonnes : 2e (gauche) · 1er (centre, plus haut) · 3e (droite).
class _Podium extends StatelessWidget {
  final List<LeaguePodiumRow> podium;
  const _Podium({required this.podium});

  LeaguePodiumRow? _byRank(int rank) {
    for (final p in podium) {
      if (p.finalRank == rank) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final first = _byRank(1);
    final second = _byRank(2);
    final third = _byRank(3);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _step(context, second, height: 78)),
        const SizedBox(width: 8),
        Expanded(child: _step(context, first, height: 104)),
        const SizedBox(width: 8),
        Expanded(child: _step(context, third, height: 60)),
      ],
    );
  }

  Widget _step(BuildContext context, LeaguePodiumRow? row, {required double height}) {
    final t = AppLocalizations.of(context);
    if (row == null) return const SizedBox.shrink();
    final color = HiColors.rank(
      row.finalRank == 1 ? 'gold' : (row.finalRank == 2 ? 'silver' : 'bronze'),
    );
    // a11y : le rang est codé visuellement par la hauteur de la barre → on l'énonce explicitement
    // (« 1re place : nom, N points »), sinon un lecteur d'écran ne perçoit pas la position.
    return Semantics(
      label: t.a11yPodiumPlace(t.rankOrdinal(row.finalRank), row.displayName, row.totalPoints),
      child: ExcludeSemantics(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HiAvatar(
          config: row.avatar ?? const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1),
          rank: 'rookie',
          size: row.finalRank == 1 ? 56 : 44,
          showRing: true,
        ),
        const SizedBox(height: 6),
        Text(
          row.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: HiType.caption.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          t.leaguePts(row.totalPoints),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: HiType.caption.copyWith(color: HiColors.textTertiary),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.18)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(HiRadius.sm)),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '#${row.finalRank}',
            style: HiType.numericM.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
    ),
    );
  }
}
