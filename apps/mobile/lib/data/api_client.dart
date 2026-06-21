import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/env.dart';
import 'models.dart';

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

/// Client HTTP vers l'`api` publique. Gère le bearer token.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Env.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_token != null) 'authorization': 'Bearer $_token',
      };

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$_baseUrl$path');
    late http.Response res;
    try {
      switch (method) {
        case 'POST':
          res = await _client.post(uri, headers: _headers, body: jsonEncode(body));
          break;
        case 'PATCH':
          res = await _client.patch(uri, headers: _headers, body: jsonEncode(body));
          break;
        case 'DELETE':
          res = await _client.delete(uri, headers: _headers);
          break;
        case 'GET':
        default:
          res = await _client.get(uri, headers: _headers);
          break;
      }
    } catch (_) {
      throw ApiException('NETWORK', 'Serveur injoignable. L\'API tourne-t-elle sur $_baseUrl ?', 0);
    }

    final text = res.body.isEmpty ? '{}' : res.body;
    final dynamic decoded = jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    final err = (decoded is Map && decoded['error'] is Map) ? decoded['error'] as Map : null;
    throw ApiException(
      err?['code']?.toString() ?? 'ERROR',
      err?['message']?.toString() ?? 'Une erreur est survenue (${res.statusCode}).',
      res.statusCode,
      details: err?['details'] is Map ? Map<String, dynamic>.from(err!['details'] as Map) : null,
    );
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

  /// Connexion Google : `profile` requis seulement à la première connexion.
  Future<({String token, AuthUser user})> googleAuth(String idToken, Map<String, dynamic>? profile) async {
    final body = <String, dynamic>{'idToken': idToken, if (profile != null) 'profile': profile};
    final j = await _send('POST', '/v1/auth/google', body) as Map<String, dynamic>;
    return (token: j['token'] as String, user: AuthUser.fromJson(j['user'] as Map<String, dynamic>));
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

  Future<Conversation> conversationMessages(String id) async {
    final j = await _send('GET', '/v1/conversations/$id/messages') as Map<String, dynamic>;
    return Conversation.fromJson(j);
  }

  /// Envoie un message ; renvoie l'id de conversation (créée au besoin).
  Future<String> sendMessage(String toUserId, String body) async {
    final j = await _send('POST', '/v1/messages', {'toUserId': toUserId, 'body': body}) as Map<String, dynamic>;
    return j['conversationId'] as String;
  }

  // --- Coach / profils publics ---
  Future<CoachResult> coach({String? attribute}) async {
    final q = attribute == null ? '' : '?attribute=$attribute';
    final j = await _send('GET', '/v1/coach$q') as Map<String, dynamic>;
    return CoachResult.fromJson(j);
  }

  Future<PublicProfile> publicProfile(String userId) async {
    final j = await _send('GET', '/v1/profiles/$userId') as Map<String, dynamic>;
    return PublicProfile.fromJson(j);
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

  // --- Communauté ---
  Future<List<FeedActivity>> feed() async {
    final j = await _send('GET', '/v1/feed') as List<dynamic>;
    return j.map((e) => FeedActivity.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Réaction sur un item de feed : route vers l'endpoint event ou post selon [isPost].
  Future<void> react(String id, String emoji, {bool isPost = false}) async => isPost
      ? _send('POST', '/v1/posts/$id/reactions', {'emoji': emoji})
      : _send('POST', '/v1/reactions', {'feedEventId': id, 'emoji': emoji});

  Future<void> unreact(String id, {bool isPost = false}) async =>
      isPost ? _send('DELETE', '/v1/posts/$id/reactions') : _send('DELETE', '/v1/reactions/$id');

  /// Crée un post texte ou un partage de perf (perf_share référence un wodResultId).
  Future<FeedActivity> createPost({required String kind, String? body, String? wodResultId}) async {
    final j = await _send('POST', '/v1/posts', {
      'kind': kind,
      if (body != null && body.isNotEmpty) 'body': body,
      if (wodResultId != null) 'wodResultId': wodResultId,
    }) as Map<String, dynamic>;
    return FeedActivity.fromJson(j);
  }

  Future<List<MyResult>> myResults() async {
    final j = await _send('GET', '/v1/results') as List<dynamic>;
    return j.map((e) => MyResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deletePost(String id) async => _send('DELETE', '/v1/posts/$id');

  Future<void> reportPost(String id, String reason, {String? note}) async =>
      _send('POST', '/v1/posts/$id/report', {'reason': reason, if (note != null && note.isNotEmpty) 'note': note});

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

  Future<WodDetail> wodDetail(String id) async {
    final j = await _send('GET', '/v1/wods/$id') as Map<String, dynamic>;
    return WodDetail.fromJson(j);
  }

  Future<List<WodLeaderboardEntry>> wodLeaderboard(String id, String sex, {String variant = 'rx', String? clubId}) async {
    final q = clubId != null ? '&clubId=$clubId' : '';
    final j = await _send('GET', '/v1/wods/$id/leaderboard?sex=$sex&variant=$variant$q') as Map<String, dynamic>;
    return ((j['entries'] as List?) ?? []).map((e) => WodLeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
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

  /// Logue un résultat sur un WOD (officiel ou custom) → renvoie le profil recalculé.
  Future<Profile?> logWodResult(String wodId, Map<String, dynamic> payload) async {
    final j = await _send('POST', '/v1/wods/$wodId/results', payload) as Map<String, dynamic>;
    final p = j['profile'];
    return p == null ? null : Profile.fromJson(p as Map<String, dynamic>);
  }

  // --- Avatar ---
  Future<AvatarConfig> getAvatar() async {
    final j = await _send('GET', '/v1/me/avatar') as Map<String, dynamic>;
    return AvatarConfig.fromJson(j);
  }

  Future<void> updateAvatar(AvatarConfig config) async => _send('PATCH', '/v1/me/avatar', config.toJson());
}
