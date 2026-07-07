import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hybrid_index/app.dart';
import 'package:hybrid_index/core/app_router.dart';
import 'package:hybrid_index/data/api_client.dart';
import 'package:hybrid_index/data/models.dart';
import 'package:hybrid_index/data/session.dart';
import 'package:hybrid_index/l10n/app_localizations.dart';
import 'package:hybrid_index/theme/app_theme.dart';

/// HARNAIS des tests d'écrans : monte un écran complet comme en production, avec
/// - un utilisateur CONNECTÉ (session simulée),
/// - un backend SIMULÉ au niveau HTTP (MockClient) → le vrai parsing JSON des modèles est exercé,
/// - le vrai thème + la vraie localisation FR.
///
/// Les fixtures ci-dessous reproduisent la forme EXACTE des réponses de l'api NestJS.
/// Tout endpoint non listé répond 404 (les providers secondaires de l'app le tolèrent).

// ─────────────────────────── Fixtures JSON (forme des réponses api) ───────────────────────────

final Map<String, Object?> kProfileJson = {
  'index': {
    'value': 72,
    'rating': 72.4,
    'internal': 640,
    'percentile': 0.81,
    'rank': 'gold',
    'isProvisional': false,
    'isEstimated': false,
    'radarCoverage': 6,
    'rankProgress': {'current': 'gold', 'next': 'diamond', 'pointsToNext': 3, 'progress': 0.6},
  },
  'radar': [
    {'attribute': 'engine', 'score': 74, 'unlocked': true, 'isEstimated': false, 'isStale': false},
    {'attribute': 'speed', 'score': 61, 'unlocked': true, 'isEstimated': false, 'isStale': false},
    {'attribute': 'strength', 'score': 68, 'unlocked': true, 'isEstimated': false, 'isStale': false},
    {'attribute': 'power', 'score': 70, 'unlocked': true, 'isEstimated': false, 'isStale': false},
    {'attribute': 'muscular_endurance', 'score': 77, 'unlocked': true, 'isEstimated': false, 'isStale': false},
    {'attribute': 'hybrid', 'score': 72, 'unlocked': true, 'isEstimated': false, 'isStale': false},
  ],
  'socialProof': null,
  'rival': {'displayName': 'Kevin', 'rank': 'gold', 'ovr': 75, 'position': 2, 'gapPoints': 3},
  'gains': <Object?>[],
  'weakest': 'speed',
  'leaguePosition': 3,
  'leagueTotal': 12,
};

/// Variante « aucun Index » (bouton « Je n'ai aucune de ces infos ») : radar verrouillé, hors ligue.
final Map<String, Object?> kEmptyProfileJson = {
  'index': {
    'value': 35,
    'rating': null,
    'internal': 0,
    'percentile': 0,
    'rank': 'rookie',
    'isProvisional': true,
    'isEstimated': true,
    'radarCoverage': 0,
    'rankProgress': {'current': 'rookie', 'next': 'bronze', 'pointsToNext': 10, 'progress': 0.0},
  },
  'radar': [
    for (final a in ['engine', 'speed', 'strength', 'power', 'muscular_endurance', 'hybrid'])
      {'attribute': a, 'score': 0, 'unlocked': false, 'isEstimated': false, 'isStale': false},
  ],
  'socialProof': null,
  'rival': null,
  'gains': <Object?>[],
  'weakest': null,
};

final Map<String, Object?> kMeJson = {
  'id': 'u-test',
  'email': 'sofiane@test.dev',
  'displayName': 'Sofiane',
  'sex': 'male',
  'goal': 'hyrox',
  'equipmentPref': 'both',
};

