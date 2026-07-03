import 'package:flutter/material.dart';

/// Tokens du design system HYBRID INDEX (cf. docs/design/design-system.md). Mode sombre
/// prioritaire, « feel jeu » façon Whoop + carte FIFA : profondeur par surfaces + glow,
/// cyan électrique en couleur signature, lime « victoire » réservé aux moments de dopamine.
/// Les tokens d'accès restent `HiColors.x` (getters) → on bascule la palette à l'exécution.
/// Voir [kHiDark] / [kHiLight].
class HiPalette {
  final Color bgBase, bgAmbient, bgElevated, bgElevated2, bgElevatedHi, strokeSubtle, strokeStrong, strokeBrand;
  final Color brandPrimary, brandPrimaryBright, brandPrimaryDeep, brandSecondary, brandSecondaryText, accentVictory;
  final Color textPrimary, textSecondary, textTertiary, textOnBrand;
  final Color success, error, warn, info;
  final Color attrEngine, attrSpeed, attrStrength, attrPower, attrEndurance, attrHybrid, attrLocked;
  const HiPalette({
    required this.bgBase,
    required this.bgAmbient,
    required this.bgElevated,
    required this.bgElevated2,
    required this.bgElevatedHi,
    required this.strokeSubtle,
    required this.strokeStrong,
    required this.strokeBrand,
    required this.brandPrimary,
    required this.brandPrimaryBright,
    required this.brandPrimaryDeep,
    required this.brandSecondary,
    required this.brandSecondaryText,
    required this.accentVictory,
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

/// Thème sombre (par défaut) — « feel jeu », cyan signature, fond plus profond pour que
/// l'Index « flotte ». `accentVictory` (lime) n'apparaît JAMAIS en UI de repos.
const kHiDark = HiPalette(
  bgBase: Color(0xFF090B11),
  // Centre du dégradé ambiant (fond signé) : bleu nuit à peine plus clair que bgBase, pour une
  // profondeur perceptible sans jamais concurrencer les surfaces élevées.
  bgAmbient: Color(0xFF0E1420),
  bgElevated: Color(0xFF11151F),
  bgElevated2: Color(0xFF1A1F2D),
  bgElevatedHi: Color(0xFF232A3B),
  strokeSubtle: Color(0x14FFFFFF),
  strokeStrong: Color(0x29FFFFFF),
  strokeBrand: Color(0x732BD4F5),
  brandPrimary: Color(0xFF2BD4F5),
  brandPrimaryBright: Color(0xFF6BECFF),
  brandPrimaryDeep: Color(0xFF0A8FB3),
  brandSecondary: Color(0xFF7C5CFF),
  brandSecondaryText: Color(0xFFA98CFF),
  accentVictory: Color(0xFFC6FF4A),
  textPrimary: Color(0xFFF2F5FA),
  textSecondary: Color(0xFFA7B0C0),
  // Éclairci de 0xFF6B7488 (4.2:1) → AA sur bgBase (5.3:1) sans changer la teinte gris-bleu.
  textTertiary: Color(0xFF7E8597),
  textOnBrand: Color(0xFF04121A),
  success: Color(0xFF34E29B),
  error: Color(0xFFFF5470),
  warn: Color(0xFFFFB23F),
  info: Color(0xFF6FB3FF),
  // Teintes d'attributs LÉGÈREMENT DÉSATURÉES (~15% vers le neutre) : moins « arc-en-ciel »,
  // plus premium ; le cyan signature reste la couleur dominante de l'app.
  attrEngine: Color(0xFFEB7A5E),
  attrSpeed: Color(0xFFE6C758),
  // Magenta FROID (ex-0xFFEA6389, rose trop proche de error 0xFFFF5470) : la Force ne peut plus
  // être confondue avec un état d'erreur.
  attrStrength: Color(0xFFE0559C),
  attrPower: Color(0xFF9D6CE0),
  attrEndurance: Color(0xFF45D6C0),
  attrHybrid: Color(0xFF5BD49B),
  attrLocked: Color(0xFF3A4256),
);

/// Thème clair — couleurs assombries pour rester lisibles sur fond clair (WCAG AA), utile en
/// plein soleil/salle (les études montrent que le dark mode est le pire en extérieur).
const kHiLight = HiPalette(
  bgBase: Color(0xFFEEF1F7),
  // Équivalent clair du fond ambiant : un blanc bleuté à peine plus lumineux que bgBase.
  bgAmbient: Color(0xFFF6F8FC),
  bgElevated: Color(0xFFFFFFFF),
  bgElevated2: Color(0xFFE4E9F2),
  bgElevatedHi: Color(0xFFD8DEEA),
  strokeSubtle: Color(0x14000000),
  strokeStrong: Color(0x24000000),
  strokeBrand: Color(0x730A7CA0),
  // Assombri de 0xFF0789AE (3.6:1 sur bgBase) → AA pour le texte (4.5:1) ; cyan conservé.
  brandPrimary: Color(0xFF056A85),
  brandPrimaryBright: Color(0xFF14A6CE),
  brandPrimaryDeep: Color(0xFF06536C),
  brandSecondary: Color(0xFF6B43E0),
  brandSecondaryText: Color(0xFF5A33D6),
  // Assombri de 0xFF5F9B00 (3.4:1) → AA pour le texte (4.5:1) ; lime/vert conservé.
  accentVictory: Color(0xFF4A7A00),
  textPrimary: Color(0xFF11161F),
  textSecondary: Color(0xFF46506A),
  // Assombri de 0xFF6E778C (4.0:1 sur bgBase) → AA (5.8:1).
  textTertiary: Color(0xFF565D70),
  textOnBrand: Color(0xFFFFFFFF),
  success: Color(0xFF0E9E66),
  error: Color(0xFFD32F4A),
  warn: Color(0xFFA8730A),
  info: Color(0xFF1F6FD6),
  attrEngine: Color(0xFFE04A28),
  attrSpeed: Color(0xFFB58600),
  // Magenta froid (ex-0xFFD8255C, trop proche de error 0xFFD32F4A) — même logique qu'en sombre.
  attrStrength: Color(0xFFC02380),
  attrPower: Color(0xFF7A3FE0),
  attrEndurance: Color(0xFF0E9E84),
  attrHybrid: Color(0xFF0E9E66),
  attrLocked: Color(0xFFC2C9D6),
);

class HiColors {
  HiColors._();

  /// Palette active (bascule sombre/clair à l'exécution). Lue par tous les getters ci-dessous.
  static HiPalette active = kHiDark;
  static void setBrightness(Brightness b) => active = b == Brightness.light ? kHiLight : kHiDark;

  static Color get bgBase => active.bgBase;
  static Color get bgAmbient => active.bgAmbient;
  static Color get bgElevated => active.bgElevated;
  static Color get bgElevated2 => active.bgElevated2;
  static Color get bgElevatedHi => active.bgElevatedHi;
  static Color get strokeSubtle => active.strokeSubtle;
  static Color get strokeStrong => active.strokeStrong;
  static Color get strokeBrand => active.strokeBrand;
  static Color get brandPrimary => active.brandPrimary;
  static Color get brandPrimaryBright => active.brandPrimaryBright;
  static Color get brandPrimaryDeep => active.brandPrimaryDeep;
  static Color get brandSecondary => active.brandSecondary;
  static Color get brandSecondaryText => active.brandSecondaryText;
  static Color get accentVictory => active.accentVictory;
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

  /// Orange de la flamme de série (constant, indépendant du thème).
  static const Color streakFlame = Color(0xFFFF8A3D);

  /// Dégradé marque « métal cyan » (primary → deep) pour boutons/anneaux : plus premium et
  /// moins « arc-en-ciel » que primary→secondary.
  static LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [active.brandPrimary, active.brandPrimaryDeep],
      );

  /// Dégradé bi-ton (primary → secondary) pour accents décoratifs (carte ligue, bulles chat).
  static LinearGradient get brandGradientDuo => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [active.brandPrimary, active.brandSecondary],
      );

  /// Dégradé « victoire » (lime → cyan) — UNIQUEMENT célébrations.
  static LinearGradient get victoryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [active.accentVictory, active.brandPrimaryBright],
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
    'engine': 'Cardio', // « Engine » (anglais) → « Cardio » : cohérence de langue sur le radar
    'speed': 'Vitesse',
    'strength': 'Force',
    'power': 'Puissance',
    'muscular_endurance': 'Endurance',
    'hybrid': 'Hybride',
  };

