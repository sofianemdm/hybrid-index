import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemePrefKey = 'hi_theme_mode';

/// Mode de thème choisi par l'utilisateur. Défaut = SOMBRE (décision humaine 03/07 : l'app est
/// pensée en sombre — landing, cartes, reveal — et suivre l'OS donnait un thème clair incohérent
/// sur les écrans hors de la landing). Toujours modifiable dans les Réglages (sombre/clair/système).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.dark;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kThemePrefKey);
    if (v == 'light') {
      state = ThemeMode.light;
    } else if (v == 'system') {
      state = ThemeMode.system;
    } else {
      // 'dark' OU aucune préférence enregistrée → sombre par défaut.
      state = ThemeMode.dark;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemePrefKey,
      mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system'),
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
