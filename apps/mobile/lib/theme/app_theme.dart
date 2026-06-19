import 'package:flutter/material.dart';
import 'tokens.dart';

/// ThemeData sombre HYBRID INDEX.
ThemeData buildHiTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: HiColors.bgBase,
    colorScheme: const ColorScheme.dark(
      primary: HiColors.brandPrimary,
      secondary: HiColors.brandSecondary,
      surface: HiColors.bgElevated,
      error: HiColors.error,
      onPrimary: HiColors.textOnBrand,
      onSurface: HiColors.textPrimary,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: HiColors.textPrimary,
      displayColor: HiColors.textPrimary,
      fontFamily: 'Roboto',
    ),
    cardTheme: CardThemeData(
      color: HiColors.bgElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HiRadius.lg),
        side: const BorderSide(color: HiColors.strokeSubtle),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HiColors.bgElevated2,
      hintStyle: const TextStyle(color: HiColors.textTertiary),
      labelStyle: const TextStyle(color: HiColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HiRadius.md),
        borderSide: const BorderSide(color: HiColors.strokeSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HiRadius.md),
        borderSide: const BorderSide(color: HiColors.strokeSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HiRadius.md),
        borderSide: const BorderSide(color: HiColors.brandPrimary, width: 1.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: HiColors.bgElevated2,
      contentTextStyle: TextStyle(color: HiColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
