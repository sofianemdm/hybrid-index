import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

/// ThemeData HYBRID INDEX pour une luminosité donnée (sombre par défaut, clair disponible).
/// Utilise la palette directement (déterministe, indépendant de HiColors.active).
ThemeData buildHiTheme(Brightness brightness) {
  final pal = brightness == Brightness.light ? kHiLight : kHiDark;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final scheme = brightness == Brightness.light
      ? ColorScheme.light(
          primary: pal.brandPrimary,
          secondary: pal.brandSecondary,
          surface: pal.bgElevated,
          error: pal.error,
          onPrimary: pal.textOnBrand,
          onSurface: pal.textPrimary,
        )
      : ColorScheme.dark(
          primary: pal.brandPrimary,
          secondary: pal.brandSecondary,
          surface: pal.bgElevated,
          error: pal.error,
          onPrimary: pal.textOnBrand,
          onSurface: pal.textPrimary,
        );
  // Corps de l'app en Inter (les chiffres data passent en Rajdhani via HiType au point d'usage).
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: pal.textPrimary,
    displayColor: pal.textPrimary,
  );
  return base.copyWith(
    scaffoldBackgroundColor: pal.bgBase,
    colorScheme: scheme,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: pal.bgElevated,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HiRadius.lg),
        side: BorderSide(color: pal.strokeSubtle),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pal.bgElevated2,
      hintStyle: TextStyle(color: pal.textTertiary),
      labelStyle: TextStyle(color: pal.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HiRadius.md),
        borderSide: BorderSide(color: pal.strokeSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HiRadius.md),
        borderSide: BorderSide(color: pal.strokeSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HiRadius.md),
        borderSide: BorderSide(color: pal.brandPrimary, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: pal.bgElevated2,
      contentTextStyle: TextStyle(color: pal.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
