import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/main.dart';

void main() {
  testWidgets('Smoke test : l\'app affiche le titre HYBRID INDEX', (tester) async {
    await tester.pumpWidget(const HybridIndexApp());
    expect(find.text('HYBRID INDEX'), findsOneWidget);
  });
}
