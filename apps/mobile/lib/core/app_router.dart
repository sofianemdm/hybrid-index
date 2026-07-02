import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart' show AuthGate, appNavigatorKey;
import '../data/session.dart';
import '../data/wod_catalog.dart';
import '../features/league/league_screen.dart';
import '../features/messaging/chat_screen.dart';
import '../features/profile/public_profile_screen.dart';
import '../features/wods/wod_detail_screen.dart';

/// ROUTEUR de l'app (go_router) — donne une ADRESSE aux écrans clés :
///   /seance/:id          détail d'une séance (ex. /seance/fran)
///   /profil/:id          profil public d'un athlète
///   /conversation/:userId chat direct (query `nom` = pseudo affiché)
///   /ligue               Ligue du mois
///
/// Pourquoi : deep links (une notification/un lien d'invitation ouvre le BON écran, App Links
/// Android), URLs web réelles (F5 conserve l'écran). Migration PROGRESSIVE : la navigation
/// impérative existante (Navigator.push) continue de fonctionner sur le même Navigator.
///
/// Les routes sont des ENFANTS de `/` : un deep link construit la pile [Accueil, Écran] → le
/// bouton retour ramène à l'app, pas hors de l'app.
GoRouter buildAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    navigatorKey: appNavigatorKey, // le PushService route ses taps via cette clé — inchangé
    initialLocation: initialLocation,
    // Garde d'auth : hors connexion, tout deep link retombe sur `/` (AuthGate → écran de connexion).
    // Le lien voulu pourra être re-tapé après connexion — plus sûr qu'un écran plein d'erreurs 401.
    redirect: (context, state) {
      if (state.matchedLocation == '/') return null;
      final session = ProviderScope.containerOf(context, listen: false).read(sessionProvider);
      return session.status == AuthStatus.loggedIn ? null : '/';
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const AuthGate(),
        routes: [
          GoRoute(
            path: 'seance/:id',
            builder: (_, state) {
              final id = state.pathParameters['id']!;
              return WodDetailScreen(wodId: id, wodName: _wodNameFor(id, state));
            },
          ),
          GoRoute(
            path: 'profil/:id',
            builder: (_, state) => PublicProfileScreen(userId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'conversation/:userId',
            builder: (_, state) => ChatScreen(
              conversationId: state.uri.queryParameters['conv'],
              otherUserId: state.pathParameters['userId']!,
              otherName: state.uri.queryParameters['nom'] ?? '',
            ),
          ),
          GoRoute(path: 'ligue', builder: (_, __) => const LeagueScreen()),
        ],
      ),
    ],
  );
}

/// Nom affichable d'une séance ouverte par lien : query `nom` si fourni, sinon catalogue local
/// (WODs officiels), sinon l'id brut (l'écran rafraîchit le vrai nom via l'API).
String _wodNameFor(String id, GoRouterState state) {
  final fromQuery = state.uri.queryParameters['nom'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  for (final w in wodCatalog) {
    if (w.id == id) return w.name;
  }
  return id;
}

/// Routeur global de l'app (main.dart). Les tests construisent le leur via [buildAppRouter].
final GoRouter appRouter = buildAppRouter();

/// Navigation par adresse depuis du code SANS BuildContext (ex. tap sur une push FCM).
void pushPath(String location) => appRouter.push(location);
