import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'session.dart';

/// Périmètre PARTAGÉ entre l'onglet « Ligue » (classement Index) et la « ligue du mois »
/// (LeagueScreen). `null` = 🌍 Ligue Mondiale (tous) ; sinon l'id d'un club auquel l'utilisateur
/// appartient (classement restreint à ses membres). Sélectionné une seule fois, tout en haut de
/// l'onglet Ligue, et lu par les deux écrans pour filtrer leurs classements respectifs.
final leagueScopeClubIdProvider = StateProvider<String?>((ref) => null);

/// Clubs de l'utilisateur, pour peupler le sélecteur de périmètre. Best-effort : liste vide si
/// déconnecté ou erreur réseau (l'app reste alors en Ligue Mondiale).
final myLeagueClubsProvider = FutureProvider<List<ClubSummary>>((ref) async {
  final s = ref.watch(sessionProvider);
  if (s.status != AuthStatus.loggedIn) return const [];
  try {
    return await ref.read(apiClientProvider).myClubs();
  } catch (_) {
    return const [];
  }
});
