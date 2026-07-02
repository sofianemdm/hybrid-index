import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/settings/settings_screen.dart';

import '../helpers/screen_harness.dart';

/// Paramètres : pseudo verrouillé + adresse e-mail (lecture seule) visibles.
void main() {
  group('SettingsScreen', () {
    for (final width in const [320.0, 400.0]) {
      testWidgets('succès @${width.toInt()} — aucun débordement + golden', (tester) async {
        await pumpAppScreen(tester, const SettingsScreen(), api: fakeApi(), width: width);
        expect(tester.takeException(), isNull);
        expect(find.text('Sofiane'), findsOneWidget); // pseudo (lecture seule)
        expect(find.text('sofiane@test.dev'), findsOneWidget); // e-mail du compte
        await expectLater(
          find.byType(SettingsScreen),
          matchesGoldenFile('goldens/settings_${width.toInt()}.png'),
        );
      });
    }
  });
}
