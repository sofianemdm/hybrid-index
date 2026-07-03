// Pont vers la landing statique du site (web/index.html) — no-op sur mobile.
export 'landing_bridge_stub.dart' if (dart.library.js_interop) 'landing_bridge_web.dart';
