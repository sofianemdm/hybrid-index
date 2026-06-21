import 'package:flutter/material.dart';

/// Tokens du design system HYBRID INDEX (cf. docs/design-system.md). Mode sombre prioritaire,
/// « feel jeu » : profondeur par surfaces + glow, cyan électrique en couleur signature.
/// Palette de couleurs (sombre ou claire). Les tokens d'accès restent `HiColors.x` (getters)
/// → on bascule la palette à l'exécution. Voir [kHiDark] / [kHiLight].
class HiPalette {
  final Color bgBase, bgElevated, bgElevated2, strokeSubtle, strokeStrong;
  final Color brandPrimary, brandPrimaryDeep, brandSecondary, brandSecondaryText;
  final Color textPrimary, textSecondary, textTertiary, textOnBrand;
  final Color success, error, warn, info;
  final Color attrEngine, attrSpeed, attrStrength, attrPower, attrEndurance, attrHybrid, attrLocked;
  const HiPalette({
    required this.bgBase,
    required this.bgElevated,
    required this.bgElevated2,
    required this.strokeSubtle,
    required this.strokeStrong,
    required this.brandPrimary,
    required this.brandPrimaryDeep,
    required this.brandSecondary,
    required this.brandSecondaryText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnBrand,
    required this.success,
    required this.error,
    required this.warn,
    required this.info,
    required this.attrEngine,
    required this.attrSpeed,
    required this.attrStrength,
    required this.attrPower,
    required this.attrEndurance,
    required this.attrHybrid,
    required this.attrLocked,
  });
}

/// Thème sombre (par défaut) — « feel jeu », cyan signature.
const kHiDark = HiPalette(
  bgBase: Color(0xFF0B0E14),
  bgElevated: Color(0xFF121724),
  bgElevated2: Color(0xFF1A2030),
  strokeSubtle: Color(0x14FFFFFF),
  strokeStrong: Color(0x29FFFFFF),
  brandPrimary: Color(0xFF3DE1FF),
  brandPrimaryDeep: Color(0xFF0A8FB3),
  brandSecondary: Color(0xFF7C5CFF),
  brandSecondaryText: Color(0xFFA98CFF),
  textPrimary: Color(0xFFF2F5FA),
  textSecondary: Color(0xFFA7B0C0),
  textTertiary: Color(0xFF6B7488),
  textOnBrand: Color(0xFF04121A),
  success: Color(0xFF46E6A0),
  error: Color(0xFFFF5470),
  warn: Color(0xFFFFB23F),
  info: Color(0xFF6FB3FF),
  attrEngine: Color(0xFFFF6B4A),
  attrSpeed: Color(0xFFFFD23F),
  attrStrength: Color(0xFFFF4D7E),
  attrPower: Color(0xFFA05CFF),
  attrEndurance: Color(0xFF3DE1FF),
  attrHybrid: Color(0xFF46E6A0),
  attrLocked: Color(0xFF3A4256),
);

/// Thème clair — couleurs assombries pour rester lisibles sur fond clair (WCAG AA), utile en
/// plein soleil/salle (les études montrent que le dark mode est le pire en extérieur).
const kHiLight = HiPalette(
  bgBase: Color(0xFFF4F6FA),
  bgElevated: Color(0xFFFFFFFF),
  bgElevated2: Color(0xFFEAEEF5),
  strokeSubtle: Color(0x14000000),
  strokeStrong: Color(0x29000000),
  brandPrimary: Color(0xFF0A7CA0),
  brandPrimaryDeep: Color(0xFF06536C),
  brandSecondary: Color(0xFF6B43E0),
  brandSecondaryText: Color(0xFF5A33D6),
  textPrimary: Color(0xFF14181F),
  textSecondary: Color(0xFF4A5160),
  textTertiary: Color(0xFF7B8494),
  textOnBrand: Color(0xFFFFFFFF),
  success: Color(0xFF0E9E66),
  error: Color(0xFFD32F4A),
  warn: Color(0xFFA8730A),
  info: Color(0xFF1F6FD6),
  attrEngine: Color(0xFFE04A28),
  attrSpeed: Color(0xFFB58600),
  attrStrength: Color(0xFFD8255C),
  attrPower: Color(0xFF7A3FE0),
  attrEndurance: Color(0xFF0A7CA0),
  attrHybrid: Color(0xFF0E9E66),
  attrLocked: Color(0xFFC2C9D6),
);

class HiColors {
  HiColors._();

  /// Palette active (bascule sombre/clair à l'exécution). Lue par tous les getters ci-dessous.
  static HiPalette active = kHiDark;
  static void setBrightness(Brightness b) => active = b == Brightness.light ? kHiLight : kHiDark;

  static Color get bgBase => active.bgBase;
  static Color get bgElevated => active.bgElevated;
  static Color get bgElevated2 => active.bgElevated2;
  static Color get strokeSubtle => active.strokeSubtle;
  static Color get strokeStrong => active.strokeStrong;
  static Color get brandPrimary => active.brandPrimary;
  static Color get brandPrimaryDeep => active.brandPrimaryDeep;
  static Color get brandSecondary => active.brandSecondary;
  static Color get brandSecondaryText => active.brandSecondaryText;
  static Color get textPrimary => active.textPrimary;
  static Color get textSecondary => active.textSecondary;
  static Color get textTertiary => active.textTertiary;
  static Color get textOnBrand => active.textOnBrand;
  static Color get success => active.success;
  static Color get error => active.error;
  static Color get warn => active.warn;
  static Color get info => active.info;
  static Color get attrEngine => active.attrEngine;
  static Color get attrSpeed => active.attrSpeed;
  static Color get attrStrength => active.attrStrength;
  static Color get attrPower => active.attrPower;
  static Color get attrEndurance => active.attrEndurance;
  static Color get attrHybrid => active.attrHybrid;
  static Color get attrLocked => active.attrLocked;

  static LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [active.brandPrimary, active.brandSecondary],
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
    'crossfit_strength': 'CrossFit',
    'all_round': 'Condition physique',
  };

  static String attribute(String k) => attributes[k] ?? k;
  static String rank(String k) => ranks[k] ?? k;
  static String goal(String k) => goals[k] ?? k;

  /// Abréviations 3 lettres des attributs (carte FIFA).
  static const Map<String, String> attrAbbr = {
    'engine': 'ENG',
    'strength': 'FOR',
    'power': 'PUI',
    'speed': 'VIT',
    'muscular_endurance': 'RES',
    'hybrid': 'HYB',
  };
  static String attrAbbreviation(String k) =>
      attrAbbr[k] ?? (k.length >= 3 ? k.substring(0, 3).toUpperCase() : k.toUpperCase());
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
