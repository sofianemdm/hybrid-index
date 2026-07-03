import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/data/models.dart';
import 'package:hybrid_index/features/wods/wod_detail_screen.dart';

/// Déroulé tour par tour des schémas dégressifs (« 21-15-9 ») — la justesse de l'enchaînement
/// affiché aux débutants ne se devine pas, elle se teste.
void main() {
  WodBlock b(String reps, String mv) => WodBlock(reps: reps, movement: mv);

  test('Benchmark Zéro : 3 tours, squats doublés, ordre conservé', () {
    final rounds = roundsBreakdown([
      b('21-15-9', 'Burpees'),
      b('21-15-9', 'Pompes'),
      b('42-30-18', 'Squats'),
    ]);
    expect(rounds, [
      ['21 Burpees', '21 Pompes', '42 Squats'],
      ['15 Burpees', '15 Pompes', '30 Squats'],
      ['9 Burpees', '9 Pompes', '18 Squats'],
    ]);
  });

  test('bloc à valeur unique (course) répété à chaque tour', () {
    final rounds = roundsBreakdown([
      b('400 m', 'Course'),
      b('21-15-9', 'Kettlebell swings'),
    ]);
    expect(rounds!.length, 3);
    expect(rounds[1], ['400 m Course', '15 Kettlebell swings']);
  });

  test('aucun schéma → null (pas de section)', () {
    expect(roundsBreakdown([b('30', 'Épaulés-jetés')]), isNull);
  });

  test('schémas de longueurs incohérentes → null (jamais d\'info fausse)', () {
    expect(
      roundsBreakdown([b('21-15-9', 'A'), b('10-8', 'B')]),
      isNull,
    );
  });
}
