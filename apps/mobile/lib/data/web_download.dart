// Export conditionnel : implémentation web (téléchargement navigateur) ou stub (mobile/desktop).
export 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';
