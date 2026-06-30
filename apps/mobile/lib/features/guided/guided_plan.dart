// MOTEUR du Mode guidé — modèle + builder. LOGIQUE PURE : aucun import Flutter (sauf `Duration`,
// fourni par dart:core). Le lecteur (runner + UI) ne lit JAMAIS un `WodDetail`/`CoachSession`
// brut ; il consomme un `GuidedPlan` déjà normalisé. C'est la frontière qui rend la machine à
// états triviale et 100 % testable sans widget (cf. docs/plan-mode-guide.md §1-§2).

/// Nature d'une phase atomique de la séance.
enum GuidedPhaseKind {
  /// Compte à rebours d'entrée « 3-2-1 GO » avant le départ (sautable).
  prep,

  /// Fenêtre de travail (effort) — for_time, AMRAP, minute EMOM, work interval/tabata, série force.
  work,

  /// Fenêtre de repos chronométrée (interval/tabata, entre séries de force).
  rest,

  /// Pause entre tours (séparateur sans effort), si un format en a besoin.
  roundBreak,

  /// Fin de la séance. Toujours la DERNIÈRE phase d'un plan.
  done,
}

/// Comportement du chrono pendant une phase :
/// - countUp  : le temps MONTE (for_time, strength, free-run) — pas de cible de fin par le temps.
/// - countDown: le temps DESCEND vers 0 (AMRAP, fenêtre EMOM, work/rest interval/tabata).
enum GuidedClock { countUp, countDown }

/// Une phase atomique de la séance. Le lecteur déroule la liste `phases` dans l'ordre.
class GuidedPhase {
  final GuidedPhaseKind kind;

  /// Durée bornée de la phase. `null` = phase OUVERTE (count-up libre, l'athlète termine à la
  /// main) : for_time sans cap, repos non chronométré, série de force, etc.
  final Duration? duration;

  /// Libellé court affiché (ex. « Échauffe-toi », « TRAVAIL », « REPOS », « Tour 2 / 5 »,
  /// « Minute 3 / 10 », « Série 1 / 4 »).
  final String label;

  /// Consigne longue optionnelle (mouvements à enchaîner) affichée sous le chrono.
  final String? cue;

  /// Numéro de tour/minute/série 1-based si la phase appartient à un cycle (sinon `null`).
  final int? roundIndex;

  const GuidedPhase({
    required this.kind,
    this.duration,
    required this.label,
    this.cue,
    this.roundIndex,
  });

  /// Phase à durée connue (déclenche une bascule automatique sur le temps).
  bool get isBounded => duration != null;

  @override
  String toString() =>
      'GuidedPhase($kind, ${duration?.inSeconds}s, "$label"${roundIndex == null ? '' : ', r$roundIndex'})';
}

/// Séance normalisée prête à dérouler : liste ORDONNÉE de phases + métadonnées de format.
class GuidedPlan {
  /// Format source ('for_time'|'amrap'|'emom'|'interval'|'tabata'|'strength'|'free') — pilote l'UI.
  final String format;
  final GuidedClock clock;

  /// Nombre de tours/rounds/minutes/séries total si connu (affichage « k/N »), sinon `null`.
  final int? totalRounds;

  /// Cap global de la séance (for_time/amrap), sinon `null`.
  final Duration? cap;

  /// Liste ORDONNÉE des phases. La dernière est TOUJOURS `GuidedPhaseKind.done`.
  final List<GuidedPhase> phases;

  /// Consignes générales (mouvements + charges) affichées en bas / au repos.
  final List<String> cues;

  /// La séance produit-elle un RÉSULTAT loguable (WOD) ? Si oui, `wodId` + `scoreType` pour router
  /// vers la saisie. Si non (CoachSession), `coachSessionId` pour créditer la série.
  final String? wodId;
  final String? scoreType;
  final String? coachSessionId;

  /// Compteur de tours manuel pertinent ? (for_time/amrap sans rounds structurés, mode simplifié).
  final bool manualRoundCounter;

  const GuidedPlan({
    required this.format,
    required this.clock,
    this.totalRounds,
    this.cap,
    required this.phases,
    this.cues = const [],
    this.wodId,
    this.scoreType,
    this.coachSessionId,
    this.manualRoundCounter = false,
  });

  /// Nombre de phases « réelles » hors `done` (utile pour la barre de progression).
  int get workPhaseCount => phases.where((p) => p.kind != GuidedPhaseKind.done).length;

