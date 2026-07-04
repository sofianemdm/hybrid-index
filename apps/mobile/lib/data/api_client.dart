import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';
import 'diag_beacon.dart'; // TEMPORAIRE DIAG (04/07) : à retirer avant merge
import 'models.dart';

/// Vrai quand la dernière lecture a été servie depuis le CACHE (réseau indisponible) → l'UI
/// affiche le bandeau « hors ligne ». Redevient false au premier appel réseau réussi.
final ValueNotifier<bool> apiOffline = ValueNotifier<bool>(false);

/// Lectures mises en cache sur l'appareil (dernière réponse réussie) : les données « à moi »
/// et les classements — consultables hors ligne. JAMAIS les écritures.
const List<String> _cacheableGetPrefixes = [
  '/v1/me/profile',
  '/v1/me/history',
  '/v1/me/streak',
  '/v1/me/weekly-recap',
  '/v1/me/badges',
  '/v1/results',
  '/v1/leaderboard',
  '/v1/league/',
  '/v1/feed',
  '/v1/wods',
];

bool _isCacheablePath(String path) => _cacheableGetPrefixes.any(path.startsWith);

/// Erreur API normalisée (envelope { error: { code, message, details } }).
class ApiException implements Exception {
  final String code;
  final String message;
  final int status;
  final Map<String, dynamic>? details;
  ApiException(this.code, this.message, this.status, {this.details});
  @override
  String toString() => message;
}

/// Marqueur interne : données servies depuis le cache hors-ligne (voir `ApiClient._fetchWithRetry`).
class _CachedPayload {
  const _CachedPayload(this.data);
  final dynamic data;
}

