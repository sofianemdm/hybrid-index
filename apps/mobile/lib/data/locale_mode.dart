import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocalePrefKey = 'hi_locale';

/// Langue choisie par l'utilisateur. `null` = suivre la langue du système (FR/EN supportées).
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _restore();
    return null; // système par défaut
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kLocalePrefKey);
    if (v == 'fr') {
      state = const Locale('fr');
    } else if (v == 'en') {
      state = const Locale('en');
    } else {
      state = null;
    }
  }

  /// `null` → suivre le système.
  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocalePrefKey);
    } else {
      await prefs.setString(_kLocalePrefKey, locale.languageCode);
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
