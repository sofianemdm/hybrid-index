// MACHINE À ÉTATS du Mode guidé. HORLOGE MURALE : la source de temps est une `Stopwatch`
// monotone (injectable pour les tests), JAMAIS une accumulation `+= 100ms` (décision verrouillée 4).
// Le `Timer.periodic(100ms)` de l'UI ne fait qu'appeler `tick()` pour rafraîchir l'affichage ; tout
// le calcul de temps part de `_clock.elapsed`. Pause = on gèle via un offset cumulé (pas d'arrêt de
// l'horloge réelle, ce qui permet le resync au retour premier plan : on rejoue les bascules
// manquées en background). Logique 100 % pure (sauf ChangeNotifier) → testable sans widget.

import 'package:flutter/foundation.dart';

import 'guided_plan.dart';

/// Source de temps monotone, abstraite pour pouvoir injecter une horloge factice en test.
abstract class GuidedClockSource {
  /// Temps écoulé depuis le démarrage (monotone, ne recule jamais).
  Duration get elapsed;
  void start();
  void stop();
  bool get isRunning;
}

/// Implémentation réelle : `Stopwatch` (horloge murale monotone).
class StopwatchClock implements GuidedClockSource {
  final Stopwatch _sw = Stopwatch();
  @override
  Duration get elapsed => _sw.elapsed;
  @override
  void start() => _sw.start();
  @override
  void stop() => _sw.stop();
  @override
  bool get isRunning => _sw.isRunning;
}

/// Horloge factice pilotée à la main en test : on AVANCE le temps explicitement.
class FakeClock implements GuidedClockSource {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  /// Avance l'horloge (n'a d'effet visible que si elle « tourne » — comme une vraie Stopwatch).
  void advance(Duration d) {
    if (_running) _elapsed += d;
  }

  @override
  Duration get elapsed => _elapsed;
  @override
  void start() => _running = true;
  @override
  void stop() => _running = false;
  @override
  bool get isRunning => _running;
}

/// Évènement de transition émis par le runner → l'UI y branche signaux (SystemSound) + haptique.
enum GuidedEventType {
  /// Décompte de préparation : une seconde vient de tomber (3, 2, 1).
  prepTick,

  /// Une phase de TRAVAIL vient de commencer (top minute EMOM, début work interval/tabata, série).
  workStart,

  /// Une phase de REPOS vient de commencer.
  restStart,

  /// Top de minute / bascule de fenêtre (signal neutre additionnel si besoin).
  windowBoundary,

  /// La séance est terminée (dernière phase atteinte).
  completed,
}

class GuidedEvent {
  final GuidedEventType type;

  /// Phase ENTRÉE par cette transition (null pour `completed` si on veut, mais on la fournit).
  final GuidedPhase? phase;

  /// Secondes restantes affichées au moment du `prepTick` (3, 2, 1).
  final int? secondsLeft;

  const GuidedEvent(this.type, {this.phase, this.secondsLeft});
}

/// État courant du lecteur. ChangeNotifier pour l'UI ; toute la logique de temps est déterministe.
class GuidedRunner extends ChangeNotifier {
  final GuidedPlan plan;
  final GuidedClockSource _clock;

  /// Branche les signaux/haptique au niveau UI (le moteur n'importe AUCUNE dépendance native).
  final void Function(GuidedEvent event)? onEvent;

  GuidedRunner(
    this.plan, {
    GuidedClockSource? clock,
    this.onEvent,
  }) : _clock = clock ?? StopwatchClock();

  int _phaseIndex = 0;

  /// Temps total écoulé (toutes phases) au DÉBUT de la phase courante. Sert d'offset pour calculer
  /// le temps DANS la phase : `elapsedInPhase = _clock.elapsed - _phaseStartElapsed`.
  Duration _phaseStartElapsed = Duration.zero;

  bool _started = false;
  bool _finished = false;

  /// Compteur de tours manuel (for_time/amrap/free), incrémenté par l'athlète.
  int _manualRounds = 0;

  /// Dernière seconde de prep signalée (pour n'émettre qu'un `prepTick` par seconde).
  int _lastPrepSecond = -1;

  // --- Accès lecture ---
  int get phaseIndex => _phaseIndex;
  GuidedPhase get currentPhase => plan.phases[_phaseIndex];
  bool get isRunning => _clock.isRunning;
  bool get isPaused => _started && !_finished && !_clock.isRunning;
  bool get isFinished => _finished;
  int get manualRounds => _manualRounds;

  /// Temps écoulé DANS la phase courante (horloge murale, jamais accumulé).
  Duration get elapsedInPhase {
    final e = _clock.elapsed - _phaseStartElapsed;
    return e.isNegative ? Duration.zero : e;
  }

  /// Temps total écoulé depuis le départ (pour la pré-saisie du résultat for_time).
  Duration get totalElapsed => _clock.elapsed;

  /// Temps de l'EFFORT réel, HORS décompte de prépa (3·2·1). C'est ce qu'on affiche/enregistre à la
  /// fin : le compte à rebours ne fait pas partie du temps de la séance (corrige le décalage +3 s).
  Duration get effortElapsed {
    final first = plan.phases.isNotEmpty ? plan.phases.first : null;
    final prep =
        (first != null && first.kind == GuidedPhaseKind.prep) ? (first.duration ?? Duration.zero) : Duration.zero;
    final e = _clock.elapsed - prep;
    return e.isNegative ? Duration.zero : e;
  }

