import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/celebration.dart';

/// Messages MOTIVANTS affichés après l'enregistrement d'un résultat, en comparant la performance
/// réelle au temps/score PRÉDIT pour l'utilisateur (5 paliers). Spec + justifications scientifiques :
/// docs/gamification/messages-motivants-resultat.md (agent gamification). Sens de la métrique :
/// `time` → plus BAS = mieux ; `reps`/`load` → plus HAUT = mieux. On normalise en un gain `g` où
/// `g > 0` veut TOUJOURS dire « mieux que prévu ».
///
/// Les chaînes (titres + corps, 3 variantes par palier) sont intégralement i18n
/// (clés `rf*` dans app_*.arb). On garde la sélection ALÉATOIRE d'une variante par palier.
class _Msg {
  final String title;
  final String body;
  const _Msg(this.title, this.body);
}

final Random _rng = Random();

/// Feedback motivant prêt à afficher (titre + corps + intensité de célébration).
class ResultFeedback {
  final String title;
  final String body;
  final CelebrationIntensity intensity;
  const ResultFeedback({required this.title, required this.body, required this.intensity});

  /// Construit le message en comparant le résultat brut [actual] au [predicted] (temps/score prédit).
  /// [predicted] null ⇒ encouragement neutre (Index pas encore exploitable / course libre).
  /// [loc] fournit les chaînes localisées (FR/EN).
  factory ResultFeedback.from({
    required AppLocalizations loc,
    required num actual,
    required num? predicted,
    required String scoreType,
    required String wodName,
  }) {
    final metric = scoreType == 'time' ? loc.rfMetricTime : loc.rfMetricScore;

    if (predicted == null || predicted <= 0) {
      final pool = <_Msg>[
        _Msg(loc.rfNoPredictionTitle1, loc.rfNoPredictionBody1),
        _Msg(loc.rfNoPredictionTitle2, loc.rfNoPredictionBody2),
      ];
      final m = pool[_rng.nextInt(pool.length)];
      return ResultFeedback(title: m.title, body: m.body, intensity: CelebrationIntensity.light);
    }
    // Gain relatif normalisé : g > 0 = mieux que prévu, quel que soit le sens de la métrique.
    final g = scoreType == 'time'
        ? (predicted - actual) / predicted * 100
        : (actual - predicted) / predicted * 100;
    final gainStr = '${max(1, g.abs().round())} %'; // jamais « 0 % » sur un palier chiffré

    final List<_Msg> pool;
    final CelebrationIntensity intensity;
    if (g >= 6) {
      pool = [
        _Msg(loc.rfFarBetterTitle1, loc.rfFarBetterBody1(gainStr)),
        _Msg(loc.rfFarBetterTitle2, loc.rfFarBetterBody2(gainStr)),
        _Msg(loc.rfFarBetterTitle3, loc.rfFarBetterBody3(gainStr)),
      ];
      intensity = CelebrationIntensity.strong;
    } else if (g >= 2) {
      pool = [
        _Msg(loc.rfBetterTitle1, loc.rfBetterBody1(gainStr)),
        _Msg(loc.rfBetterTitle2, loc.rfBetterBody2(gainStr)),
        _Msg(loc.rfBetterTitle3, loc.rfBetterBody3(gainStr)),
      ];
      intensity = CelebrationIntensity.medium;
    } else if (g > -2) {
      pool = [
        _Msg(loc.rfOnTargetTitle1, loc.rfOnTargetBody1(metric)),
        _Msg(loc.rfOnTargetTitle2, loc.rfOnTargetBody2),
        _Msg(loc.rfOnTargetTitle3, loc.rfOnTargetBody3),
      ];
      intensity = CelebrationIntensity.medium;
    } else if (g > -10) {
      pool = [
        _Msg(loc.rfBelowTitle1, loc.rfBelowBody1),
        _Msg(loc.rfBelowTitle2, loc.rfBelowBody2(wodName)),
        _Msg(loc.rfBelowTitle3, loc.rfBelowBody3),
      ];
      intensity = CelebrationIntensity.light;
    } else {
      pool = [
        _Msg(loc.rfWayBelowTitle1, loc.rfWayBelowBody1(wodName)),
        _Msg(loc.rfWayBelowTitle2, loc.rfWayBelowBody2(wodName)),
        _Msg(loc.rfWayBelowTitle3, loc.rfWayBelowBody3(wodName)),
      ];
      intensity = CelebrationIntensity.light;
    }

    final m = pool[_rng.nextInt(pool.length)];
    return ResultFeedback(title: m.title, body: m.body, intensity: intensity);
  }

  /// Affiche le message : plein écran festif (strong/medium) ou dialogue calme + haptique (light :
  /// paliers bas / pas de prédiction — surtout PAS de confettis sur une contre-perf).
  Future<void> show(BuildContext context) async {
    if (intensity != CelebrationIntensity.light) {
      await Celebration.show(context, title: title, subtitle: body, intensity: intensity);
      return;
    }
    HiHaptics.success();
    if (!context.mounted) return;
    final loc = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(title, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        content: Text(body, style: HiType.body.copyWith(color: HiColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(loc.commonOk)),
        ],
      ),
    );
  }
}
