// Web : relaie vers la logique d'installation PWA définie dans web/index.html.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// 'none' = ne rien proposer (déjà installée / pas dispo) · 'ready' = prompt natif dispo
/// (Android/Chrome) · 'ios' = pas de prompt auto → instructions manuelles.
String webInstallState() {
  try {
    final r = js.context.callMethod('hiInstallState');
    return r is String ? r : 'none';
  } catch (_) {
    return 'none';
  }
}

/// Déclenche l'installation : prompt natif (Android) ou feuille d'instructions (iOS / fallback).
void webPromptInstall() {
  try {
    js.context.callMethod('hiInstall');
  } catch (_) {/* la landing n'a pas encore initialisé : sans effet */}
}