  /// La séance comporte-t-elle PLUSIEURS tours déclarés ? `totalRounds == null` ⇒ structure de
  /// tours inconnue ⇒ un seul tour implicite.
  bool get isMultiRound => (totalRounds ?? 1) > 1;

  /// Faut-il proposer le compteur / bouton « Tour +1 » manuel ?
  /// - AMRAP : le nombre de tours EST le score → toujours pertinent (même sans total déclaré).
  /// - for_time : seulement si la séance est explicitement MULTI-TOURS (`totalRounds > 1`). Un
  ///   for_time à un seul effort (ex. une course) ne doit pas afficher de compteur de tours.
  /// - free (séance coach) : masqué sauf multi-tours déclaré (jamais en pratique).
  /// Évite le bouton de tour parasite sur une séance à UN SEUL tour (cf. bug compteur de tour).
  bool get showManualRoundCounter =>
      manualRoundCounter && (format == 'amrap' || isMultiRound);

  /// La séance crédite-t-elle une CoachSession (mode simplifié) plutôt qu'un WOD loguable ?
  bool get isCoachSession => coachSessionId != null;
}

/// Données du bloc `guided` exposé par `GET /v1/wods/:id` (cf. wods.service.ts > buildGuided).
/// Découplé de `WodDetail` pour garder le builder testable sans tirer tout le modèle.
class GuidedSource {
  final String format;
  final int? rounds;
  final int? capSec;

  /// Fenêtres canoniques connues côté serveur (ex. Tabata 20/10). Vide → repli builder.
  final List<({String kind, int durationSec})> work;
  final List<String> cues;

  const GuidedSource({
    required this.format,
    this.rounds,
    this.capSec,
    this.work = const [],
    this.cues = const [],
  });

  /// Repli quand le bloc `guided` est ABSENT (vieux back) : on dérive du seul `type` + cap.
  /// EMOM/interval/tabata retombent alors sur les constantes canoniques du builder.
  factory GuidedSource.fallback({required String type, int? capSec, int? rounds}) =>
      GuidedSource(format: type, rounds: rounds, capSec: capSec);

