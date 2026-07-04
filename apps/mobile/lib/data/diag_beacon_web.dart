// TEMPORAIRE (diagnostic auth 04/07) : implémentation web. Envoie l'événement au collecteur local
// /diag-report (même origine que la page, donc le proxy 8093) via dart:html HttpRequest — un canal
// réseau DIFFÉRENT de package:http, exprès : si package:http est cassé, le beacon passe quand même.
// Trace aussi dans la console. Best-effort : ne lève jamais. À RETIRER avant merge.
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void diagBeacon(String tag, Map<String, Object?> data) {
  try {
    final payload = jsonEncode({
      'src': 'flutter',
      'tag': tag,
      'ua': html.window.navigator.userAgent,
      ...data,
    });
    html.window.console.error('DIAG[$tag] $payload');
    // Fire-and-forget (pas de await) ; les erreurs du Future sont avalées.
    html.HttpRequest.request(
      '/diag-report',
      method: 'POST',
      sendData: payload,
      requestHeaders: {'content-type': 'application/json'},
    ).catchError((Object _) => html.HttpRequest());
  } catch (_) {/* jamais bloquant */}
}
