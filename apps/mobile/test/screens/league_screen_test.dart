import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/league/league_screen.dart';

import '../helpers/screen_harness.dart';

/// Ligue du mois — régression verrouillée : la carte « Ma position » débordait à droite
/// (texte « Fais la séance… » hors écran) sur petit téléphone.
void main() {
  group('LeagueScreen', () {
    for (final width in const [320.0, 400.0]) {
      testWidgets('succès @${width.toInt()} — aucun débordement + golden', (tester) async {
        await pumpAppScreen(tester, const LeagueScreen(), api: fakeApi(), width: width);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Kevin'), findsWidgets); // classement rendu
        await expectLater(
          find.byType(LeagueScreen),
          matchesGoldenFile('goldens/league_${width.toInt()}.png'),
        );
      });
    }

    testWidgets('classement vide (saison sans points) — pas de crash', (tester) async {
      await pumpAppScreen(
        tester,
        const LeagueScreen(),
        api: fakeApi(overrides: {
          '/v1/league/standings': {
            'monthKey': '2026-07',
            'sex': 'male',
            'total': 0,
            'entries': <Object?>[],
            'me': null,
          },
        }),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
