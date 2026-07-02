import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/onboarding/onboarding_screen.dart';

import '../helpers/screen_harness.dart';

/// Onboarding — étape « Crée ton avatar » (régression verrouillée : l'éditeur était écrasé sur
/// petit écran, couleurs/formes inaccessibles ; onglets désormais sur 1 ligne défilante).
void main() {
  group('OnboardingScreen', () {
    for (final width in const [320.0, 400.0]) {
      testWidgets('étape avatar @${width.toInt()} — aucun débordement + golden', (tester) async {
        await pumpAppScreen(tester, const OnboardingScreen(), api: fakeApi(), width: width);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('avatar'), findsWidgets); // titre de l'étape rendu
        await expectLater(
          find.byType(OnboardingScreen),
          matchesGoldenFile('goldens/onboarding_avatar_${width.toInt()}.png'),
        );
      });
    }
  });
}
