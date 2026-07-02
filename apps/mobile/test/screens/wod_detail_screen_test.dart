import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/wods/wod_detail_screen.dart';
import 'package:hybrid_index/widgets/error_retry.dart';

import '../helpers/screen_harness.dart';

/// Détail d'une séance (Fran) : paliers, prescription (avec icône info des mouvements guidés),
/// record perso, classement vide.
void main() {
  group('WodDetailScreen', () {
    for (final width in const [320.0, 400.0]) {
      testWidgets('succès @${width.toInt()} — aucun débordement + golden', (tester) async {
        await pumpAppScreen(
          tester,
          const WodDetailScreen(wodId: 'fran', wodName: 'Fran'),
          api: fakeApi(),
          width: width,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Thrusters'), findsWidgets); // prescription rendue
        await expectLater(
          find.byType(WodDetailScreen),
          matchesGoldenFile('goldens/wod_detail_${width.toInt()}.png'),
        );
      });
    }

    testWidgets('erreur serveur (détail 500) → ErrorRetry', (tester) async {
      // Le classement reste OK : sa Future n'est observée que dans la branche succès du détail —
      // la mettre aussi en erreur laisserait une Future en échec non observée (erreur de zone).
      await pumpAppScreen(
        tester,
        const WodDetailScreen(wodId: 'fran', wodName: 'Fran'),
        api: fakeApi(overrides: {'/v1/wods/fran': 500}),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorRetry), findsWidgets);
    });
  });
}
