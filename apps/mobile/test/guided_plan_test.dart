import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_index/features/guided/guided_plan.dart';

/// Filtre les phases « réelles » (hors prep / done) d'un type donné.
List<GuidedPhase> _phasesOf(GuidedPlan p, GuidedPhaseKind kind) =>
    p.phases.where((ph) => ph.kind == kind).toList();

void main() {
  group('GuidedPlanBuilder.fromWod — for_time', () {
    test('cap connu → une phase work bornée au cap, chrono qui monte, compteur manuel', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'for_time', rounds: 5, capSec: 600, cues: ['21-15-9 Thrusters']),
        wodId: 'grace',
        scoreType: 'time',
      );
      expect(plan.clock, GuidedClock.countUp);
      expect(plan.cap, const Duration(seconds: 600));
      expect(plan.totalRounds, 5);
      expect(plan.manualRoundCounter, isTrue);
      final work = _phasesOf(plan, GuidedPhaseKind.work);
      expect(work.length, 1);
      expect(work.first.duration, const Duration(seconds: 600));
      // prep + work + done
      expect(plan.phases.first.kind, GuidedPhaseKind.prep);
      expect(plan.phases.last.kind, GuidedPhaseKind.done);
      expect(plan.cues, ['21-15-9 Thrusters']);
    });

    test('sans cap → phase work ouverte (duration null, fin manuelle)', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'for_time'),
        wodId: 'w',
        scoreType: 'time',
      );
      expect(_phasesOf(plan, GuidedPhaseKind.work).single.duration, isNull);
    });

    test('chipper est traité comme for_time', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'chipper', capSec: 1200),
        wodId: 'w',
        scoreType: 'time',
      );
      expect(plan.format, 'for_time');
      expect(plan.clock, GuidedClock.countUp);
    });
  });

  group('GuidedPlanBuilder.fromWod — amrap', () {
    test('décompte sur la durée = cap, compteur manuel', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'amrap', capSec: 720),
        wodId: 'cindy',
        scoreType: 'reps',
      );
      expect(plan.clock, GuidedClock.countDown);
      final work = _phasesOf(plan, GuidedPhaseKind.work).single;
      expect(work.duration, const Duration(minutes: 12));
      expect(plan.manualRoundCounter, isTrue);
    });
  });

  group('GuidedPlanBuilder.fromWod — emom', () {
    test('EMOM 12 min → 12 phases work de 1 min, labellisées Minute k/N', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'emom', rounds: 12),
        wodId: 'w',
        scoreType: 'reps',
      );
      final work = _phasesOf(plan, GuidedPhaseKind.work);
      expect(work.length, 12);
      expect(work.every((p) => p.duration == const Duration(seconds: 60)), isTrue);
      expect(work.first.label, 'Minute 1 / 12');
      expect(work.last.label, 'Minute 12 / 12');
      expect(work.first.roundIndex, 1);
      expect(work.last.roundIndex, 12);
      expect(plan.totalRounds, 12);
      expect(plan.clock, GuidedClock.countDown);
    });

    test('EMOM sans rounds mais cap connu → minutes = cap/60', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'emom', capSec: 600),
        wodId: 'w',
        scoreType: 'reps',
      );
      expect(_phasesOf(plan, GuidedPhaseKind.work).length, 10);
    });

    test('EMOM sans rounds ni cap → repli documenté (10 min)', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'emom'),
        wodId: 'w',
        scoreType: 'reps',
      );
      expect(_phasesOf(plan, GuidedPhaseKind.work).length,
          GuidedPlanBuilder.emomDefaultMinutes);
    });
  });

  group('GuidedPlanBuilder.fromWod — tabata / interval', () {
    test('Tabata 20/10 x8 → 16 phases (8 work + 7 rest entre + pas de rest final) + done', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'tabata'),
        wodId: 'w',
        scoreType: 'reps',
      );
      final work = _phasesOf(plan, GuidedPhaseKind.work);
      final rest = _phasesOf(plan, GuidedPhaseKind.rest);
      expect(work.length, 8);
      expect(rest.length, 7); // pas de repos après le 8e round
      expect(work.first.duration, const Duration(seconds: 20));
      expect(rest.first.duration, const Duration(seconds: 10));
      expect(plan.totalRounds, 8);
      // alternance work/rest dans l'ordre, dernière phase utile = work
      expect(plan.phases[plan.phases.length - 2].kind, GuidedPhaseKind.work);
      expect(plan.phases.last.kind, GuidedPhaseKind.done);
    });

    test('Tabata avec fenêtres serveur explicites → respecte work/rest fournis', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(
          format: 'tabata',
          rounds: 6,
          work: [(kind: 'work', durationSec: 30), (kind: 'rest', durationSec: 15)],
        ),
        wodId: 'w',
        scoreType: 'reps',
      );
      final work = _phasesOf(plan, GuidedPhaseKind.work);
      final rest = _phasesOf(plan, GuidedPhaseKind.rest);
      expect(work.length, 6);
      expect(work.first.duration, const Duration(seconds: 30));
      expect(rest.first.duration, const Duration(seconds: 15));
    });

    test('interval sans structure → constantes par défaut + alternance', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'interval', rounds: 4),
        wodId: 'w',
        scoreType: 'reps',
      );
      expect(plan.format, 'interval');
      expect(_phasesOf(plan, GuidedPhaseKind.work).length, 4);
      expect(_phasesOf(plan, GuidedPhaseKind.rest).length, 3);
      expect(_phasesOf(plan, GuidedPhaseKind.work).first.duration,
          GuidedPlanBuilder.intervalWork);
    });
  });

  group('GuidedPlanBuilder.fromWod — strength', () {
    test('séries ouvertes (count-up) + repos chronométré entre, pas après la dernière', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'strength', rounds: 4),
        wodId: 'w',
        scoreType: 'load',
      );
      expect(plan.clock, GuidedClock.countUp);
      final work = _phasesOf(plan, GuidedPhaseKind.work);
      final rest = _phasesOf(plan, GuidedPhaseKind.rest);
      expect(work.length, 4);
      expect(rest.length, 3);
      expect(work.every((p) => p.duration == null), isTrue); // séries ouvertes
      expect(rest.first.duration, GuidedPlanBuilder.strengthRest);
      expect(work.first.label, 'Série 1 / 4');
      expect(work.last.label, 'Série 4 / 4');
      expect(plan.manualRoundCounter, isFalse);
    });

    test('strength sans rounds → repli documenté', () {
      final plan = GuidedPlanBuilder.fromWod(
        const GuidedSource(format: 'strength'),
        wodId: 'w',
        scoreType: 'load',
      );
      expect(_phasesOf(plan, GuidedPhaseKind.work).length,
          GuidedPlanBuilder.strengthDefaultSets);
    });
  });

  group('GuidedPlanBuilder.fromCoachSession — mode simplifié (free)', () {
    test('durée connue → countDown borné + cue = description', () {
      final plan = GuidedPlanBuilder.fromCoachSession(
        sessionId: 's1',
        durationMin: 20,
        description: 'Gainage + mobilité',
      );
      expect(plan.format, 'free');
      expect(plan.clock, GuidedClock.countDown);
      expect(plan.coachSessionId, 's1');
      expect(plan.wodId, isNull);
      final work = _phasesOf(plan, GuidedPhaseKind.work).single;
      expect(work.duration, const Duration(minutes: 20));
      expect(work.cue, 'Gainage + mobilité');
      expect(plan.manualRoundCounter, isTrue);
      // pas de prep en mode free
      expect(plan.phases.first.kind, GuidedPhaseKind.work);
    });

    test('durée 0 → countUp libre (phase ouverte)', () {
      final plan = GuidedPlanBuilder.fromCoachSession(
        sessionId: 's2',
        durationMin: 0,
        description: 'À ton rythme',
      );
      expect(plan.clock, GuidedClock.countUp);
      expect(_phasesOf(plan, GuidedPhaseKind.work).single.duration, isNull);
    });
  });

  group('GuidedSource — parsing & repli', () {
    test('fromJson parse format/rounds/cap/work/cues', () {
      final src = GuidedSource.fromJson({
        'format': 'tabata',
        'rounds': 8,
        'capSec': 240,
        'work': [
          {'kind': 'work', 'durationSec': 20},
          {'kind': 'rest', 'durationSec': 10},
          {'kind': 'rest', 'durationSec': 0}, // filtré (durée nulle)
        ],
        'cues': ['Air squats'],
      });
      expect(src.format, 'tabata');
      expect(src.rounds, 8);
      expect(src.capSec, 240);
      expect(src.work.length, 2);
      expect(src.cues, ['Air squats']);
    });

    test('fallback (back ancien) → dérive du type + cap', () {
      final src = GuidedSource.fallback(type: 'amrap', capSec: 600);
      final plan = GuidedPlanBuilder.fromWod(src, wodId: 'w', scoreType: 'reps');
      expect(plan.format, 'amrap');
      expect(plan.cap, const Duration(seconds: 600));
    });
  });
}
