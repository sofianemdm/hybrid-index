import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/theme/tokens.dart';
import 'package:hybrid_index/widgets/rank_badge.dart';

void main() {
  testWidgets('RankBadge affiche le libellé FR du rang', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: RankBadge(rank: 'diamond'))),
    ));
    expect(find.text('DIAMANT'), findsOneWidget);
  });

  test('HiLabels mappe attributs et rangs en FR', () {
    expect(HiLabels.attribute('muscular_endurance'), 'Endurance');
    expect(HiLabels.rank('elite'), 'Élite');
  });
}