/// Client HTTP vers l'`api` publique. Gère le bearer token.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Env.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  String? _token;

  void setToken(String? token) => _token = token;

  /// Token bearer courant (null si déconnecté). Exposé pour le handshake WebSocket temps réel,
  /// qui passe le JWT en query `?token=` (le navigateur n'autorise pas d'en-tête custom sur `new WebSocket()`).
  String? get token => _token;

  /// URL de base de l'API (http/https). Exposée pour dériver l'URL WebSocket (`ws(s)://…/ws/messaging`).
  String get baseUrl => _baseUrl;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_token != null) 'authorization': 'Bearer $_token',
      };

  /// Dernière réponse connue pour une lecture whitelistée — ou null. Pose `apiOffline` à true
  /// quand un repli est servi (l'UI affiche le bandeau « hors ligne »).
  Future<dynamic> _readCache(String method, String path) async {
    if (method != 'GET' || !_isCacheablePath(path)) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString('apicache:$path');
      if (text == null) return null;
      final decoded = jsonDecode(text);
      apiOffline.value = true;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _request(String method, Uri uri, String jsonBody) {
    switch (method) {
      case 'POST':
        return _client.post(uri, headers: _headers, body: jsonBody);
      case 'PATCH':
        return _client.patch(uri, headers: _headers, body: jsonBody);
      case 'DELETE':
        return _client.delete(uri, headers: _headers);
      case 'GET':
      default:
        return _client.get(uri, headers: _headers);
    }
  }

  /// Délai max par tentative : au-delà, l'appel échoue en « connexion trop lente » au lieu de
  /// rester bloqué INDÉFINIMENT (squelette de chargement éternel sur réseau mobile instable).
  static const Duration _timeout = Duration(seconds: 20); // 20s : tolère un réveil à froid Railway

  /// Petit délai entre 2 tentatives, ISOLÉ dans sa propre méthode À DESSEIN.
  ///
  /// En build web release (dart2js minifié), garder `Future<void>.delayed(...)` DANS le corps de
  /// `_send` déclenchait une miscompilation de la machine à états async : l'objet `Uri` local était
  /// réutilisé comme paramètre de type du Future, d'où un `NoSuchMethodError: 'b' (b.b is not a
  /// function)` à CHAQUE réponse d'erreur (404/400…) — ce qui bloquait TOUTE création de compte.
  /// En sortant le délai ici (aucun `Uri` en portée), l'aliasing devient impossible. Le pragma
  /// `noInline` est INDISPENSABLE : sans lui dart2js réinline le corps dans `_send` et le bug revient.
  @pragma('dart2js:noInline')
  Future<void> _retryDelay() {
    // Timer + Completer plutôt que `Future.delayed` : on évite complètement le `typeAcceptsNull<T>()`
    // interne de `Future.delayed` (c'est LUI qui plantait, `b.b(null)` sur un type mal résolu).
    final c = Completer<void>();
    Timer(const Duration(milliseconds: 300), c.complete);
    return c.future;
  }

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$_baseUrl$path');
    // Corps JSON : un POST/PATCH SANS body envoyait `jsonEncode(null)` = la chaîne "null" avec
    // Content-Type application/json → le serveur rejette (400). On envoie `{}` par défaut pour les
    // endpoints sans corps (ex. suivre un utilisateur) qui échouaient tous en « une erreur est survenue ».
    final jsonBody = jsonEncode(body ?? const <String, dynamic>{});
    final fetched = await _fetchWithRetry(method, uri, jsonBody, path);
    if (fetched is _CachedPayload) return fetched.data; // hors ligne → dernières données connues
    final res = fetched as http.Response;
    apiOffline.value = false; // le réseau répond → fin de l'état hors ligne
    return _decodeResponse(method, path, res);
  }

  /// Émission réseau + retry, ISOLÉS hors de `_send` À DESSEIN (avec `_decodeResponse`).
  ///
  /// BUG VÉCU (04/07, build web release dart2js UNIQUEMENT) : quand la boucle « for + try/catch +
  /// continue » et le traitement de la réponse cohabitaient dans LA MÊME fonction async, la machine
  /// à états générée donnait au `catch` une portée qui DÉBORDAIT sur le code post-boucle.
  /// L'ApiException LÉGITIME levée après la boucle (ex. 404 « pas d'Index », 409 « email pris »)
  /// était re-capturée par ce catch → retry (2 requêtes visibles dans la console) → re-capturée →
  /// « NETWORK / connexion impossible ». Inscription et onboarding totalement bloqués.
  /// Preuve par beacons : `send-http-error 404` suivi de `send-network` portant le MESSAGE du 404.
  /// Le découpage en fonctions séparées + `noInline` (sinon dart2js réinline et le bug revient)
  /// rend ce débordement impossible : ici, AUCUN code ne suit la boucle.
  @pragma('dart2js:noInline')
  Future<dynamic> _fetchWithRetry(String method, Uri uri, String jsonBody, String path) async {
    // 1 retry SILENCIEUX sur les lectures uniquement (GET = sans effet de bord) : une micro-coupure
    // réseau se répare toute seule. Jamais de retry automatique sur écriture (POST/PATCH/DELETE) —
    // on ne risque aucun doublon, même si les endpoints critiques sont déjà idempotents.
    final attempts = method == 'GET' ? 2 : 1;
    for (var attempt = 1; ; attempt++) {
      try {
        return await _request(method, uri, jsonBody).timeout(_timeout);
      } on TimeoutException {
        if (attempt < attempts) {
          await _retryDelay();
          continue;
        }
        final cached = await _readCache(method, path);
        if (cached != null) return _CachedPayload(cached); // hors ligne → dernières données connues
        diagBeacon('send-timeout', {'method': method, 'path': path}); // TEMPORAIRE DIAG
        throw ApiException('TIMEOUT', 'Connexion trop lente. Vérifie ton réseau et réessaie.', 0);
      } catch (e) {
        // Garde-fou : une erreur déjà typée ne doit JAMAIS être re-emballée en NETWORK.
        if (e is ApiException) rethrow;
        if (attempt < attempts) {
          await _retryDelay();
          continue;
        }
        final cached = await _readCache(method, path);
        if (cached != null) return _CachedPayload(cached); // hors ligne → dernières données connues
        // TEMPORAIRE DIAG : expose la cause réelle (type + message) dans le bandeau + beacon.
        final cause = '$e';
        diagBeacon('send-network', {
          'method': method,
          'path': path,
          'errorType': e.runtimeType.toString(),
          'error': cause.length > 300 ? cause.substring(0, 300) : cause,
        });
        throw ApiException(
            'NETWORK',
            'Connexion au serveur impossible. Vérifie ta connexion et réessaie. '
            '[diag ${e.runtimeType}: ${cause.length > 140 ? cause.substring(0, 140) : cause}]',
            0);
      }
    }
  }

  /// Décodage de la réponse + enveloppe d'erreur, isolés hors de `_send` et SYNCHRONES
  /// (aucune machine à états async ici, donc aucun débordement de catch possible).
  dynamic _decodeResponse(String method, String path, http.Response res) {
    final text = res.body.isEmpty ? '{}' : res.body;
    // Réponse non-JSON (ex. page HTML d'un proxy/504) → erreur normalisée plutôt qu'un crash de parsing.
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      diagBeacon('send-bad-response', {'method': method, 'path': path, 'status': res.statusCode}); // TEMPORAIRE DIAG
      throw ApiException('BAD_RESPONSE', 'Réponse serveur illisible (${res.statusCode}).', res.statusCode);
    }
    // Cache hors-ligne : mémorise la dernière réponse RÉUSSIE des lectures whitelistées.
    if (res.statusCode >= 200 && res.statusCode < 300 && method == 'GET' && _isCacheablePath(path)) {
      SharedPreferences.getInstance()
          .then((p) => p.setString('apicache:$path', text))
          .catchError((Object _) => false); // best-effort : un échec de cache n'affecte jamais l'appel
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    // Extraction DÉFENSIVE de l'enveloppe { error: { code, message, details } }.
    // BUG VÉCU (04/07) : sous le build web MINIFIÉ (release dart2js), l'ancienne écriture
    // `err?['code']?.toString()` levait un NoSuchMethodError (`c.b is not a function`) AU LIEU
    // de construire l'ApiException → un 404 « pas d'Index » (attendu) remontait comme un vrai
    // crash → écran d'erreur au lieu de l'onboarding, bloquant TOUTE création de compte.
    // On n'appelle plus aucune méthode dynamique, on teste les types, et on enveloppe le tout :
    // quoi qu'il arrive, on lève une ApiException typée avec le VRAI statut (donc myProfile
    // reconnaît le 404 et renvoie null).
    var code = 'ERROR';
    var message = 'Une erreur est survenue (${res.statusCode}).';
    Map<String, dynamic>? details;
    try {
      final err = decoded is Map ? decoded['error'] : null;
      if (err is Map) {
        final c = err['code'];
        if (c is String) code = c;
        final m = err['message'];
        if (m is String) message = m;
        final d = err['details'];
        if (d is Map) details = Map<String, dynamic>.from(d);
      }
    } catch (_) {/* on garde code/message génériques + le vrai statut */}
    // TEMPORAIRE DIAG : trace chaque réponse HTTP d'erreur correctement parsée (ex. 404 attendu).
    diagBeacon('send-http-error', {'method': method, 'path': path, 'status': res.statusCode, 'code': code});
    throw ApiException(code, message, res.statusCode, details: details);
  }

  // --- Auth ---
  Future<({String token, AuthUser user})> register(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/auth/register', payload) as Map<String, dynamic>;
    return (token: j['token'] as String, user: AuthUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<({String token, AuthUser user})> login(String email, String password) async {
    final j = await _send('POST', '/v1/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    return (token: j['token'] as String, user: AuthUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  /// « Mot de passe oublié » : envoie un code par email (réponse toujours ok, anti-énumération).
  Future<void> forgotPassword(String email) async =>
      _send('POST', '/v1/auth/forgot', {'email': email});

  /// Réinitialise le mot de passe avec le code à 6 chiffres reçu par email.
  Future<void> resetPassword(String email, String code, String newPassword) async =>
      _send('POST', '/v1/auth/reset', {'email': email, 'code': code, 'newPassword': newPassword});

  /// Connexion Google : `profile` requis seulement à la première connexion.
  Future<({String token, AuthUser user})> googleAuth(String idToken, Map<String, dynamic>? profile) async {
    final body = <String, dynamic>{'idToken': idToken, if (profile != null) 'profile': profile};
    final j = await _send('POST', '/v1/auth/google', body) as Map<String, dynamic>;
    return (token: j['token'] as String, user: AuthUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  /// Connexion Apple : `profile` requis seulement à la première connexion.
  Future<({String token, AuthUser user})> appleAuth(String identityToken, Map<String, dynamic>? profile) async {
    final body = <String, dynamic>{'identityToken': identityToken, if (profile != null) 'profile': profile};
    final j = await _send('POST', '/v1/auth/apple', body) as Map<String, dynamic>;
    return (token: j['token'] as String, user: AuthUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  /// Métadonnées app (mise à jour forcée) : build minimum supporté + URL du store.
  Future<({int minBuild, String storeUrl})> appMeta() async {
    final j = await _send('GET', '/v1/meta/app') as Map<String, dynamic>;
    return (minBuild: (j['minBuild'] as num?)?.toInt() ?? 0, storeUrl: j['storeUrl'] as String? ?? '');
  }

  Future<Map<String, dynamic>> me() async => await _send('GET', '/v1/me') as Map<String, dynamic>;

  Future<void> updateMe(Map<String, dynamic> payload) async => await _send('PATCH', '/v1/me', payload);

  // --- Onboarding ---
  Future<Profile> onboardingEstimate(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/onboarding/estimate', payload) as Map<String, dynamic>;
    return Profile.fromJson(j);
  }

  Future<Profile> onboardingComplete(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/onboarding/complete', payload) as Map<String, dynamic>;
    return Profile.fromJson(j);
  }

  /// « Je n'ai aucune de ces infos » : entre dans l'app sans Index (onboarding marqué fait).
  Future<void> onboardingSkip() async {
    await _send('POST', '/v1/onboarding/skip');
  }

  // --- Profil / résultats ---
  Future<Profile?> myProfile() async {
    try {
      final j = await _send('GET', '/v1/me/profile') as Map<String, dynamic>;
      return Profile.fromJson(j);
    } on ApiException catch (e) {
      if (e.status == 404) return null; // pas encore d'Index
      rethrow;
    }
  }

  Future<({Profile profile, List<String> newBadges})> logResult(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/results', payload) as Map<String, dynamic>;
    final badges = ((j['unlockedBadges'] as List?) ?? [])
        .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return (profile: Profile.fromJson(j['profile'] as Map<String, dynamic>), newBadges: badges);
  }

  Future<List<WodResultItem>> results() async {
    final j = await _send('GET', '/v1/results') as List<dynamic>;
    return j.map((e) => WodResultItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Supprime un de mes résultats (l'Index est recalculé côté serveur).
  Future<void> deleteResult(String id) async => _send('DELETE', '/v1/results/$id');

  Future<List<IndexPoint>> history() async {
    final j = await _send('GET', '/v1/me/history') as List<dynamic>;
    return j.map((e) => IndexPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  // --- Classement ---
  Future<Leaderboard> leaderboard(String sex, {int limit = 50}) async {
    final j = await _send('GET', '/v1/leaderboard?sex=$sex&limit=$limit') as Map<String, dynamic>;
    return Leaderboard.fromJson(j);
  }

  Future<ProgressBoard> progressBoard(String sex, {String? clubId}) async {
    final q = clubId != null ? '&clubId=$clubId' : '';
    final j = await _send('GET', '/v1/leaderboard/progress?sex=$sex$q') as Map<String, dynamic>;
    return ProgressBoard.fromJson(j);
  }

  // --- Clubs ---
  Future<List<ClubSummary>> myClubs() async {
    final j = await _send('GET', '/v1/me/clubs') as List<dynamic>;
    return j.map((e) => ClubSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ClubSummary>> searchClubs(String q) async {
    final j = await _send('GET', '/v1/clubs?q=${Uri.encodeQueryComponent(q)}') as List<dynamic>;
    return j.map((e) => ClubSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ClubDetail> clubDetail(String id) async {
    final j = await _send('GET', '/v1/clubs/$id') as Map<String, dynamic>;
    return ClubDetail.fromJson(j);
  }

  Future<ClubDetail> createClub(String name, {String? description}) async {
    final j = await _send('POST', '/v1/clubs', {'name': name, if (description != null && description.isNotEmpty) 'description': description}) as Map<String, dynamic>;
    return ClubDetail.fromJson(j);
  }

  Future<ClubDetail> joinClub(String id) async {
    final j = await _send('POST', '/v1/clubs/$id/join', {}) as Map<String, dynamic>;
    return ClubDetail.fromJson(j);
  }

  Future<void> leaveClub(String id) async => _send('DELETE', '/v1/clubs/$id/members/me');

  Future<void> inviteToClub(String clubId, String userId) async =>
      _send('POST', '/v1/clubs/$clubId/invites', {'inviteeId': userId});

  Future<List<ClubInvite>> myClubInvites() async {
    final j = await _send('GET', '/v1/me/club-invites') as List<dynamic>;
    return j.map((e) => ClubInvite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> declineClubInvite(String inviteId) async => _send('POST', '/v1/club-invites/$inviteId/decline', {});

  // --- Messagerie privée ---
  Future<DmEligibility> canDm(String userId) async {
    final j = await _send('GET', '/v1/users/$userId/can-dm') as Map<String, dynamic>;
    return DmEligibility.fromJson(j);
  }

  Future<List<ConversationSummary>> conversations() async {
    final j = await _send('GET', '/v1/conversations') as List<dynamic>;
    return j.map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Messages d'une conversation (page la plus récente par défaut). `before` = id d'un message →
  /// charge la page ANTÉRIEURE (scroll vers le haut). La réponse porte `hasMore` / `nextBefore`.
  Future<Conversation> conversationMessages(String id, {String? before}) async {
    final q = before == null ? '' : '?before=${Uri.encodeQueryComponent(before)}';
    final j = await _send('GET', '/v1/conversations/$id/messages$q') as Map<String, dynamic>;
    return Conversation.fromJson(j);
  }

  /// Envoie un message ; renvoie l'id de conversation (créée au besoin).
  Future<String> sendMessage(String toUserId, String body) async {
    final j = await _send('POST', '/v1/messages', {'toUserId': toUserId, 'body': body}) as Map<String, dynamic>;
    return j['conversationId'] as String;
  }

  /// Bloque un utilisateur (garde-fou de la messagerie publique). Idempotent côté serveur.
  Future<void> blockUser(String userId) async => _send('POST', '/v1/users/$userId/block', {});

  // --- Coach / profils publics ---
  Future<CoachResult> coach({String? attribute}) async {
    final q = attribute == null ? '' : '?attribute=$attribute';
    final j = await _send('GET', '/v1/coach$q') as Map<String, dynamic>;
    return CoachResult.fromJson(j);
  }

  /// Bibliothèque de séances qui travaillent un attribut, triées par pertinence (poids décroissant).
  Future<List<CoachSession>> coachLibrary(String attribute) async {
    final j = await _send('GET', '/v1/coach/library?attribute=$attribute') as Map<String, dynamic>;
    return (j['sessions'] as List<dynamic>).map((e) => CoachSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// TOUTE la bibliothèque (filtre « Tout ») en UN appel — séances dédupliquées, filtrées selon le
  /// matériel du profil, triées stable (durée asc → nom). Remplace les 6 appels par-axe (anti N+1).
  Future<List<CoachSession>> coachLibraryAll() async {
    final j = await _send('GET', '/v1/coach/library/all') as Map<String, dynamic>;
    return (j['sessions'] as List<dynamic>).map((e) => CoachSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// La « séance de la semaine » (Le Forgeron).
  Future<CoachSession> weeklySession() async {
    final j = await _send('GET', '/v1/coach/weekly') as Map<String, dynamic>;
    return CoachSession.fromJson(j['session'] as Map<String, dynamic>);
  }

  /// Marque une séance GUIDÉE comme faite : persiste la complétion ET crédite la SÉRIE côté serveur
  /// (sans créer de WOD ni toucher l'Athlete Index). Idempotent par jour. Renvoie [streakCredited]
  /// pour que l'UI ne mente PAS sur le crédit de série si le recalcul a échoué.
  Future<({bool recorded, bool streakCredited})> completeCoachSession(String sessionId) async {
    final j = await _send('POST', '/v1/coach/sessions/$sessionId/complete', {}) as Map<String, dynamic>;
    return (recorded: j['recorded'] == true, streakCredited: j['streakCredited'] == true);
  }

  Future<PublicProfile> publicProfile(String userId) async {
    final j = await _send('GET', '/v1/profiles/$userId') as Map<String, dynamic>;
    return PublicProfile.fromJson(j);
  }

  /// Historique de séances public d'un athlète (50 derniers résultats).
  Future<List<WodResultItem>> publicResults(String userId) async {
    final j = await _send('GET', '/v1/profiles/$userId/results') as List<dynamic>;
    return j.map((e) => WodResultItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // --- Engagement / RGPD ---
  Future<StreakState> streak() async {
    final j = await _send('GET', '/v1/me/streak') as Map<String, dynamic>;
    return StreakState.fromJson(j);
  }

  Future<List<BadgeModel>> badges() async {
    final j = await _send('GET', '/v1/me/badges') as List<dynamic>;
    return j.map((e) => BadgeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Badges gagnés (forme compacte) pour la carte de joueur : /v1/me/badges/card.
  Future<List<CardBadge>> badgesCard() async {
    final j = await _send('GET', '/v1/me/badges/card') as Map<String, dynamic>;
    return (j['earned'] as List<dynamic>? ?? const [])
        .map((e) => CardBadge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Signalement de bug (bêta) → stocké côté serveur. `context` = écran/plateforme (optionnel).
  Future<void> sendFeedback(String message, {String? context}) async {
    await _send('POST', '/v1/feedback', {'message': message, if (context != null) 'context': context});
  }

  /// Temps/score prédit pour un WOD d'après le niveau de l'utilisateur. Null si non prédictible.
  Future<WodPrediction?> wodPrediction(String wodId) async {
    try {
      final j = await _send('GET', '/v1/wods/$wodId/prediction') as Map<String, dynamic>;
      return WodPrediction.fromJson(j);
    } catch (_) {
      return null; // non bloquant : on n'affiche simplement pas la carte
    }
  }

  Future<WeeklyRecap> weeklyRecap() async {
    final j = await _send('GET', '/v1/me/weekly-recap') as Map<String, dynamic>;
    return WeeklyRecap.fromJson(j);
  }

  /// Enregistre le device token push (FCM). Renvoie l'état d'activation côté serveur.
  Future<bool> registerPushToken(String token) async {
    final j = await _send('POST', '/v1/me/push-token', {'token': token}) as Map<String, dynamic>;
    return j['enabled'] as bool? ?? false;
  }

  Future<StreakState> updateStreak({int? weeklyGoal, bool? plannedRest}) async {
    final body = <String, dynamic>{
      if (weeklyGoal != null) 'weeklyGoal': weeklyGoal,
      if (plannedRest != null) 'plannedRest': plannedRest,
    };
    final j = await _send('PATCH', '/v1/me/streak', body) as Map<String, dynamic>;
    return StreakState.fromJson(j);
  }

  Future<List<FeedItem>> notificationsFeed() async {
    final j = await _send('GET', '/v1/me/notifications/feed') as List<dynamic>;
    return j.map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> notificationPrefs() async =>
      await _send('GET', '/v1/me/notifications') as Map<String, dynamic>;

  Future<void> updateNotificationPrefs(Map<String, dynamic> payload) async =>
      _send('PATCH', '/v1/me/notifications', payload);

  // --- Ligue (mode mensuel opt-in) ---
  Future<LeagueSeason?> leagueSeason() async {
    final dynamic j = await _send('GET', '/v1/league/season/current');
    if (j is! Map || j['monthKey'] == null) return null;
    return LeagueSeason.fromJson(Map<String, dynamic>.from(j));
  }

  Future<LeagueStandings> leagueStandings(String sex) async {
    final j = await _send('GET', '/v1/league/standings?sex=$sex') as Map<String, dynamic>;
    return LeagueStandings.fromJson(j);
  }

  /// Résultat de la dernière saison CLOSE (reveal de fin de saison) ; null si aucune saison close.
  Future<LeagueLastResult?> leagueLastResult() async {
    final dynamic j = await _send('GET', '/v1/league/last-result');
    if (j is! Map || j['monthKey'] == null) return null;
    return LeagueLastResult.fromJson(Map<String, dynamic>.from(j));
  }

  // --- Records personnels (A8 — PR Wall) ---
  Future<List<PrItem>> personalRecords() async {
    final j = await _send('GET', '/v1/results/prs') as List<dynamic>;
    return j.map((e) => PrItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }



  // --- Communauté ---
  /// Fil d'actualité. [scope] = 'all' (fil GLOBAL, défaut) ou 'following' (suivis + moi).
  Future<List<FeedActivity>> feed({String scope = 'all'}) async {
    final j = await _send('GET', '/v1/feed?scope=$scope') as List<dynamic>;
    return j.map((e) => FeedActivity.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// « Mur » d'un athlète : ses posts (paginés par curseur). Respecte blocage/visibilité côté back.
  Future<PostPage> userPosts(String userId, {String? cursor}) async {
    final q = cursor == null || cursor.isEmpty ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    final j = await _send('GET', '/v1/users/$userId/posts$q') as Map<String, dynamic>;
    return PostPage.fromJson(j);
  }

  /// Fil « Découvrir » : top de la ligue (même sexe) à suivre (repli explicite).
  Future<List<FeedActivity>> discover() async {
    final j = await _send('GET', '/v1/social/discover') as List<dynamic>;
    return j.map((e) => FeedActivity.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Applaudir (kudos unifié 👏). Route vers l'endpoint event ou post selon [isPost].
  Future<void> react(String id, {bool isPost = false}) async => isPost
      ? _send('POST', '/v1/posts/$id/reactions', {})
      : _send('POST', '/v1/reactions', {'feedEventId': id});

  Future<void> unreact(String id, {bool isPost = false}) async =>
      isPost ? _send('DELETE', '/v1/posts/$id/reactions') : _send('DELETE', '/v1/reactions/$id');

  /// Crée un post texte ou un partage de perf (perf_share référence un wodResultId).
  /// [clubId] : le post est rattaché au fil de ce club (réservé aux membres, validé côté serveur).
  Future<FeedActivity> createPost({required String kind, String? body, String? wodResultId, String? clubId}) async {
    final j = await _send('POST', '/v1/posts', {
      'kind': kind,
      if (body != null && body.isNotEmpty) 'body': body,
      if (wodResultId != null) 'wodResultId': wodResultId,
      if (clubId != null) 'clubId': clubId,
    }) as Map<String, dynamic>;
    return FeedActivity.fromJson(j);
  }

  /// Fil d'un club (posts rattachés au club), paginé.
  Future<PostPage> clubPosts(String clubId, {String? cursor}) async {
    final q = cursor != null ? '?cursor=$cursor' : '';
    final j = await _send('GET', '/v1/posts/club/$clubId$q') as Map<String, dynamic>;
    return PostPage.fromJson(j);
  }

  Future<List<MyResult>> myResults() async {
    final j = await _send('GET', '/v1/results') as List<dynamic>;
    return j.map((e) => MyResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deletePost(String id) async => _send('DELETE', '/v1/posts/$id');

  Future<void> reportPost(String id, String reason, {String? note}) async =>
      _send('POST', '/v1/posts/$id/report', {'reason': reason, if (note != null && note.isNotEmpty) 'note': note});

  // --- Commentaires (sous un post du feed) ---
  /// Liste paginée des commentaires d'un post (curseur ; ordre chronologique).
  Future<CommentPage> comments(String postId, {String? cursor}) async {
    final q = cursor == null || cursor.isEmpty ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    final j = await _send('GET', '/v1/posts/$postId/comments$q') as Map<String, dynamic>;
    return CommentPage.fromJson(j);
  }

  /// Poste un commentaire sous [postId] → renvoie le commentaire créé. [parentId] non nul =
  /// réponse (thread 1 niveau) sous le commentaire racine `parentId`.
  Future<Comment> createComment(String postId, String body, {String? parentId}) async {
    final j = await _send('POST', '/v1/posts/$postId/comments', {
      'body': body,
      if (parentId != null) 'parentId': parentId,
    }) as Map<String, dynamic>;
    return Comment.fromJson(j);
  }

  /// Applaudir (👏) un commentaire → renvoie `(kudosCount, iKudo)` recalculés côté serveur.
  Future<(int, bool)> reactComment(String commentId) async {
    final j = await _send('POST', '/v1/comments/$commentId/reactions', {}) as Map<String, dynamic>;
    return ((j['kudosCount'] as num?)?.toInt() ?? 0, j['iKudo'] as bool? ?? true);
  }

  /// Retirer son applaudissement d'un commentaire (toggle off, idempotent).
  Future<(int, bool)> unreactComment(String commentId) async {
    final j = await _send('DELETE', '/v1/comments/$commentId/reactions') as Map<String, dynamic>;
    return ((j['kudosCount'] as num?)?.toInt() ?? 0, j['iKudo'] as bool? ?? false);
  }

  Future<void> deleteComment(String id) async => _send('DELETE', '/v1/comments/$id');

  Future<void> reportComment(String id, String reason, {String? note}) async =>
      _send('POST', '/v1/comments/$id/report', {'reason': reason, if (note != null && note.isNotEmpty) 'note': note});

  Future<void> followUser(String userId) async => _send('POST', '/v1/follow/$userId');

  Future<void> unfollowUser(String userId) async => _send('DELETE', '/v1/follow/$userId');

  Future<List<AthleteSummary>> following() async {
    final j = await _send('GET', '/v1/me/following') as List<dynamic>;
    return j.map((e) => AthleteSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AthleteSummary>> explore({String? sex, String? rank, String? q}) async {
    final params = [
      if (sex != null) 'sex=$sex',
      if (rank != null) 'rank=$rank',
      if (q != null && q.isNotEmpty) 'q=${Uri.encodeQueryComponent(q)}',
    ].join('&');
    final j = await _send('GET', '/v1/explore${params.isEmpty ? '' : '?$params'}') as List<dynamic>;
    return j.map((e) => AthleteSummary.fromJson(e as Map<String, dynamic>)).toList();
  }



  Future<EndgameInfo> endgame() async {
    final j = await _send('GET', '/v1/me/endgame') as Map<String, dynamic>;
    return EndgameInfo.fromJson(j);
  }

  Future<dynamic> exportData() async => _send('GET', '/v1/me/export');

  Future<void> deleteAccount() async => _send('DELETE', '/v1/me');

  // --- WOD Engine ---
  Future<List<WodCatalogEntry>> wodsCatalog() async {
    final j = await _send('GET', '/v1/wods') as List<dynamic>;
    return j.map((e) => WodCatalogEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Séances minimales à faire pour compléter le radar (révéler le vrai Index).
  Future<CompletionPlan> completionPlan() async {
    final j = await _send('GET', '/v1/wods/completion-plan') as Map<String, dynamic>;
    return CompletionPlan.fromJson(j);
  }

  Future<WodDetail> wodDetail(String id) async {
    final j = await _send('GET', '/v1/wods/$id') as Map<String, dynamic>;
    return WodDetail.fromJson(j);
  }

  Future<WodLeaderboard> wodLeaderboard(String id, String sex, {String variant = 'rx', String? clubId}) async {
    final q = clubId != null ? '&clubId=$clubId' : '';
    final j = await _send('GET', '/v1/wods/$id/leaderboard?sex=$sex&variant=$variant$q') as Map<String, dynamic>;
    return WodLeaderboard.fromJson(j);
  }

  // --- Défi de la semaine ---
  Future<WeeklyChallenge> currentChallenge() async {
    final j = await _send('GET', '/v1/challenge') as Map<String, dynamic>;
    return WeeklyChallenge.fromJson(j);
  }

  Future<List<WodLeaderboardEntry>> challengeLeaderboard(String sex) async {
    final j = await _send('GET', '/v1/challenge/leaderboard?sex=$sex') as Map<String, dynamic>;
    return ((j['entries'] as List?) ?? []).map((e) => WodLeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<OtherWorkout>> otherWorkouts() async {
    final j = await _send('GET', '/v1/other-workouts') as List<dynamic>;
    return j.map((e) => OtherWorkout.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MovementSummary>> movements() async {
    final j = await _send('GET', '/v1/movements') as List<dynamic>;
    return j.map((e) => MovementSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EstimateResult> estimateWod(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/wods/estimate', payload) as Map<String, dynamic>;
    return EstimateResult.fromJson(j);
  }

  Future<String> createWod(Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/wods', payload) as Map<String, dynamic>;
    return j['id'] as String;
  }

  /// Édite un WOD personnalisé (créateur uniquement) → renvoie l'id du WOD mis à jour.
  Future<String> updateWod(String id, Map<String, dynamic> payload) async {
    final j = await _send('PATCH', '/v1/wods/$id', payload) as Map<String, dynamic>;
    return j['id'] as String;
  }

  /// Supprime un WOD personnalisé (créateur uniquement). 409 si des résultats existent déjà.
  Future<void> deleteWod(String id) async => _send('DELETE', '/v1/wods/$id');

  /// Logue un résultat sur un WOD (officiel ou custom) → renvoie le profil recalculé ET les badges
  /// nouvellement débloqués par ce log (pour la célébration dopamine côté app).
  Future<WodLogResult> logWodResult(String wodId, Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/wods/$wodId/results', payload) as Map<String, dynamic>;
    final p = j['profile'];
    final badges = ((j['unlockedBadges'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((e) => BadgeModel.fromJson({...e, 'unlocked': true}))
        .toList();
    return WodLogResult(
      profile: p == null ? null : Profile.fromJson(p as Map<String, dynamic>),
      unlockedBadges: badges,
    );
  }

  // --- Avatar ---
  Future<AvatarConfig> getAvatar() async {
    final j = await _send('GET', '/v1/me/avatar') as Map<String, dynamic>;
    return AvatarConfig.fromJson(j);
  }

  Future<void> updateAvatar(AvatarConfig config) async => _send('PATCH', '/v1/me/avatar', config.toJson());
}
