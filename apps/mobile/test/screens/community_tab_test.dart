import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/community/community_tab.dart';

import '../helpers/screen_harness.dart';

/// Communauté — régression verrouillée : le titre « Communauté » se coupait (« é » à la ligne)
/// quand les 4 icônes d'action serraient l'espace sur petit écran.
void main() {
  group('CommunityTab', () {
    for (final width in const [320.0, 400.0]) {
      testWidgets('fil avec posts @${width.toInt()} — aucun débordement + golden', (tester) async {
        await pumpAppScreen(tester, const CommunityTab(), api: fakeApi(), width: width);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Kevin'), findsWidgets); // post du fil rendu
        await expectLater(
          find.byType(CommunityTab),
          matchesGoldenFile('goldens/community_${width.toInt()}.png'),
        );
      });
    }
  });
}
