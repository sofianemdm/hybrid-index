import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemePrefKey = 'hi_theme_mode';

/// Mode de thème choisi par l'utilisateur. Défaut = système (recommandation NN/g : suivre l'OS,
/// proposer les deux ; le clair est utile en plein soleil/salle où le sombre est le pire).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kThemePrefKey);
    if (v == 'light') {
      state = ThemeMode.light;
    } else if (v == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
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
