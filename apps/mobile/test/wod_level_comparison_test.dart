import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/wods/wod_format.dart';

/// Couvre la décision PURE de la ligne comparative « estimation niveau » (plan §A).
/// Garde-fou : c'est de l'AFFICHAGE — aucune incidence sur la notation / l'Index.
void main() {
  group('wodBeatsEstimate — seuil & sens', () {
    test('valeurs manquantes → null (pas de comparaison)', () {
      expect(wodBeatsEstimate(null, 390, 'time'), isNull);
      expect(wodBeatsEstimate(390, null, 'time'), isNull);
    });

    test('estimation ≤ 0 → null (division impossible)', () {
      expect(wodBeatsEstimate(390, 0, 'time'), isNull);
    });

    test('écart faible (≤ 8 %) → null (pas de bruit)', () {
      // 390 vs 400 ⇒ 2,5 % d'écart → on n'affiche rien.
      expect(wodBeatsEstimate(390, 400, 'time'), isNull);
      // Pile au seuil de 8 % → toujours masqué (strictement > pour afficher).
      expect(wodBeatsEstimate(432, 400, 'time'), isNull);
    });

    test('time : plus court que l\'estimation et écart > 8 % → dépasse son niveau (true)', () {
      // 5:00 vs estimation 6:30 ⇒ 23 % plus rapide.
      expect(wodBeatsEstimate(300, 390, 'time'), isTrue);
    });

    test('time : plus lent que l\'estimation et écart > 8 % → marge de progression (false)', () {
      // 9:50 (590 s) vs estimation 6:30 (390 s) ⇒ 51 % plus lent.
      expect(wodBeatsEstimate(590, 390, 'time'), isFalse);
    });

    test('reps : plus haut que l\'estimation → dépasse son niveau (true)', () {
      // Plus de reps = mieux : 220 vs estimation 180 ⇒ 22 % au-dessus.
      expect(wodBeatsEstimate(220, 180, 'reps'), isTrue);
    });

    test('load : plus bas que l\'estimation → marge de progression (false)', () {
      // Plus de charge = mieux : 100 kg vs estimation 120 kg ⇒ 17 % en dessous.
      expect(wodBeatsEstimate(100, 120, 'load'), isFalse);
    });
  });
}
