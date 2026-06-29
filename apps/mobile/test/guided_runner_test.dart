import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/guided/guided_plan.dart';
import 'package:hybrid_index/features/guided/guided_runner.dart';

/// Plan EMOM minimal SANS prep, pour tester l'avance de phase au temps exact.
GuidedPlan _emomNoPrep(int minutes) => GuidedPlan(
      format: 'emom',
      clock: GuidedClock.countDown,
      totalRounds: minutes,
      phases: [
        for (var k = 1; k <= minutes; k++)
          GuidedPhase(
            kind: GuidedPhaseKind.work,
            duration: const Duration(seconds: 60),
            label: 'Minute $k / $minutes',
            roundIndex: k,
          ),
        const GuidedPhase(kind: GuidedPhaseKind.done, label: 'Terminé'),
      ],
    );

void main() {
  group('GuidedRunner — avance de phase (horloge murale)', () {
    test('avance à la phase suivante exactement au temps cible, pas avant', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(3), clock: clock);
      runner.start();
      expect(runner.phaseIndex, 0);

      // 59,9 s : encore dans la minute 1.
      clock.advance(const Duration(milliseconds: 59900));
      runner.tick();
      expect(runner.phaseIndex, 0);

      // 60 s pile : bascule sur la minute 2.
      clock.advance(const Duration(milliseconds: 100));
      runner.tick();
      expect(runner.phaseIndex, 1);
      expect(runner.currentPhase.roundIndex, 2);
    });

    test('rejoue plusieurs bascules manquées en un seul tick (rattrapage background)', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(5), clock: clock);
      runner.start();
      // App en arrière-plan 3 min 10 s → au resync, on doit être sur la minute 4 (index 3).
      clock.advance(const Duration(seconds: 190));
      runner.tick();
      expect(runner.phaseIndex, 3);
      expect(runner.currentPhase.roundIndex, 4);
    });

    test('détecte la fin quand toutes les phases sont écoulées', () {
      final clock = FakeClock();
      var completed = false;
      final runner = GuidedRunner(
        _emomNoPrep(2),
        clock: clock,
        onEvent: (e) {
          if (e.type == GuidedEventType.completed) completed = true;
        },
      );
      runner.start();
      clock.advance(const Duration(seconds: 120));
      runner.tick();
      expect(runner.isFinished, isTrue);
      expect(completed, isTrue);
      expect(runner.currentPhase.kind, GuidedPhaseKind.done);
    });

    test('pas de dérive : 100 ticks de 600ms = 60s pile, une seule bascule', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(2), clock: clock);
      runner.start();
      for (var i = 0; i < 100; i++) {
        clock.advance(const Duration(milliseconds: 600));
        runner.tick();
      }
      // 100 * 600ms = 60s → exactement une bascule (jamais 0, jamais 2 par dérive).
      expect(runner.phaseIndex, 1);
      expect(runner.elapsedInPhase, const Duration(seconds: 0));
    });
  });

  group('GuidedRunner — pause / reprise', () {
    test('pause gèle le temps (le tick ne fait plus avancer)', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(3), clock: clock);
      runner.start();
      clock.advance(const Duration(seconds: 30));
      runner.tick();
      expect(runner.elapsedInPhase, const Duration(seconds: 30));

      runner.pause();
      expect(runner.isPaused, isTrue);
      // L'horloge factice « tourne » seulement si start() : après stop(), advance() est sans effet.
      clock.advance(const Duration(seconds: 100));
      runner.tick();
      expect(runner.phaseIndex, 0); // n'a pas basculé
      expect(runner.elapsedInPhase, const Duration(seconds: 30)); // gelé

      runner.resume();
      clock.advance(const Duration(seconds: 30));
      runner.tick();
      expect(runner.phaseIndex, 1); // 30 + 30 = 60 → bascule
    });
  });

  group('GuidedRunner — skip / previous', () {
    test('skip avance d\'une phase et redémarre son chrono', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(3), clock: clock);
      runner.start();
      clock.advance(const Duration(seconds: 20));
      runner.tick();
      runner.skip();
      expect(runner.phaseIndex, 1);
      expect(runner.elapsedInPhase, Duration.zero); // chrono de la nouvelle phase reparti de 0
    });

    test('previous revient à la phase précédente (jamais sous 0)', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(3), clock: clock);
      runner.start();
      runner.skip();
      expect(runner.phaseIndex, 1);
      runner.previous();
      expect(runner.phaseIndex, 0);
      runner.previous(); // déjà à 0 → reste à 0
      expect(runner.phaseIndex, 0);
    });

    test('skip jusqu\'à done termine la séance', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(1), clock: clock);
      runner.start();
      runner.skip(); // index 1 = done
      expect(runner.isFinished, isTrue);
    });
  });

  group('GuidedRunner — compteur manuel & display', () {
    test('bumpRound incrémente tant que non terminé', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(2), clock: clock);
      runner.start();
      runner.bumpRound();
      runner.bumpRound();
      expect(runner.manualRounds, 2);
    });

    test('countDown : displayTime = temps restant de la phase', () {
      final clock = FakeClock();
      final runner = GuidedRunner(_emomNoPrep(2), clock: clock);
      runner.start();
      clock.advance(const Duration(seconds: 15));
      runner.tick();
      expect(runner.displayTime, const Duration(seconds: 45));
    });
  });

  group('GuidedRunner — évènements de transition', () {
    test('émet workStart à chaque entrée de phase work (top de minute)', () {
      final clock = FakeClock();
      final events = <GuidedEventType>[];
      final runner = GuidedRunner(
        _emomNoPrep(3),
        clock: clock,
        onEvent: (e) => events.add(e.type),
      );
      runner.start(); // entre dans minute 1 → workStart
      clock.advance(const Duration(seconds: 60));
      runner.tick(); // minute 2 → workStart
      clock.advance(const Duration(seconds: 60));
      runner.tick(); // minute 3 → workStart
      expect(events.where((e) => e == GuidedEventType.workStart).length, 3);
    });

    test('plan avec prep émet prepTick à 3/2/1', () {
      final clock = FakeClock();
      final ticks = <int>[];
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'amrap', capSec: 60),
        wodId: 'w',
        scoreType: 'reps',
      );
      final runner = GuidedRunner(
        plan,
        clock: clock,
        onEvent: (e) {
          if (e.type == GuidedEventType.prepTick) ticks.add(e.secondsLeft!);
        },
      );
      runner.start();
      // prep = 10 s ; on avance seconde par seconde pour capter 3,2,1.
      for (var i = 0; i < 10; i++) {
        clock.advance(const Duration(seconds: 1));
        runner.tick();
      }
      expect(ticks, containsAllInOrder([3, 2, 1]));
    });
  });
}
