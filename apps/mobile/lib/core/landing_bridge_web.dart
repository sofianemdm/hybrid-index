import 'dart:js_interop';

@JS('hiOnFlutterReady')
external void _hiOnFlutterReady();

/// Signale à la landing HTML (web/index.html) que l'app Flutter a peint son premier frame :
/// elle se retire alors (immédiatement pour un utilisateur déjà connecté, ou dès que le
/// visiteur a cliqué « Commencer »). Best-effort : absente (vieux cache), on ne casse rien.
void notifyLandingReady() {
  try {
    _hiOnFlutterReady();
  } catch (_) {/* landing absente : rien à faire */}
}
