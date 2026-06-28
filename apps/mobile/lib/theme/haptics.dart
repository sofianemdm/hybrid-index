import 'package:flutter/services.dart';

/// Point d'entrée unique du retour haptique. No-op silencieux sur Web (les plateformes
/// sans vibreur ignorent simplement l'appel — pas de crash).
class HiHaptics {
  HiHaptics._();

  /// Tap léger : sélection, navigation, toggle.
  static void tap() => HapticFeedback.selectionClick();

  /// Action confirmée (envoi message, like, log enregistré).
  static void success() => HapticFeedback.lightImpact();

  /// Impact moyen : fin de count-up, ouverture d'un moment fort.
  static void impact() => HapticFeedback.mediumImpact();

  /// Célébration : franchissement de palier, PR, montée au classement.
  static void celebrate() => HapticFeedback.heavyImpact();

  /// Échec d'une action (ex. envoi de message rejeté) — signal sec et distinct.
  static void error() => HapticFeedback.heavyImpact();
}
