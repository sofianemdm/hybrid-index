import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/data/models.dart';

/// INC. 3 — FOURCHETTE : le modèle `WodPrediction` parse l'intervalle { low, mid, high } + la
/// confiance, et expose `hasRange`. Fallback : un point seul (repli population) ⇒ pas de fourchette.
/// Garde-fou : purement AFFICHAGE — aucune incidence sur la notation / l'Index.
void main() {
  group('WodPrediction.fromJson — fourchette', () {
    test('fourchette complète : low/mid/high + confidence parsés, hasRange = true', () {
      final p = WodPrediction.fromJson(const {
        'predictedRaw': 600,
        'predictedLow': 540,
        'predictedHigh': 660,
        'confidence': 'medium',
        'scoreType': 'time',
      });
      expect(p.predictedRaw, 600);
      expect(p.predictedLow, 540);
      expect(p.predictedHigh, 660);
      expect(p.confidence, 'medium');
      expect(p.hasRange, isTrue);
      // low ≤ mid ≤ high (contrat de bout en bout).
      expect(p.predictedLow! <= p.predictedRaw!, isTrue);
      expect(p.predictedRaw! <= p.predictedHigh!, isTrue);
    });

    test('point seul (repli population) : bornes absentes ⇒ hasRange = false', () {
      final p = WodPrediction.fromJson(const {
        'predictedRaw': 1200,
        'scoreType': 'time',
      });
      expect(p.predictedRaw, 1200);
      expect(p.predictedLow, isNull);
      expect(p.predictedHigh, isNull);
      expect(p.confidence, isNull);
      expect(p.hasRange, isFalse);
    });

    test('non prédictible : predictedRaw null ⇒ hasRange = false', () {
      final p = WodPrediction.fromJson(const {
        'predictedRaw': null,
        'scoreType': 'reps',
      });
      expect(p.predictedRaw, isNull);
      expect(p.hasRange, isFalse);
    });
  });
}