final List<Object?> kFeedJson = [
  {
    'id': 'ev-1',
    'type': 'wod_logged',
    'source': 'event',
    'actor': {'userId': 'u-2', 'displayName': 'Kevin', 'rank': 'gold', 'index': 75, 'isMe': false},
    'createdAt': '2026-07-02T10:00:00.000Z',
    'payload': {'wodName': 'Fran', 'rawResult': 245, 'scoreType': 'time', 'subScore': 82},
    'kudosCount': 2,
    'iKudo': false,
    'commentCount': 1,
    'canFollow': true,
  },
  {
    'id': 'ev-2',
    'type': 'pr',
    'source': 'event',
    'actor': {'userId': 'u-3', 'displayName': 'Nora', 'rank': 'silver', 'index': 58, 'isMe': false},
    'createdAt': '2026-07-01T18:30:00.000Z',
    'payload': {'wodName': 'Benchmark Zéro', 'rawResult': 512, 'scoreType': 'time', 'subScore': 66},
    'kudosCount': 5,
    'iKudo': true,
    'commentCount': 0,
    'canFollow': true,
  },
];

final Map<String, Object?> kWodDetailJson = {
  'id': 'fran',
  'name': 'Fran',
  'scoreType': 'time',
  'requiresEquipment': true,
  'targetAttributes': ['muscular_endurance', 'power'],
  'levels': {
    'male': {'champion': 135, 'intermediate': 300, 'occasional': 540},
    'female': {'champion': 165, 'intermediate': 360, 'occasional': 640},
  },
  'myBest': {'rawResult': 245, 'subScore': 82},
  'isCustom': false,
  'isMine': false,
  'type': 'for_time',
  'prescription': {
    'summary': 'Le sprint le plus célèbre : 21-15-9 thrusters et tractions, le plus vite possible.',
    'format': '21-15-9, pour le temps',
    'blocks': [
      {'reps': '21-15-9', 'movement': 'Thrusters', 'detail': '43 kg / 30 kg'},
      {'reps': '21-15-9', 'movement': 'Tractions'},
    ],
    'weights': <Object?>[],
    'scoringNote': 'Tu enregistres ton temps total.',
  },
  'myHistory': <Object?>[],
  // Référence à note LONGUE (cas marathon réel) : verrouille le layout de la ligne
  // « World Record » (deux Text dynamiques côte à côte → tous deux flexibles, sinon la
  // colonne de gauche s'écrase en une lettre par ligne — bug vécu le 03/07).
  'references': [
    {
      'tier': 'record',
      'sex': 'male',
      'athlete': 'Sabastian Sawe',
      'result': 7170,
      'note': '1:59:30 · 1er marathon sub-2h, record du monde (Londres 2026)',
      'source': 'World Athletics',
    },
  ],
  'movementIds': ['thruster', 'pull_up'],
};

final Map<String, Object?> kWodLeaderboardJson = {'entries': <Object?>[], 'me': null};

final Map<String, Object?> kLeagueSeasonJson = {
  'monthKey': '2026-07',
  'status': 'active',
  'divisionTier': 1,
  'opensAt': '2026-07-01T00:00:00.000Z',
  'closesAt': '2026-08-01T00:00:00.000Z',
  'currentWeek': null,
  'enrolled': true,
};

final Map<String, Object?> kLeagueStandingsJson = {
  'monthKey': '2026-07',
  'sex': 'male',
  'total': 3,
  'entries': [
    {'position': 1, 'userId': 'u-2', 'displayName': 'Kevin', 'points': 950, 'isMe': false},
    {'position': 2, 'userId': 'u-3', 'displayName': 'Marc-Antoine', 'points': 720, 'isMe': false},
    {'position': 3, 'userId': 'u-test', 'displayName': 'Sofiane', 'points': 540, 'isMe': true},
  ],
  'me': {'position': 3, 'points': 540},
};

// ─────────────────────────────── Backend HTTP simulé ───────────────────────────────

