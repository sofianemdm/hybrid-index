import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/data/models.dart';
import 'package:hybrid_index/data/projection.dart';

IndexPoint pt(int v, DateTime at) => IndexPoint(value: v, rank: 'gold', at: at);

void main() {
  final base = DateTime(2026, 1, 1);

  test('tendance positive → projette le prochain palier de 10', () {
    final h = [pt(70, base), pt(74, base.add(const Duration(days: 14)))];
    final p = projectIndex(h, 74);
    expect(p, isNotNull);
    expect(p!.targetGrade, 80);
    expect(p.weeks, 3); // 6 pts à combler / 2 pts par semaine = 3
  });

  test('pas de progression récente → null (pas de fausse promesse)', () {
    final h = [pt(74, base), pt(74, base.add(const Duration(days: 14)))];
    expect(projectIndex(h, 74), isNull);
  });

  test('trop peu de points → null', () {
    expect(projectIndex([pt(74, base)], 74), isNull);
  });

  test('tendance trop courte (< 5 j) → null', () {
    final h = [pt(70, base), pt(74, base.add(const Duration(days: 2)))];
    expect(projectIndex(h, 74), isNull);
  });

  test('déjà au sommet (100) → null', () {
    final h = [pt(98, base), pt(100, base.add(const Duration(days: 14)))];
    expect(projectIndex(h, 100), isNull);
  });
}