  /// Temps restant de la phase courante si elle est bornée, sinon `null` (phase ouverte).
  Duration? get remainingInPhase {
    final d = currentPhase.duration;
    if (d == null) return null;
    final r = d - elapsedInPhase;
    return r.isNegative ? Duration.zero : r;
  }

  /// Valeur à afficher au chrono selon le sens d'horloge du plan.
  Duration get displayTime {
    if (plan.clock == GuidedClock.countDown) {
      return remainingInPhase ?? elapsedInPhase;
    }
    return elapsedInPhase;
  }

  /// Démarre la séance (entre dans la première phase et lance l'horloge).
  void start() {
    if (_started) return;
    _started = true;
    _phaseIndex = 0;
    _phaseStartElapsed = Duration.zero;
    _clock.start();
    _emitPhaseStart(currentPhase);
    // Si la première phase est une PRÉPA, on émet TOUT DE SUITE le premier chiffre du décompte
    // (ex. « 3 ») sans attendre le premier tick — l'overlay 3·2·1·GO démarre dès l'appui sur Démarrer.
    _maybeEmitPrepTick();
    notifyListeners();
  }

  /// Émet un `prepTick` (3/2/1) si la phase courante est une prépa et que la seconde a changé.
  /// Idempotent par seconde grâce à `_lastPrepSecond`.
  void _maybeEmitPrepTick() {
    if (currentPhase.kind != GuidedPhaseKind.prep) return;
    // CEIL (et non troncature inSeconds) : chaque chiffre reste affiché 1 s PLEINE → vrai
    // « 3 · 2 · 1 ». Avant, inSeconds tronquait « 3 » à ~100 ms → on ne voyait que « 2 1 ».
    final left = ((remainingInPhase ?? Duration.zero).inMilliseconds / 1000).ceil();
    if (left <= 3 && left >= 1 && left != _lastPrepSecond) {
      _lastPrepSecond = left;
      onEvent?.call(GuidedEvent(GuidedEventType.prepTick, secondsLeft: left));
    }
  }

  void pause() {
    if (!_started || _finished || !_clock.isRunning) return;
    _clock.stop();
    notifyListeners();
  }

  void resume() {
    if (!_started || _finished || _clock.isRunning) return;
    _clock.start();
    notifyListeners();
  }

  /// Incrémente le compteur de tours manuel (for_time/amrap/free).
  void bumpRound() {
    if (!_started || _finished) return;
    _manualRounds++;
    notifyListeners();
  }

  /// Passe à la phase suivante (skip utilisateur). Réinitialise l'offset de phase au temps courant.
  void skip() {
    if (!_started || _finished) return;
    _advanceTo(_phaseIndex + 1);
  }

  /// Revient à la phase précédente (≥ 0). Réinitialise l'offset au temps courant.
  void previous() {
    if (!_started || _finished) return;
    if (_phaseIndex == 0) return;
    _advanceTo(_phaseIndex - 1);
  }

  /// Tick d'affichage. Appelé par le `Timer.periodic` de l'UI (≈100ms) OU au resync `resumed`.
  /// Ne MESURE rien : il LIT `_clock.elapsed` et déclenche les bascules de phase atteintes.
  /// Plusieurs bascules peuvent être rejouées d'affilée (rattrapage background) — d'où la boucle.
  void tick() {
    if (!_started || _finished || !_clock.isRunning) return;

    // Signaux de décompte de prep (3-2-1) sur la phase de préparation.
    _maybeEmitPrepTick();

    // Rejoue toutes les bascules de phase dont la durée est échue (rattrapage après background).
    var guard = 0;
    while (!_finished && currentPhase.isBounded && elapsedInPhase >= currentPhase.duration!) {
      // L'offset de la phase suivante = offset courant + durée pile de la phase échue (pas
      // `_clock.elapsed`), pour ne PAS perdre le débordement et garder une horloge murale exacte.
      _phaseStartElapsed += currentPhase.duration!;
      _advanceToInternal(_phaseIndex + 1, resetOffset: false);
      if (++guard > plan.phases.length + 2) break; // garde-fou anti-boucle
    }
    notifyListeners();
  }

  // --- interne ---

  /// Skip/previous manuel : la phase cible démarre MAINTENANT (offset = temps courant).
  void _advanceTo(int index) => _advanceToInternal(index, resetOffset: true);

  void _advanceToInternal(int index, {required bool resetOffset}) {
    final clamped = index.clamp(0, plan.phases.length - 1);
    _phaseIndex = clamped;
    _lastPrepSecond = -1;
    if (resetOffset) {
      _phaseStartElapsed = _clock.elapsed;
    }
    final phase = plan.phases[_phaseIndex];
    if (phase.kind == GuidedPhaseKind.done) {
      _finish();
      return;
    }
    _emitPhaseStart(phase);
    notifyListeners();
  }

  void _emitPhaseStart(GuidedPhase phase) {
    switch (phase.kind) {
      case GuidedPhaseKind.work:
        onEvent?.call(GuidedEvent(GuidedEventType.workStart, phase: phase));
        break;
      case GuidedPhaseKind.rest:
        onEvent?.call(GuidedEvent(GuidedEventType.restStart, phase: phase));
        break;
      case GuidedPhaseKind.roundBreak:
        onEvent?.call(GuidedEvent(GuidedEventType.windowBoundary, phase: phase));
        break;
      case GuidedPhaseKind.prep:
      case GuidedPhaseKind.done:
        break;
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _clock.stop();
    onEvent?.call(GuidedEvent(GuidedEventType.completed, phase: plan.phases.last));
    notifyListeners();
  }
}
