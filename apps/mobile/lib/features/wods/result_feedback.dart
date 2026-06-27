import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/celebration.dart';

/// Messages MOTIVANTS affichés après l'enregistrement d'un résultat, en comparant la performance
/// réelle au temps/score PRÉDIT pour l'utilisateur (5 paliers). Spec + justifications scientifiques :
/// docs/gamification/messages-motivants-resultat.md (agent gamification). Sens de la métrique :
/// `time` → plus BAS = mieux ; `reps`/`load` → plus HAUT = mieux. On normalise en un gain `g` où
/// `g > 0` veut TOUJOURS dire « mieux que prévu ».
class _Msg {
  final String title;
  final String body;
  const _Msg(this.title, this.body);
}

// Palier 1 — g >= +6 % (bien mieux que prévu) → célébration FORTE.
const List<_Msg> _farBetter = [
  _Msg("Performance d'exception",
      "Tu as battu ta prédiction de {gain}. Ce n'est pas la chance : c'est ton travail qui parle. Note ce que tu as fait de bien aujourd'hui."),
  _Msg("Tu as explosé le plafond",
      "{gain} au-dessus de ce qu'on attendait de toi. Ton niveau réel vient de prendre de l'avance sur le modèle. Continue exactement comme ça."),
  _Msg("Bien au-dessus de la cible",
      "Prédiction pulvérisée de {gain}. Ce genre de séance, c'est la preuve concrète que ta préparation paie."),
];

// Palier 2 — +2 % <= g < +6 % (mieux que prévu) → célébration MOYENNE.
const List<_Msg> _better = [
  _Msg("Au-dessus de la cible",
      "{gain} de mieux que ta prédiction. Tu progresses dans la bonne direction, et ça se voit."),
  _Msg("Solide. Tu prends le dessus",
      "Tu as dépassé ce qui était attendu de {gain}. Garde ce rythme, c'est exactement comme ça qu'on monte."),
  _Msg("Mieux que prévu",
      "+{gain} sur la prédiction. Petit écart, vraie progression : capitalise dessus à ta prochaine séance."),
];

// Palier 3 — -2 % < g < +2 % (pile la prédiction) → célébration MOYENNE.
const List<_Msg> _onTarget = [
  _Msg("Pile dans la cible",
      "Tu as fait exactement le {metric} prévu pour toi. Atteindre sa cible, c'est déjà une réussite : ton niveau et ta perf sont alignés."),
  _Msg("Objectif atteint",
      "Tu as tenu la prédiction au plus juste. C'est de la régularité maîtrisée — la base de toute vraie progression."),
  _Msg("Dans le mille",
      "Tu as réalisé la perf attendue pour ton niveau. Solide et fiable : maintenant, vise un cran au-dessus."),
];

// Palier 4 — -10 % < g <= -2 % (un peu moins bien) → léger (dialogue calme, pas de fanfare).
const List<_Msg> _below = [
  _Msg("Séance dans la boîte",
      "Un peu en dessous de ta cible aujourd'hui, mais tu l'as terminée — et c'est ça qui compte. On sait que tu peux faire mieux : la prochaine sera meilleure."),
  _Msg("Bravo, c'est noté",
      "Pas ton meilleur jour sur {wodName}, mais chaque répétition compte dans ta progression. Tu as la marge pour repasser au-dessus."),
  _Msg("Tu as fait le travail",
      "Résultat un peu sous ta prédiction, mais l'important c'est que tu sois venu(e). On est sûrs que tu peux faire mieux la prochaine fois."),
];

// Palier 5 — g <= -10 % (très décevant / mauvais jour) → léger, ton récupération, jamais de honte.
const List<_Msg> _wayBelow = [
  _Msg("Mauvais jour, ça arrive",
      "Loin de ton niveau habituel aujourd'hui — et ce n'est pas grave. Le corps a ses jours sans. Repose-toi, et reviens retenter {wodName} en forme : tu vaux bien mieux que ça."),
  _Msg("Ce n'était pas ton jour",
      "Cette perf ne reflète pas ce dont tu es capable. Fatigue, sommeil, journée chargée : ça compte. Reviens sur {wodName} quand tu seras au top."),
  _Msg("On range cette séance",
      "Jour sans, tout simplement. L'avoir terminée malgré tout, c'est déjà du mental. Récupère bien et retente {wodName} reposé(e) — tu feras nettement mieux."),
];

// Pas de prédiction (Index incomplet / course libre) → encouragement neutre tourné vers le déblocage.
const List<_Msg> _noPrediction = [
  _Msg("Résultat enregistré",
      "Belle séance, c'est dans la boîte. Encore quelques entraînements et on pourra te dire exactement où tu te situes — et te prédire tes prochains chronos."),
  _Msg("C'est noté, continue",
      "Chaque résultat enregistré rapproche ton Index complet. Bientôt, on te donnera une cible personnalisée à battre sur chaque séance."),
];

final Random _rng = Random();

/// Feedback motivant prêt à afficher (titre + corps + intensité de célébration).
class ResultFeedback {
  final String title;
  final String body;
  final CelebrationIntensity intensity;
  const ResultFeedback({required this.title, required this.body, required this.intensity});

  /// Construit le message en comparant le résultat brut [actual] au [predicted] (temps/score prédit).
  /// [predicted] null ⇒ encouragement neutre (Index pas encore exploitable / course libre).
  factory ResultFeedback.from({
    required num actual,
    required num? predicted,
    required String scoreType,
    required String wodName,
  }) {
    if (predicted == null || predicted <= 0) {
      final m = _noPrediction[_rng.nextInt(_noPrediction.length)];
      return ResultFeedback(title: m.title, body: m.body, intensity: CelebrationIntensity.light);
    }
    // Gain relatif normalisé : g > 0 = mieux que prévu, quel que soit le sens de la métrique.
    final g = scoreType == 'time'
        ? (predicted - actual) / predicted * 100
        : (actual - predicted) / predicted * 100;

    final List<_Msg> pool;
    final CelebrationIntensity intensity;
    if (g >= 6) {
      pool = _farBetter;
      intensity = CelebrationIntensity.strong;
    } else if (g >= 2) {
      pool = _better;
      intensity = CelebrationIntensity.medium;
    } else if (g > -2) {
      pool = _onTarget;
      intensity = CelebrationIntensity.medium;
    } else if (g > -10) {
      pool = _below;
      intensity = CelebrationIntensity.light;
    } else {
      pool = _wayBelow;
      intensity = CelebrationIntensity.light;
    }

    final m = pool[_rng.nextInt(pool.length)];
    final gainStr = '${max(1, g.abs().round())} %'; // jamais « 0 % » sur un palier chiffré
    final metric = scoreType == 'time' ? 'temps' : 'score';
    final body = m.body
        .replaceAll('{gain}', gainStr)
        .replaceAll('{metric}', metric)
        .replaceAll('{wodName}', wodName);
    return ResultFeedback(title: m.title, body: body, intensity: intensity);
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(title, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        content: Text(body, style: HiType.body.copyWith(color: HiColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }
}
