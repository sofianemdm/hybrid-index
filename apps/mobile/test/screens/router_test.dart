import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/league/league_screen.dart';
import 'package:hybrid_index/features/wods/wod_detail_screen.dart';

import '../helpers/screen_harness.dart';

/// Deep links (go_router) : ouvrir l'app par une URL doit afficher le BON écran, avec l'accueil
/// en dessous (bouton retour → l'app, pas la sortie).
void main() {
  group('Deep links', () {
    testWidgets('/seance/fran → détail de la séance (nom résolu via le catalogue)', (tester) async {
      await pumpAppAtLocation(tester, '/seance/fran', api: fakeApi());
      expect(find.byType(WodDetailScreen), findsOneWidget);
      expect(find.textContaining('Fran'), findsWidgets);
    });

    testWidgets('/ligue → écran Ligue du mois', (tester) async {
      await pumpAppAtLocation(tester, '/ligue', api: fakeApi());
      expect(find.byType(LeagueScreen), findsOneWidget);
    });
  });
}