http.Response _json(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Client API branché sur un faux backend. [overrides] remplace/complète les fixtures, par chemin.
/// Valeurs possibles : un JSON (réponse 200), un `int` (statut d'erreur simulé), `null` (404).
/// Correspondance par préfixe, le chemin le PLUS LONG gagne ('/v1/me' reste exact-only).
ApiClient fakeApi({Map<String, Object?>? overrides}) {
  const exactOnly = {'/v1/me'}; // préfixe de /v1/me/streak, /v1/me/history… → jamais en préfixe
  final routes = <String, Object?>{
    '/v1/me/profile': kProfileJson,
    '/v1/me/avatar': {'diceStyle': 'avataaars'},
    '/v1/me/history': <Object?>[],
    '/v1/me': kMeJson,
    '/v1/conversations': <Object?>[],
    '/v1/wods/completion-plan': {'missing': <Object?>[], 'sessions': <Object?>[]},
    '/v1/feed': kFeedJson,
    '/v1/wods/fran/leaderboard': kWodLeaderboardJson,
    '/v1/wods/fran': kWodDetailJson,
    '/v1/league/season/current': kLeagueSeasonJson,
    '/v1/league/standings': kLeagueStandingsJson,
  };
  if (overrides != null) routes.addAll(overrides); // l'override REMPLACE la fixture du même chemin
  final keys = routes.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

  final mock = MockClient((request) async {
    final path = request.url.path;
    for (final k in keys) {
      final match = path == k || (!exactOnly.contains(k) && path.startsWith(k));
      if (!match) continue;
      final body = routes[k];
      if (body == null) {
        return _json({'error': {'code': 'NOT_FOUND', 'message': 'Introuvable (test).'}}, 404);
      }
      if (body is int) {
        return _json({'error': {'code': 'ERROR', 'message': 'Erreur simulée (test).'}}, body);
      }
      return _json(body);
    }
    if (path == '/v1/league/last-result') return _json(null); // « pas de dernier résultat » légitime
    return _json({'error': {'code': 'NOT_FOUND', 'message': 'Endpoint non simulé: $path'}}, 404);
  });
  return ApiClient(client: mock, baseUrl: 'http://test.local');
}

// ─────────────────────────────── Session simulée + montage ───────────────────────────────

class _TestSession extends SessionNotifier {
  _TestSession(super.ref) {
    state = const SessionState(
      status: AuthStatus.loggedIn,
      user: AuthUser(id: 'u-test', email: 'sofiane@test.dev', displayName: 'Sofiane'),
      sex: 'male',
      goal: 'hyrox',
    );
  }
}

/// Monte [screen] comme en prod (thème sombre, FR, session connectée, backend simulé) dans une
/// surface de [width]×[height] points. Les pompes sont BORNÉES (jamais pumpAndSettle : certaines
/// animations bouclent à l'infini, ex. reflet de la carte joueur).
Future<void> pumpAppScreen(
  WidgetTester tester,
  Widget screen, {
  required ApiClient api,
  double width = 400,
  double height = 800,
  List<Override> extraOverrides = const [],
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sessionProvider.overrideWith((ref) => _TestSession(ref)),
        // Le badge boîte de réception POLLE en continu (timers interdits en fin de test) → flux figé.
        inboxBadgeProvider.overrideWith((ref) => Stream<int>.value(0)),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHiTheme(Brightness.dark),
        // Scaffold : les écrans-onglets (Accueil, Ligue, Communauté) n'ont PAS le leur (il vit
        // dans HomeShell) — sans lui, aucun Material pour les InkWell. Les écrans qui ont déjà
        // leur Scaffold s'imbriquent sans problème.
        home: Scaffold(body: screen),
      ),
    ),
  );
  // Laisse les Futures (fixtures) se résoudre et l'UI se stabiliser — bornes fixes, déterministes.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Monte l'app COMPLÈTE derrière le routeur (deep links) : `initialLocation` simule l'ouverture
/// de l'app par une URL (notification, lien d'invitation, App Link Android).
Future<void> pumpAppAtLocation(
  WidgetTester tester,
  String initialLocation, {
  required ApiClient api,
  double width = 400,
  double height = 800,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sessionProvider.overrideWith((ref) => _TestSession(ref)),
        inboxBadgeProvider.overrideWith((ref) => Stream<int>.value(0)),
      ],
      child: MaterialApp.router(
        routerConfig: buildAppRouter(initialLocation: initialLocation),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHiTheme(Brightness.dark),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
