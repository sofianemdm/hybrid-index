import 'package:flutter/material.dart';

/// Tokens du design system HYBRID INDEX (cf. docs/design-system.md). Mode sombre prioritaire,
/// « feel jeu » : profondeur par surfaces + glow, cyan électrique en couleur signature.
class HiColors {
  HiColors._();

  // Surfaces & marque
  static const bgBase = Color(0xFF0B0E14);
  static const bgElevated = Color(0xFF121724);
  static const bgElevated2 = Color(0xFF1A2030);
  static const strokeSubtle = Color(0x14FFFFFF);
  static const strokeStrong = Color(0x29FFFFFF);

  static const brandPrimary = Color(0xFF3DE1FF); // cyan signature
  static const brandPrimaryDeep = Color(0xFF0A8FB3);
  static const brandSecondary = Color(0xFF7C5CFF); // violet énergie

  static const textPrimary = Color(0xFFF2F5FA);
  static const textSecondary = Color(0xFFA7B0C0);
  static const textTertiary = Color(0xFF6B7488);
  static const textOnBrand = Color(0xFF04121A);

  // Sémantique
  static const success = Color(0xFF46E6A0);
  static const error = Color(0xFFFF5470);
  static const warn = Color(0xFFFFB23F);
  static const info = Color(0xFF6FB3FF);

  // Attributs (radar) — teinte propre par axe
  static const attrEngine = Color(0xFFFF6B4A);
  static const attrSpeed = Color(0xFFFFD23F);
  static const attrStrength = Color(0xFFFF4D7E);
  static const attrPower = Color(0xFFA05CFF);
  static const attrEndurance = Color(0xFF3DE1FF);
  static const attrHybrid = Color(0xFF46E6A0);
  static const attrLocked = Color(0xFF3A4256);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimary, brandSecondary],
  );

  /// Couleur d'un attribut par sa clé (snake_case côté API).
  static Color attribute(String key) {
    switch (key) {
      case 'engine':
        return attrEngine;
      case 'speed':
        return attrSpeed;
      case 'strength':
        return attrStrength;
      case 'power':
        return attrPower;
      case 'muscular_endurance':
        return attrEndurance;
      case 'hybrid':
        return attrHybrid;
      default:
        return attrLocked;
    }
  }

  /// Couleur d'un rang (anglais côté API).
  static Color rank(String key) {
    switch (key) {
      case 'bronze':
        return const Color(0xFFC87E4F);
      case 'silver':
        return const Color(0xFFC2CBD8);
      case 'gold':
        return const Color(0xFFF3C13A);
      case 'platinum':
        return const Color(0xFF5FE0C8);
      case 'diamond':
        return const Color(0xFF6FB3FF);
      case 'elite':
        return const Color(0xFFB98CFF);
      default:
        return const Color(0xFF8A93A6); // rookie
    }
  }
}

/// Libellés FR (l'API renvoie de l'anglais snake_case ; i18n à l'affichage).
class HiLabels {
  HiLabels._();

  static const attributes = {
    'engine': 'Engine',
    'speed': 'Vitesse',
    'strength': 'Force',
    'power': 'Puissance',
    'muscular_endurance': 'Endurance',
    'hybrid': 'Hybride',
  };

  static const ranks = {
    'rookie': 'Rookie',
    'bronze': 'Bronze',
    'silver': 'Argent',
    'gold': 'Or',
    'platinum': 'Platine',
    'diamond': 'Diamant',
    'elite': 'Élite',
  };

  static const goals = {
    'hyrox': 'HYROX',
    'crossfit_strength': 'CrossFit / Force',
    'all_round': 'Polyvalent',
  };

  static String attribute(String k) => attributes[k] ?? k;
  static String rank(String k) => ranks[k] ?? k;
  static String goal(String k) => goals[k] ?? k;
}

class HiSpace {
  HiSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class HiRadius {
  HiRadius._();
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}
