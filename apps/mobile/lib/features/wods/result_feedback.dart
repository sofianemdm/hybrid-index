import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';

class _Msg {
  final String title;
  final String body;
  const _Msg(this.title, this.body);
}

final Random _rng = Random();

/// Message post-résultat : encouragement NEUTRE, affiché dans un dialogue calme que
/// l'utilisateur ferme lui-même (bouton OK — jamais d'auto-fermeture).
///
/// Historique : ce message comparait la perf à un temps PRÉDIT (« 12 % mieux que
/// l'estimation ») via une Celebration plein écran auto-fermante. Les estimations ont été
/// RETIRÉES du produit (décision humaine du 01/07) — la comparaison et ses 5 paliers ont été
/// supprimés le 03/07 (dernier vestige, repéré par l'humain sur « La Flèche »).
class ResultFeedback {
  final String title;
  final String body;
  const ResultFeedback({required this.title, required this.body});

  factory ResultFeedback.from({required AppLocalizations loc}) {
    final pool = <_Msg>[
      _Msg(loc.rfNoPredictionTitle1, loc.rfNoPredictionBody1),
      _Msg(loc.rfNoPredictionTitle2, loc.rfNoPredictionBody2),
    ];
    final m = pool[_rng.nextInt(pool.length)];
    return ResultFeedback(title: m.title, body: m.body);
  }

  /// Dialogue calme + haptique de succès. Se ferme au bouton OK, jamais tout seul.
  Future<void> show(BuildContext context) async {
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
