import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../app.dart';
import 'session.dart';

/// Événement temps réel poussé par le serveur (signal de rafraîchissement, sans contenu).
/// Le client refetch ensuite le contenu via REST (qui gère modération/pagination/accusés de lecture).
sealed class RealtimeEvent {
  const RealtimeEvent();
}

/// Un message direct vient d'être enregistré dans [conversationId] (côté destinataire OU expéditeur).
class DmReceived extends RealtimeEvent {
  final String conversationId;
  const DmReceived(this.conversationId);
}

/// Code de fermeture applicatif renvoyé par le serveur quand l'auth échoue (token absent/invalide/
/// expiré/compte non actif). On NE retente PAS dans ce cas : la session est invalide, pas le réseau.
const int _kAuthFailedCloseCode = 4401;

/// Service de connexion WebSocket temps réel vers `ws(s)://<host>/ws/messaging?token=<JWT>`.
///
/// Rôle : porter l'instantanéité de la messagerie (signal `{type:'dm', conversationId}`). Le polling
/// REST RESTE en repli (ralenti quand le WS est connecté) — ce service est purement additif et ne
/// doit JAMAIS faire planter l'app s'il ne peut pas se connecter (Web/prod, réseau, proxy…).
///
/// - Reconnexion automatique avec backoff exponentiel + jitter (sauf fermeture auth `4401`).
/// - Suspension en arrière-plan (lifecycle) ; reprise au retour au premier plan.
/// - Fermeture propre au logout (token nul) et au dispose.
class RealtimeService {
  RealtimeService({required String baseUrl, required String? Function() tokenProvider})
      : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  final String _baseUrl;
  final String? Function() _tokenProvider;

  final _controller = StreamController<RealtimeEvent>.broadcast();

  /// Flux d'événements temps réel. Les écrans s'y abonnent pour déclencher leur refetch existant.
  Stream<RealtimeEvent> get events => _controller.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnect;
  int _attempt = 0;
  bool _connected = false;
  bool _wantConnected = false; // intention : doit-on être connecté (premier plan + session active) ?
  bool _disposed = false;

  /// True si une session WS est actuellement établie. Utilisé par les écrans pour choisir le rythme
  /// de polling (rapide si WS down, lent si WS up).
  bool get isConnected => _connected;

  /// Construit l'URL WS : http→ws, https→wss, conserve hôte/port, ajoute le path et le token.
  Uri? _buildUri() {
    final token = _tokenProvider();
    if (token == null || token.isEmpty) return null;
    final base = Uri.tryParse(_baseUrl);
    if (base == null) return null;
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/ws/messaging',
      queryParameters: {'token': token},
    );
  }

  /// Démarre (ou redémarre) la connexion. Idempotent : ne fait rien si déjà connecté/connectant.
  void connect() {
    if (_disposed) return;
    _wantConnected = true;
    if (_connected || _channel != null) return;
    _open();
  }

  void _open() {
    if (_disposed || !_wantConnected) return;
    final uri = _buildUri();
    if (uri == null) {
      // Pas de token (déconnecté) : on n'essaie pas, on ne planifie pas de retry.
      return;
    }
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: (_) => _onClosed(),
        onDone: () => _onClosed(closeCode: channel.closeCode),
        cancelOnError: true,
      );
      // La connexion est confirmée par le premier événement « ready » du stream ; on considère
      // l'ouverture optimiste comme connectée pour ralentir le polling sans attendre.
      channel.ready.then((_) {
        if (_disposed) return;
        _connected = true;
        _attempt = 0;
      }).catchError((_) {
        // ready a échoué (handshake refusé) → traité comme une fermeture (avec éventuel retry).
        _onClosed();
      });
    } catch (_) {
      // Échec synchrone (URL invalide, plateforme) : on retombe sur le repli polling, retry doux.
      _onClosed();
    }
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      json = decoded;
    } catch (_) {
      return; // trame non-JSON : ignorée
    }
    final type = json['type'];
    // Champ `type` discriminant : on IGNORE tout type inconnu (évolutions read/typing sans casse).
    if (type == 'dm') {
      final id = json['conversationId'];
      if (id is String && id.isNotEmpty && !_controller.isClosed) {
        _controller.add(DmReceived(id));
      }
    }
  }

  void _onClosed({int? closeCode}) {
    _connected = false;
    _teardownChannel();
    if (_disposed || !_wantConnected) return;
    // Auth invalide : inutile de retenter (le token ne deviendra pas valide tout seul). On attend
    // un nouveau connect() explicite (ex. relogin).
    if (closeCode == _kAuthFailedCloseCode) {
      _wantConnected = false;
      return;
    }
    // Plus de token (logout pendant la connexion) : on ne retente pas.
    final token = _tokenProvider();
    if (token == null || token.isEmpty) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnect?.cancel();
    // Backoff exponentiel plafonné + jitter (évite le thundering herd au retour réseau).
    final base = min(30, pow(2, _attempt).toInt());
    _attempt = min(_attempt + 1, 6);
    final jitterMs = Random().nextInt(1000);
    final delay = Duration(seconds: base, milliseconds: jitterMs);
    _reconnect = Timer(delay, () {
      if (!_disposed && _wantConnected) _open();
    });
  }

  void _teardownChannel() {
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Coupe la connexion sans interdire une reprise ultérieure (utilisé en arrière-plan).
  void suspend() {
    _wantConnected = false;
    _reconnect?.cancel();
    _reconnect = null;
    _connected = false;
    _teardownChannel();
  }

  /// Coupe DÉFINITIVEMENT (logout) : empêche toute reconnexion jusqu'à un nouveau connect().
  void disconnect() => suspend();

  void dispose() {
    _disposed = true;
    _wantConnected = false;
    _reconnect?.cancel();
    _teardownChannel();
    _controller.close();
  }
}

/// Service temps réel applicatif (singleton). Se (re)connecte selon la session ET le cycle de vie :
/// connecté quand l'utilisateur est loggé ET l'app au premier plan ; suspendu sinon.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final api = ref.read(apiClientProvider);
  final service = RealtimeService(
    baseUrl: api.baseUrl,
    tokenProvider: () => api.token,
  );

  // (Re)connexion pilotée par l'état d'auth.
  ref.listen<SessionState>(sessionProvider, (prev, next) {
    if (next.status == AuthStatus.loggedIn) {
      service.connect();
    } else {
      service.disconnect();
    }
  }, fireImmediately: true);

  // Suspension en arrière-plan, reprise au premier plan (économie batterie/réseau, cohérent avec
  // le comportement du chat). On ne touche pas à l'intention si l'utilisateur n'est pas loggé.
  ref.listen<AppLifecycleState>(appLifecycleProvider, (prev, next) {
    final loggedIn = ref.read(sessionProvider).status == AuthStatus.loggedIn;
    if (!loggedIn) return;
    if (next == AppLifecycleState.resumed) {
      service.connect();
    } else {
      service.suspend();
    }
  });

  ref.onDispose(service.dispose);
  return service;
});