  static const ranks = {
    'rookie': 'Débutant', // « Rookie » (anglais) → « Débutant » : échelle francisée
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

/// Grades par paliers de 10 (« 40+ », « 50+ » … « 100 ») calés sur l'OVR /100.
/// Remplace les rangs médailles (bronze/argent/or…). Calculés CÔTÉ FRONT à partir de l'Index.
class HiGrade {
  HiGrade._();

  /// Borne basse du palier de l'Index (40 pour tout Index < 50, sinon la dizaine).
  static int lowerBound(int ovr) => ovr < 50 ? 40 : (ovr ~/ 10) * 10;

  /// Seuil du palier SUIVANT (null si déjà à 100).
  static int? nextThreshold(int ovr) => ovr >= 100 ? null : lowerBound(ovr) + 10;

  /// Libellé du grade courant : « 40+ », … « 90+ », ou « 100 ».
  static String label(int ovr) => ovr >= 100 ? '100' : '${lowerBound(ovr)}+';

  /// Libellé du grade suivant à viser (« 80+ »…), ou « 100 ».
  static String nextLabel(int ovr) {
    final t = nextThreshold(ovr);
    if (t == null) return '100';
    return t >= 100 ? '100' : '$t+';
  }

  /// Points restants avant le palier suivant (0 si au sommet).
  static int pointsToNext(int ovr) {
    final t = nextThreshold(ovr);
    return t == null ? 0 : (t - ovr).clamp(0, 10);
  }

  /// Progression [0..1] dans le palier courant (pleine à 100).
  static double progress(int ovr) {
    if (ovr >= 100) return 1;
    final lo = lowerBound(ovr);
    return ((ovr - lo) / 10).clamp(0.0, 1.0);
  }

  /// Couleur signature du grade (bordure + texte du chip, remplissage de barre).
  static Color color(int ovr) {
    if (ovr >= 100) return const Color(0xFF6BECFF); // cyan lumineux (sommet)
    switch (lowerBound(ovr)) {
      case 90:
        return const Color(0xFFB98CFF); // platine-violet
      case 80:
        return const Color(0xFFF3C13A); // or
      case 70:
        return const Color(0xFF6FB3FF); // azur
      case 60:
        return const Color(0xFF56C2A6); // laiton-jade
      case 50:
        return const Color(0xFF9FB0C3); // acier froid
      default:
        return const Color(0xFFC87E4F); // bronze (40+)
    }
  }

  /// Couleur du palier suivant (pour le dégradé de la barre).
  static Color nextColor(int ovr) => color((nextThreshold(ovr) ?? 100).clamp(40, 100));
}

class HiSpace {
  HiSpace._();
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const gutter = 20.0; // marge d'écran (plus respirante que lg partout)
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;
}

/// Cibles tactiles : taille minimale d'une zone cliquable pour l'accessibilité
/// (Material : 48dp, HIG : 44pt — on prend 48 pour couvrir les deux).
class HiTap {
  HiTap._();
  static const double minTarget = 48.0;
}

class HiRadius {
  HiRadius._();
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0; // boutons
  static const lg = 20.0; // cartes
  static const xl = 28.0; // cartes héros
  static const xxl = 36.0; // bottom sheets
  static const pill = 999.0;
}

/// Ombres premium : sur fond sombre, l'ombre noire seule est invisible → on combine
/// profondeur + halo coloré. En clair, on adoucit (bleu-gris).
class HiShadow {
  HiShadow._();

  static bool get _light => HiColors.active.bgBase.computeLuminance() > 0.5;

  /// Cartes standard.
  static List<BoxShadow> get e1 => _light
      ? const [BoxShadow(color: Color(0x142A3550), blurRadius: 12, offset: Offset(0, 5))]
      : const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))];

  /// Cartes héros / éléments saillants.
  static List<BoxShadow> get e2 => _light
      ? const [
          BoxShadow(color: Color(0x1F2A3550), blurRadius: 22, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
        ]
      : const [
          BoxShadow(color: Color(0x80000000), blurRadius: 28, offset: Offset(0, 12)),
          BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1)),
        ];

  /// Bottom sheets / modales (ombre vers le haut).
  static List<BoxShadow> get e3 => _light
      ? const [BoxShadow(color: Color(0x332A3550), blurRadius: 30, offset: Offset(0, -6))]
      : const [BoxShadow(color: Color(0xB3000000), blurRadius: 40, offset: Offset(0, -8))];

  /// Halo cyan (anneau d'Index, bouton primaire focus). [alpha] 0..1.
  static List<BoxShadow> glowBrand([double alpha = 0.35]) =>
      [BoxShadow(color: HiColors.brandPrimary.withValues(alpha: alpha), blurRadius: 32, spreadRadius: 2)];

  /// Burst de célébration — lime, uniquement franchissements.
  static List<BoxShadow> glowVictory([double alpha = 0.45]) =>
      [BoxShadow(color: HiColors.accentVictory.withValues(alpha: alpha), blurRadius: 40, spreadRadius: 4)];
}

