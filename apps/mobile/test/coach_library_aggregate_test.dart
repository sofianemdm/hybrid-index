import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/data/models.dart';
import 'package:hybrid_index/features/coach/coach_library_aggregate.dart';

CoachSession s(String id, {required int durationMin, required String name, String primaryAttribute = 'engine'}) =>
    CoachSession(
      id: id,
      name: name,
      primaryAttribute: primaryAttribute,
      requiresEquipment: false,
      durationMin: durationMin,
      intensity: 'medium',
      description: 'desc',
    );

void main() {
  test('liste vide → résultat vide', () {
    expect(aggregateAllSessions(const []), isEmpty);
    expect(aggregateAllSessions([<CoachSession>[]]), isEmpty);
  });

  test('déduplique par id (une séance remontée sur plusieurs axes n\'apparaît qu\'une fois)', () {
    final shared = s('a', durationMin: 20, name: 'Alpha', primaryAttribute: 'engine');
    final out = aggregateAllSessions([
      [shared, s('b', durationMin: 30, name: 'Bravo')],
      [shared, s('c', durationMin: 25, name: 'Charlie')], // 'a' réapparaît
    ]);
    final ids = out.map((e) => e.id).toList();
    expect(ids.length, 3);
    expect(ids.toSet(), {'a', 'b', 'c'});
    expect(ids.where((id) => id == 'a').length, 1);
  });

  test('première occurrence conservée lors de la dédup', () {
    final first = s('x', durationMin: 10, name: 'Premier', primaryAttribute: 'speed');
    final second = s('x', durationMin: 99, name: 'Doublon', primaryAttribute: 'power');
    final out = aggregateAllSessions([
      [first],
      [second],
    ]);
    expect(out.single.name, 'Premier');
    expect(out.single.primaryAttribute, 'speed');
  });

  test('tri par durée croissante', () {
    final out = aggregateAllSessions([
      [s('a', durationMin: 45, name: 'A'), s('b', durationMin: 15, name: 'B'), s('c', durationMin: 30, name: 'C')],
    ]);
    expect(out.map((e) => e.durationMin).toList(), [15, 30, 45]);
  });

  test('à durée égale, tri par nom (ordre stable)', () {
    final out = aggregateAllSessions([
      [s('a', durationMin: 20, name: 'Zoulou'), s('b', durationMin: 20, name: 'Alpha'), s('c', durationMin: 20, name: 'Mike')],
    ]);
    expect(out.map((e) => e.name).toList(), ['Alpha', 'Mike', 'Zoulou']);
  });
}
