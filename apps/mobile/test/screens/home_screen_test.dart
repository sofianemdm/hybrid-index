import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/home/home_screen.dart';
import 'package:hybrid_index/widgets/error_retry.dart';

import '../helpers/screen_harness.dart';

/// Accueil — l'écran le plus vu. Un débordement (RenderFlex overflow) lève une exception en test
/// → `takeException()` doit rester null aux DEUX largeurs (petit téléphone 320 / standard 400).
void main() {
  group('HomeScreen', () {
    for (final width in const [320.0, 400.0]) {
      testWidgets('succès @${width.toInt()} — aucun débordement + golden', (tester) async {
        await pumpAppScreen(tester, const HomeScreen(), api: fakeApi(), width: width);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(HomeScreen),
          matchesGoldenFile('goldens/home_${width.toInt()}.png'),
        );
      });
    }

    testWidgets('erreur serveur (profil 500) → ErrorRetry', (tester) async {
      await pumpAppScreen(tester, const HomeScreen(), api: fakeApi(overrides: {'/v1/me/profile': 500}));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorRetry), findsOneWidget);
    });

    testWidgets('aucun Index (onboarding passé) → état vide + CTA séance', (tester) async {
      await pumpAppScreen(
        tester,
        const HomeScreen(),
        api: fakeApi(overrides: {'/v1/me/profile': kEmptyProfileJson}),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('pas encore révélé'), findsOneWidget);
      expect(find.textContaining('Faire une séance'), findsOneWidget);
    });
  });
}