/// Durées et courbes du langage de motion.
class HiMotion {
  HiMotion._();
  static const instant = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 480);
  static const reveal = Duration(milliseconds: 1600);
  static const celebrate = Duration(milliseconds: 900);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasis = Curves.easeOutBack; // overshoot léger (reveal, montée de palier)
  static const countUp = Curves.easeOutExpo; // grimpe puis se pose
}

/// Échelle typographique « instrument de sport » : Rajdhani (chiffres/titres data, figures
/// tabulaires pour des count-up sans saut) + Inter (corps, lisible en FR). Polices EMBARQUÉES
/// (assets/fonts, déclarées au pubspec) → aucun fetch réseau, pas de saut de police au reveal.
class HiType {
  HiType._();

  static const _data = 'Rajdhani';
  static const _body = 'Inter';
  static const _tabular = [FontFeature.tabularFigures()];

  // ---- Data / chiffres (Rajdhani) ----
  static const TextStyle displayXL =
      TextStyle(fontFamily: _data, fontSize: 88, fontWeight: FontWeight.w700, letterSpacing: -1.5, height: 0.92, fontFeatures: _tabular);
  static const TextStyle displayL =
      TextStyle(fontFamily: _data, fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 0.95, fontFeatures: _tabular);
  static const TextStyle displayS =
      TextStyle(fontFamily: _data, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.0, fontFeatures: _tabular);
  static const TextStyle numericL =
      TextStyle(fontFamily: _data, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.0, fontFeatures: _tabular);
  static const TextStyle numericM =
      TextStyle(fontFamily: _data, fontSize: 22, fontWeight: FontWeight.w600, height: 1.0, fontFeatures: _tabular);
  static const TextStyle overline =
      TextStyle(fontFamily: _data, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.5, height: 1.0);

  // ---- Corps / UI (Inter) ----
  static const TextStyle titleXL = TextStyle(fontFamily: _body, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.15);
  static const TextStyle titleL = TextStyle(fontFamily: _body, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.2, height: 1.15);
  static const TextStyle titleM = TextStyle(fontFamily: _body, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.1, height: 1.2);
  static const TextStyle body = TextStyle(fontFamily: _body, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4);
  static const TextStyle bodyStrong = TextStyle(fontFamily: _body, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4);
  static const TextStyle label = TextStyle(fontFamily: _body, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2, height: 1.3);
  static const TextStyle caption = TextStyle(fontFamily: _body, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.2, height: 1.3);
  static const TextStyle button = TextStyle(fontFamily: _body, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3, height: 1.0);
  /// Label de la bottom-nav (11 pt : lisible sans concurrencer les icônes).
  static const TextStyle navLabel = TextStyle(fontFamily: _body, fontSize: 11, fontWeight: FontWeight.w500, height: 1.0);
}
