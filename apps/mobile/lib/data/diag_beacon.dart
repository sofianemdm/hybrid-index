// TEMPORAIRE (diagnostic auth 04/07) : beacon best-effort qui rapporte les erreurs réseau au
// collecteur local (/diag-report du proxy 8093) pour identifier la cause exacte des échecs
// « connexion impossible » côté navigateur. No-op hors web. À RETIRER avant merge dans main.
export 'diag_beacon_stub.dart' if (dart.library.html) 'diag_beacon_web.dart';
