import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_review/in_app_review.dart';

/// Demande l'avis natif (App Store / Play) APRÈS un moment de réussite (PR, montée de rang) —
/// jamais après une erreur. L'OS plafonne lui-même la fréquence (Apple ~3×/an), donc on peut
/// appeler à chaque réussite sans spammer. No-op sur le Web ; jamais bloquant.
Future<void> maybeAskForReview() async {
  if (kIsWeb) return;
  try {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  } catch (_) {
    // L'avis ne doit jamais perturber le parcours.
  }
}
