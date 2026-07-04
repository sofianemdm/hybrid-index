// Pont vers la logique d'installation PWA de la landing (window.hiInstallState / window.hiInstall).
// No-op hors web. Permet d'afficher un bouton « Installer l'app » DANS l'app Flutter Web.
export 'web_install_stub.dart' if (dart.library.js) 'web_install_web.dart';