  factory GuidedSource.fromJson(Map<String, dynamic> j) => GuidedSource(
        format: j['format'] as String? ?? 'for_time',
        rounds: (j['rounds'] as num?)?.toInt(),
        capSec: (j['capSec'] as num?)?.toInt(),
        work: ((j['work'] as List?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .map((m) => (
                  kind: m['kind'] as String? ?? 'work',
                  durationSec: (m['durationSec'] as num?)?.toInt() ?? 0,
                ))
            .where((w) => w.durationSec > 0)
            .toList(),
        cues: ((j['cues'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

/// Builder PUR : dérive un `GuidedPlan` d'un WOD structuré (`GuidedSource`) ou d'une CoachSession.
/// Toutes les méthodes sont statiques et déterministes → testables sans Flutter.
class GuidedPlanBuilder {
  GuidedPlanBuilder._();

  // --- Constantes canoniques documentées (cf. plan §2) ---
  /// Compte à rebours d'entrée « 3 · 2 · 1 · GO » : EXACTEMENT 3 s pour qu'une SEULE séquence
  /// propre tourne (overlay plein écran 3→2→1), sans qu'un chrono « tourne puis se reset ». Le
  /// chrono principal reste masqué (à 0) pendant la prep et démarre à GO (cf. UI _Chrono).
  static const Duration prep = Duration(seconds: 3);

  /// Durée d'une fenêtre EMOM (top de minute).
  static const Duration emomWindow = Duration(seconds: 60);

  /// Tabata canonique : 20 s travail / 10 s repos × 8.
  static const Duration tabataWork = Duration(seconds: 20);
  static const Duration tabataRest = Duration(seconds: 10);
  static const int tabataRounds = 8;

  /// Intervalle par défaut quand la structure n'est pas fournie.
  static const Duration intervalWork = Duration(minutes: 1);
  static const Duration intervalRest = Duration(seconds: 30);

  /// Repos par défaut entre séries de force.
  static const Duration strengthRest = Duration(seconds: 120);

  /// Replis documentés quand l'info de tours/cap manque.
  static const int emomDefaultMinutes = 10;
  static const int intervalDefaultRounds = 8;
  static const int strengthDefaultSets = 5;

  /// Phase de préparation préfixée à tout plan non-`free` (calage du départ, sautable).
  static GuidedPhase _prep(String goLabel) =>
      GuidedPhase(kind: GuidedPhaseKind.prep, duration: prep, label: goLabel);

  static const GuidedPhase _done =
      GuidedPhase(kind: GuidedPhaseKind.done, label: 'Terminé');

  /// Construit le plan d'un WOD à partir de son bloc `guided`.
  /// [labels] permet d'injecter l'i18n depuis l'UI ; valeurs par défaut FR pour les tests/repli.
  static GuidedPlan fromWod(
    GuidedSource src, {
    required String wodId,
    required String scoreType,
    GuidedLabels labels = const GuidedLabels(),
  }) {
    final cap = src.capSec != null && src.capSec! > 0
        ? Duration(seconds: src.capSec!)
        : null;
    switch (src.format) {
      case 'amrap':
        return _amrap(src, cap, wodId, scoreType, labels);
      case 'emom':
        return _emom(src, cap, wodId, scoreType, labels);
      case 'interval':
        return _interval(src, wodId, scoreType, labels, isTabata: false);
      case 'tabata':
        return _interval(src, wodId, scoreType, labels, isTabata: true);
      case 'strength':
        return _strength(src, wodId, scoreType, labels);
      case 'for_time':
      case 'chipper':
      default:
        return _forTime(src, cap, wodId, scoreType, labels);
    }
  }

  /// Mode SIMPLIFIÉ pour une CoachSession (description texte seule, pas de structure machine).
  static GuidedPlan fromCoachSession({
    required String sessionId,
    required int durationMin,
    required String description,
    GuidedLabels labels = const GuidedLabels(),
  }) {
    final hasDuration = durationMin > 0;
    final work = GuidedPhase(
      kind: GuidedPhaseKind.work,
      duration: hasDuration ? Duration(minutes: durationMin) : null,
      label: labels.work,
      cue: description.trim().isEmpty ? null : description.trim(),
    );
    return GuidedPlan(
      format: 'free',
      clock: hasDuration ? GuidedClock.countDown : GuidedClock.countUp,
      phases: [work, _done],
      cues: description.trim().isEmpty ? const [] : [description.trim()],
      coachSessionId: sessionId,
      manualRoundCounter: true,
    );
  }

  // --- Builders par format ---

  static GuidedPlan _forTime(
    GuidedSource src,
    Duration? cap,
    String wodId,
    String scoreType,
    GuidedLabels labels,
  ) {
    // for_time : le chrono MONTE. Une phase work bornée au cap (s'arrête au cap) ou ouverte.
    final work = GuidedPhase(
      kind: GuidedPhaseKind.work,
      duration: cap,
      label: labels.work,
      roundIndex: 1,
    );
    return GuidedPlan(
      format: 'for_time',
      clock: GuidedClock.countUp,
      totalRounds: src.rounds,
      cap: cap,
      phases: [_prep(labels.go), work, _done],
      cues: src.cues,
      wodId: wodId,
      scoreType: scoreType,
      manualRoundCounter: true,
    );
  }

  static GuidedPlan _amrap(
    GuidedSource src,
    Duration? cap,
    String wodId,
    String scoreType,
    GuidedLabels labels,
  ) {
    // AMRAP : décompte sur toute la durée (= cap). Tally manuel des tours/reps.
    final work = GuidedPhase(
      kind: GuidedPhaseKind.work,
      duration: cap,
      label: labels.work,
      roundIndex: 1,
    );
    return GuidedPlan(
      format: 'amrap',
      clock: GuidedClock.countDown,
      cap: cap,
      phases: [_prep(labels.go), work, _done],
      cues: src.cues,
      wodId: wodId,
      scoreType: scoreType,
      manualRoundCounter: true,
    );
  }

  static GuidedPlan _emom(
    GuidedSource src,
    Duration? cap,
    String wodId,
    String scoreType,
    GuidedLabels labels,
  ) {
    // N phases work de 60 s, une par minute. N = rounds ?? cap/60 ?? défaut.
    final n = src.rounds ??
        (cap != null ? (cap.inSeconds / 60).round() : null) ??
        emomDefaultMinutes;
    final minutes = n < 1 ? 1 : n;
    final phases = <GuidedPhase>[_prep(labels.go)];
    for (var k = 1; k <= minutes; k++) {
      phases.add(GuidedPhase(
        kind: GuidedPhaseKind.work,
        duration: emomWindow,
        label: labels.minute(k, minutes),
        roundIndex: k,
      ));
    }
    phases.add(_done);
    return GuidedPlan(
      format: 'emom',
      clock: GuidedClock.countDown,
      totalRounds: minutes,
      phases: phases,
      cues: src.cues,
      wodId: wodId,
      scoreType: scoreType,
    );
  }

  static GuidedPlan _interval(
    GuidedSource src,
    String wodId,
    String scoreType,
    GuidedLabels labels, {
    required bool isTabata,
  }) {
    // Fenêtres work/rest depuis src.work si fourni, sinon constantes canoniques.
    Duration workDur;
    Duration restDur;
    final serverWork = src.work.where((w) => w.kind == 'work').toList();
    final serverRest = src.work.where((w) => w.kind == 'rest').toList();
    if (serverWork.isNotEmpty) {
      workDur = Duration(seconds: serverWork.first.durationSec);
      restDur = serverRest.isNotEmpty
          ? Duration(seconds: serverRest.first.durationSec)
          : (isTabata ? tabataRest : intervalRest);
    } else if (isTabata) {
      workDur = tabataWork;
      restDur = tabataRest;
    } else {
      workDur = intervalWork;
      restDur = intervalRest;
    }
    final rounds = src.rounds ??
        (isTabata ? tabataRounds : intervalDefaultRounds);
    final n = rounds < 1 ? 1 : rounds;
    final phases = <GuidedPhase>[_prep(labels.go)];
    for (var k = 1; k <= n; k++) {
      phases.add(GuidedPhase(
        kind: GuidedPhaseKind.work,
        duration: workDur,
        label: labels.workRound(k, n),
        roundIndex: k,
      ));
      // Pas de repos après le DERNIER round (on enchaîne sur `done`).
      if (k < n) {
        phases.add(GuidedPhase(
          kind: GuidedPhaseKind.rest,
          duration: restDur,
          label: labels.rest,
          roundIndex: k,
        ));
      }
    }
    phases.add(_done);
    return GuidedPlan(
      format: isTabata ? 'tabata' : 'interval',
      clock: GuidedClock.countDown,
      totalRounds: n,
      phases: phases,
      cues: src.cues,
      wodId: wodId,
      scoreType: scoreType,
    );
  }

  static GuidedPlan _strength(
    GuidedSource src,
    String wodId,
    String scoreType,
    GuidedLabels labels,
  ) {
    // Séries au count-up (l'athlète exécute ses reps) + repos chronométré entre séries.
    final sets = (src.rounds ?? strengthDefaultSets);
    final n = sets < 1 ? 1 : sets;
    final phases = <GuidedPhase>[_prep(labels.go)];
    for (var k = 1; k <= n; k++) {
      phases.add(GuidedPhase(
        kind: GuidedPhaseKind.work,
        duration: null, // série ouverte : l'athlète passe à la suite quand il a fini
        label: labels.set(k, n),
        roundIndex: k,
      ));
      if (k < n) {
        phases.add(GuidedPhase(
          kind: GuidedPhaseKind.rest,
          duration: strengthRest,
          label: labels.rest,
          roundIndex: k,
        ));
      }
    }
    phases.add(_done);
    return GuidedPlan(
      format: 'strength',
      clock: GuidedClock.countUp,
      totalRounds: n,
      phases: phases,
      cues: src.cues,
      wodId: wodId,
      scoreType: scoreType,
    );
  }
}

/// Libellés injectables (i18n). Valeurs par défaut FR pour tests + repli si l'UI n'en fournit pas.
/// L'UI passera des fonctions branchées sur `AppLocalizations`.
class GuidedLabels {
  final String work;
  final String rest;
  final String go;
  final String Function(int k, int n) minute;
  final String Function(int k, int n) workRound;
  final String Function(int k, int n) set;

  const GuidedLabels({
    this.work = 'TRAVAIL',
    this.rest = 'REPOS',
    this.go = '3 · 2 · 1 · GO',
    this.minute = _defaultMinute,
    this.workRound = _defaultWorkRound,
    this.set = _defaultSet,
  });

  static String _defaultMinute(int k, int n) => 'Minute $k / $n';
  static String _defaultWorkRound(int k, int n) => 'Tour $k / $n';
  static String _defaultSet(int k, int n) => 'Série $k / $n';
}
