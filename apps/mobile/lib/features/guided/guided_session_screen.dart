// LECTEUR plein écran du « Mode guidé ». Consomme le moteur PUR (`GuidedPlan` + `GuidedRunner`)
// et n'y ajoute QUE la couche présentation : rendu, signaux (SystemSound + HiHaptics), a11y.
//
// Contrats respectés (décisions verrouillées du lot) :
//  - HORLOGE MURALE : la source de temps est le `GuidedRunner` (Stopwatch). Le `Timer.periodic(100ms)`
//    NE FAIT QU'appeler `runner.tick()` pour rafraîchir l'affichage ; jamais d'accumulation `+= 100ms`.
//  - RESYNC : au retour premier plan (`AppLifecycleState.resumed`) on rappelle `tick()` une fois pour
//    rejouer les bascules de phase manquées en arrière-plan.
//  - SIGNAUX : `SystemSound` (package:flutter/services) + `HiHaptics` UNIQUEMENT. Aucune dépendance native.
//  - COMPLÉTION AUTO : pas de bouton « marquer comme faite » ; `onCompleted` est appelé À L'ENTRÉE
//    dans la phase TERMINÉ (idempotent côté appelant).
//
// Le widget reste autonome (pas de Riverpod requis). Helpers de lancement : `.start`, `.fromWod`, `.fromCoach`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../movements/movement_guide_content.dart';
import '../movements/movement_guide_screen.dart';
import 'guided_plan.dart';
import 'guided_runner.dart';

/// Consigne d'exécution affichée dans le panneau (une ligne = un mouvement / une étape).
class GuidedCue {
  final String text;

  /// Détail secondaire (charge, tempo, note) — affiché en plus discret.
  final String? detail;
  const GuidedCue(this.text, {this.detail});
}

class GuidedSessionScreen extends StatefulWidget {
  const GuidedSessionScreen({
    super.key,
    required this.plan,
    required this.title,
    this.cues = const [],
    this.movementLabels = const [],
    this.onCompleted,
    this.onFinishAction,
    this.finishActionLabel,
  });

  /// Plan pré-calculé (issu de `GuidedPlanBuilder`).
  final GuidedPlan plan;

  /// Titre affiché en en-tête (nom du WOD / de la séance).
  final String title;

  /// Consignes à dérouler dans le panneau (mouvements/reps). Vide → panneau masqué.
  final List<GuidedCue> cues;

  /// Libellés des mouvements de la séance (ids ou noms libres), pour le guide « Comment faire ».
  /// Vide ⇒ pas de bouton guide dans l'en-tête.
  final List<String> movementLabels;

  /// Appelé UNE fois à l'entrée dans la phase TERMINÉ (crédit série / log WOD). Idempotent côté appelant.
  /// Synchrone ou asynchrone : s'il retourne un `Future`, le lecteur attend pour afficher l'état
  /// validation → succès/échec (avec bouton « réessayer »).
  ///
  /// IMPORTANT : `onCompleted` est un EFFET DE BORD silencieux (crédit). Il ne doit PAS faire de
  /// navigation : l'écran « Séance terminée » reste affiché jusqu'à une action explicite. Pour une
  /// suite EXPLICITE (ex. saisie du temps d'un WOD), utiliser [onFinishAction] / [finishActionLabel].
  final FutureOr<void> Function()? onCompleted;

  /// Action EXPLICITE proposée sur l'écran « Séance terminée » via un bouton primaire (ex. « Enregistrer
  /// mon temps » pour un WOD). Le lecteur FERME d'abord (pop) puis exécute l'action — aucune
  /// navigation automatique/temporisée. Si `null`, l'écran terminé n'affiche qu'un bouton « Fermer ».
  /// Quand [onFinishAction] est fourni, [onCompleted] n'est PAS déclenché automatiquement (l'action
  /// explicite prend le relais).
  final VoidCallback? onFinishAction;

  /// Libellé du bouton primaire de l'écran terminé (ex. « Enregistrer mon temps »). Requis si
  /// [onFinishAction] est fourni ; ignoré sinon.
  final String? finishActionLabel;

  // --------------------------------------------------------------------------
  // Helpers de lancement (route plein écran). Ne branche pas encore les points
  // d'entrée produit : ils sont exposés pour la phase d'intégration suivante.
  // --------------------------------------------------------------------------

  /// Lancement générique à partir d'un plan déjà construit.
  static Future<void> start(
    BuildContext context, {
    required GuidedPlan plan,
    required String title,
    List<GuidedCue> cues = const [],
    List<String> movementLabels = const [],
    FutureOr<void> Function()? onCompleted,
    VoidCallback? onFinishAction,
    String? finishActionLabel,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GuidedSessionScreen(
          plan: plan,
          title: title,
          cues: cues,
          movementLabels: movementLabels,
          onCompleted: onCompleted,
          onFinishAction: onFinishAction,
          finishActionLabel: finishActionLabel,
        ),
      ),
    );
  }

  /// Construit le plan depuis un `WodDetail` (bloc `guided` du serveur, sinon repli sur `type`/prescription)
  /// puis lance le lecteur format-aware. `sex`/`scaled` servent à afficher la charge des consignes.
  static Future<void> fromWod(
    BuildContext context, {
    required WodDetail wod,
    String sex = 'male',
    bool scaled = false,
    VoidCallback? onSaveResult,
  }) {
    final source = _sourceFromWod(wod);
    final labels = _labelsOf(context);
    final t = AppLocalizations.of(context);
    final plan = GuidedPlanBuilder.fromWod(
      source,
      wodId: wod.id,
      scoreType: wod.scoreType,
      labels: labels,
    );
    // Un WOD est une ÉPREUVE LOGUABLE : l'écran « Séance terminée » RESTE affiché et propose un
    // bouton EXPLICITE « Enregistrer mon temps » → on ferme le lecteur puis on ouvre la saisie de
    // résultat. Plus d'auto-navigation/auto-pop temporisée (cf. bug écran terminé qui disparaît).
    return start(
      context,
      plan: plan,
      title: wod.name,
      cues: _cuesFromWod(wod, sex: sex, scaled: scaled),
      movementLabels: _movementLabelsFromWod(wod),
      onFinishAction: onSaveResult,
      finishActionLabel: t.guidedSaveResult,
    );
  }

  /// Libellés des mouvements d'un WOD pour le guide « Comment faire » : ids exacts de `editPayload`
  /// si présents (WOD custom), sinon noms libres de la prescription (résolus par nom côté guide).
  static List<String> _movementLabelsFromWod(WodDetail wod) {
    // 1) PRIORITÉ aux identifiants canoniques exposés par le backend (movementIds du blueprint).
    //    Résolution exacte côté guide → les ids basiques supprimés sont ignorés silencieusement.
    if (wod.movementIds.isNotEmpty) return List<String>.from(wod.movementIds);

    // 2) Repli : ids d'édition (WOD custom) puis noms libres de la prescription.
    final out = <String>[];
    final payloadBlocks = wod.editPayload?.blocks;
    if (payloadBlocks != null && payloadBlocks.isNotEmpty) {
      for (final b in payloadBlocks) {
        final id = b['movementId'];
        if (id is String && id.trim().isNotEmpty) out.add(id);
      }
    }
    final p = wod.prescription;
    if (p != null) {
      for (final b in p.blocks) {
        if (b.movement.trim().isNotEmpty) out.add(b.movement);
      }
      for (final w in p.weights) {
        if (w.movement.trim().isNotEmpty) out.add(w.movement);
      }
    }
    return out;
  }

  /// Construit un plan SIMPLIFIÉ (chrono libre + consignes texte + Tour +1 manuel) pour une CoachSession.
  static Future<void> fromCoach(
    BuildContext context, {
    required CoachSession session,
    FutureOr<void> Function()? onCompleted,
  }) {
    final plan = GuidedPlanBuilder.fromCoachSession(
      sessionId: session.id,
      durationMin: session.durationMin,
      description: session.description,
      labels: _labelsOf(context),
    );
    return start(
      context,
      plan: plan,
      title: session.name,
      cues: _cuesFromText(session.description),
      onCompleted: onCompleted,
    );
  }

  // --- Mappings de données (purs) ---

  static GuidedSource _sourceFromWod(WodDetail wod) {
    final g = wod.guided;
    if (g != null) {
      return GuidedSource(
        format: g.format,
        rounds: g.rounds,
        capSec: g.capSec,
        work: g.work,
        cues: g.cues,
      );
    }
    // Repli : back ancien sans bloc `guided`. On dérive du seul `type` + cap éventuel.
    return GuidedSource.fallback(
      type: wod.type ?? wod.prescription?.format ?? 'for_time',
      capSec: wod.prescription?.timeCapSec,
    );
  }

  static List<GuidedCue> _cuesFromWod(WodDetail wod, {required String sex, required bool scaled}) {
    final blocks = wod.prescription?.blocks ?? const <WodBlock>[];
    if (blocks.isEmpty) {
      // Pas de prescription structurée : on retombe sur les cues du bloc guided (texte libre).
      return (wod.guided?.cues ?? const <String>[]).map((c) => GuidedCue(c)).toList();
    }
    final weights = wod.prescription?.weights ?? const <WodWeight>[];
    return blocks.map((b) {
      final reps = b.reps.trim();
      final text = reps.isEmpty ? b.movement : '$reps · ${b.movement}';
      final w = weights.where((x) => x.movement == b.movement).cast<WodWeight?>().firstWhere((_) => true, orElse: () => null);
      String? detail = b.detail;
      if (w != null) {
        final load = scaled ? w.scaled(sex) : w.rx(sex);
        if (load > 0) {
          final loadStr = '${load % 1 == 0 ? load.toInt() : load} ${w.unit}';
          detail = detail == null ? loadStr : '$detail · $loadStr';
        }
      }
      return GuidedCue(text, detail: detail);
    }).toList();
  }

  static List<GuidedCue> _cuesFromText(String description) {
    return description
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => GuidedCue(l))
        .toList();
  }

  /// Branche l'i18n FR/EN sur les libellés dynamiques du builder (Minute/Tour/Série).
  static GuidedLabels _labelsOf(BuildContext context) {
    final t = AppLocalizations.of(context);
    return GuidedLabels(
      work: t.guidedPhaseWork.toUpperCase(),
      rest: t.guidedPhaseRest.toUpperCase(),
      go: t.guidedGo,
      minute: (k, n) => t.guidedMinuteOf(k, n),
      workRound: (k, n) => t.guidedRoundOf(k, n),
      set: (k, n) => t.guidedSetOf(k, n),
    );
  }

  @override
  State<GuidedSessionScreen> createState() => _GuidedSessionScreenState();
}

class _GuidedSessionScreenState extends State<GuidedSessionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final GuidedRunner _runner;

  // Rafraîchissement de l'affichage. UN Ticker (pas un Timer.periodic) : il bat à chaque frame,
  // est muté/disposé proprement par le binding (y compris en test), et NE MESURE rien — il se
  // contente d'appeler `runner.tick()` qui lit l'horloge murale du moteur.
  late final Ticker _ticker;

  // Toggle son (le son est par défaut ON ; l'haptique reste toujours active).
  bool _soundOn = true;

  // Flash de couleur de phase (coupé en reduce-motion). Couleur courante + opacité animée.
  Color? _flashColor;
  double _flashOpacity = 0;
  Timer? _flashTimer;

  // Overlay 3-2-1 GO : chiffre courant (ou 0 = « GO »), null = pas d'overlay.
  int? _countdownDigit;
  // Maintient « GO » affiché brièvement à l'entrée du travail, puis retire l'overlay.
  Timer? _goTimer;

  // État de complétion (auto, best-effort). idle au départ → saving → ok / failed.
  _Credit _credit = _Credit.idle;
  bool _completionFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runner = GuidedRunner(widget.plan, onEvent: _onEvent)..addListener(_onRunnerChange);
    _ticker = createTicker((_) {
      if (mounted && _runner.isRunning) _runner.tick();
    })
      ..start();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _goTimer?.cancel();
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _runner.removeListener(_onRunnerChange);
    _runner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resync horloge murale : on rejoue les bascules manquées en arrière-plan.
    if (state == AppLifecycleState.resumed && _runner.isRunning) _runner.tick();
  }

  void _onRunnerChange() {
    if (!mounted) return;
    // Complétion AUTO (effet de bord silencieux, ex. crédit de série coach) : à l'entrée dans
    // TERMINÉ, on déclenche `onCompleted` une seule fois. MAIS si une action de fin EXPLICITE est
    // fournie (`onFinishAction`, ex. « Enregistrer mon temps » d'un WOD), on n'auto-déclenche RIEN :
    // l'écran « Séance terminée » reste affiché jusqu'à l'action de l'utilisateur.
    if (_runner.isFinished && !_completionFired && widget.onFinishAction == null) {
      _completionFired = true;
      _fireCompletion();
    }
    setState(() {});
  }

  // --- Signaux (SystemSound + HiHaptics) ---

  void _sound(SystemSoundType type) {
    if (_soundOn) SystemSound.play(type);
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Vrai si au moins un mouvement de la séance a une fiche « Comment faire » (sinon pas de bouton).
  bool get _hasMovementGuide => resolveMovementGuides(widget.movementLabels).isNotEmpty;

  /// Ouvre le guide des mouvements de la séance en cours (consignes/exécution).
  void _openMovementGuide() {
    MovementGuideScreen.open(context, labels: widget.movementLabels, title: widget.title);
  }

  void _onEvent(GuidedEvent e) {
    if (!mounted) return;
    switch (e.type) {
      case GuidedEventType.prepTick:
        final n = e.secondsLeft ?? 0;
        _sound(SystemSoundType.click);
        HiHaptics.tap();
        setState(() => _countdownDigit = n);
        break;
      case GuidedEventType.workStart:
        _sound(SystemSoundType.alert);
        HiHaptics.impact();
        _flash(HiColors.success);
        // Si on arrivait du décompte de prep, on affiche brièvement « GO » (digit 0) puis on
        // retire l'overlay — une seule séquence 3·2·1·GO, pas de chrono fantôme.
        if (_countdownDigit != null) {
          setState(() => _countdownDigit = 0);
          _goTimer?.cancel();
          _goTimer = Timer(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _countdownDigit = null);
          });
        } else {
          setState(() => _countdownDigit = null);
        }
        break;
      case GuidedEventType.restStart:
        _sound(SystemSoundType.click);
        HiHaptics.success();
        _flash(HiColors.warn);
        break;
      case GuidedEventType.windowBoundary:
        _sound(SystemSoundType.click);
        HiHaptics.tap();
        break;
      case GuidedEventType.completed:
        _sound(SystemSoundType.alert);
        HiHaptics.celebrate();
        break;
    }
  }

  void _flash(Color color) {
    if (_reduceMotion) return;
    setState(() {
      _flashColor = color;
      _flashOpacity = 0.42;
    });
    // Retombée douce. Timer GÉRÉ (annulé en dispose) pour ne pas laisser de timer pendant.
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _flashOpacity = 0);
    });
  }

  Future<void> _fireCompletion() async {
    if (widget.onCompleted == null) return;
    setState(() => _credit = _Credit.saving);
    try {
      // onCompleted peut être synchrone (void) ou asynchrone (Future) ; on attend si nécessaire.
      final result = widget.onCompleted!();
      if (result is Future) await result;
      if (mounted) setState(() => _credit = _Credit.ok);
    } catch (_) {
      if (mounted) setState(() => _credit = _Credit.failed);
    }
  }

  // --- Contrôles ---

  void _onAddRound() {
    HiHaptics.tap();
    _runner.bumpRound();
  }

  /// Action de fin EXPLICITE (ex. « Enregistrer mon temps ») : on FERME d'abord le lecteur, puis on
  /// exécute l'action de l'appelant (qui ouvre la suite, ex. saisie de résultat). Aucun timer.
  void _onFinishAction() {
    final action = widget.onFinishAction;
    if (action == null) return;
    HiHaptics.impact();
    Navigator.of(context).pop();
    action();
  }

  Future<bool> _confirmQuit() async {
    if (_runner.isFinished || !_runner.isRunning && _runner.phaseIndex == 0) return true;
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(t.guidedQuitTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        content: Text(t.guidedQuitBody, style: HiType.body.copyWith(color: HiColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.guidedQuitCancel, style: HiType.button.copyWith(color: HiColors.brandPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.guidedQuitConfirm, style: HiType.button.copyWith(color: HiColors.error)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // --------------------------------------------------------------------------
  // Rendu
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final phase = _runner.currentPhase;
    final finished = _runner.isFinished;
    final started = _runner.phaseIndex > 0 || _runner.isRunning || _runner.isPaused;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quit = await _confirmQuit();
        if (quit && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: HiColors.bgBase,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: HiSpace.gutter),
                child: Column(
                  children: [
                    _Header(
                      title: widget.title,
                      soundOn: _soundOn,
                      onToggleSound: () {
                        HiHaptics.tap();
                        setState(() => _soundOn = !_soundOn);
                      },
                      onClose: () async {
                        final quit = await _confirmQuit();
                        if (quit && context.mounted) Navigator.of(context).pop();
                      },
                      onShowGuide: _hasMovementGuide ? _openMovementGuide : null,
                    ),
                    const SizedBox(height: HiSpace.sm),
                    _SessionProgressBar(
                      value: _sessionProgress(),
                      reduceMotion: _reduceMotion,
                    ),
                    Expanded(
                      child: finished
                          ? _FinishedView(
                              runner: _runner,
                              credit: _credit,
                              reduceMotion: _reduceMotion,
                              onRetry: () {
                                _completionFired = false;
                                _fireCompletion();
                              },
                            )
                          : _RunningView(
                              runner: _runner,
                              phase: phase,
                              cues: widget.cues,
                              reduceMotion: _reduceMotion,
                            ),
                    ),
                    _Controls(
                      runner: _runner,
                      started: started,
                      finished: finished,
                      onStart: _runner.start,
                      onPause: () {
                        HiHaptics.tap();
                        _runner.pause();
                      },
                      onResume: () {
                        HiHaptics.tap();
                        _runner.resume();
                      },
                      onSkip: () {
                        HiHaptics.tap();
                        _runner.skip();
                      },
                      onAddRound: _onAddRound,
                      onFinish: () {
                        HiHaptics.impact();
                        // « Terminer » = aller jusqu'à la phase TERMINÉ quel que soit le format.
                        // skip() avance d'une phase et déclenche _finish() en atteignant `done`.
                        var guard = 0;
                        while (!_runner.isFinished && guard++ < _runner.plan.phases.length + 1) {
                          _runner.skip();
                        }
                      },
                      onDone: () => Navigator.of(context).pop(),
                      onFinishAction: widget.onFinishAction == null ? null : _onFinishAction,
                      finishActionLabel: widget.finishActionLabel,
                      labelStart: t.guidedStart,
                      labelPause: t.guidedPause,
                      labelResume: t.guidedResume,
                      labelSkip: t.guidedSkip,
                      labelFinish: t.guidedFinish,
                      labelAddRound: t.guidedAddRound,
                      labelSetDone: t.guidedSetDone,
                      labelDone: t.guidedClose,
                    ),
                    const SizedBox(height: HiSpace.md),
                  ],
                ),
              ),
            ),
            // Flash de couleur de phase (par-dessus, non interactif).
            if (_flashColor != null)
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: _reduceMotion ? Duration.zero : HiMotion.instant,
                  opacity: _flashOpacity,
                  child: Container(color: _flashColor),
                ),
              ),
            // Overlay 3-2-1 GO.
            if (_countdownDigit != null)
              _CountdownOverlay(digit: _countdownDigit!, reduceMotion: _reduceMotion),
          ],
        ),
      ),
    );
  }

  double _sessionProgress() {
    final phases = widget.plan.phases;
    final total = phases.length <= 1 ? 1 : phases.length - 1; // hors prep idéalement, approximation
    final idx = _runner.phaseIndex.clamp(0, total);
    if (_runner.isFinished) return 1;
    return (idx / total).clamp(0.0, 1.0);
  }
}

enum _Credit { idle, saving, ok, failed }

// ============================================================================
// EN-TÊTE
// ============================================================================

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.soundOn,
    required this.onToggleSound,
    required this.onClose,
    this.onShowGuide,
  });

  final String title;
  final bool soundOn;
  final VoidCallback onToggleSound;
  final VoidCallback onClose;

  /// Ouvre le guide « Comment faire les mouvements ». Null ⇒ bouton masqué.
  final VoidCallback? onShowGuide;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        Semantics(
          button: true,
          label: t.guidedClose,
          child: IconButton(
            iconSize: 26,
            constraints: const BoxConstraints(minWidth: HiTap.minTarget, minHeight: HiTap.minTarget),
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: HiColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HiType.titleM.copyWith(color: HiColors.textPrimary),
          ),
        ),
        if (onShowGuide != null)
          Semantics(
            button: true,
            label: t.movementGuideButton,
            child: IconButton(
              iconSize: 24,
              constraints: const BoxConstraints(minWidth: HiTap.minTarget, minHeight: HiTap.minTarget),
              onPressed: onShowGuide,
              icon: Icon(Icons.menu_book_outlined, color: HiColors.textSecondary),
            ),
          ),
        Semantics(
          button: true,
          label: soundOn ? t.guidedSoundOn : t.guidedSoundOff,
          child: IconButton(
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: HiTap.minTarget, minHeight: HiTap.minTarget),
            onPressed: onToggleSound,
            icon: Icon(
              soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: soundOn ? HiColors.brandPrimary : HiColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// VUE EN COURS (phase + chrono + compteur + consignes)
// ============================================================================

class _RunningView extends StatelessWidget {
  const _RunningView({
    required this.runner,
    required this.phase,
    required this.cues,
    required this.reduceMotion,
  });

  final GuidedRunner runner;
  final GuidedPhase phase;
  final List<GuidedCue> cues;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: HiSpace.lg),
        _PhaseBanner(phase: phase, reduceMotion: reduceMotion),
        const SizedBox(height: HiSpace.lg),
        Expanded(
          child: Center(
            child: _Chrono(runner: runner, phase: phase),
          ),
        ),
        _Counter(runner: runner, phase: phase),
        const SizedBox(height: HiSpace.md),
        // Le panneau de consignes reste visible dès le départ (y compris pendant la prep) pour
        // prévisualiser les mouvements ; il ne disparaît qu'en l'absence de consigne.
        if (cues.isNotEmpty)
          Expanded(
            child: _CuesPanel(cues: cues, runner: runner),
          ),
      ],
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.phase, required this.reduceMotion});
  final GuidedPhase phase;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Color? color;
    String? text;
    String? a11y;
    switch (phase.kind) {
      case GuidedPhaseKind.work:
        color = HiColors.success;
        text = t.guidedPhaseWork.toUpperCase();
        a11y = t.a11yGuidedPhaseWork;
        break;
      case GuidedPhaseKind.rest:
        color = HiColors.warn;
        text = t.guidedPhaseRest.toUpperCase();
        a11y = t.a11yGuidedPhaseRest;
        break;
      case GuidedPhaseKind.prep:
        color = HiColors.brandPrimary;
        text = t.guidedPhasePrepare.toUpperCase();
        a11y = t.a11yGuidedPhasePrepare;
        break;
      case GuidedPhaseKind.roundBreak:
      case GuidedPhaseKind.done:
        // Pas de bandeau (for_time/amrap n'ont pas de phase d'effort nommée à montrer).
        return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      label: a11y,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : HiMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg, vertical: HiSpace.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(HiRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Text(text, style: HiType.overline.copyWith(color: color, fontSize: 14)),
      ),
    );
  }
}

class _Chrono extends StatelessWidget {
  const _Chrono({required this.runner, required this.phase});
  final GuidedRunner runner;
  final GuidedPhase phase;

  static String fmt(Duration d) {
    final neg = d.isNegative;
    final s = d.abs();
    final m = s.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = s.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = s.inHours;
    final base = h > 0 ? '$h:$m:$sec' : '$m:$sec';
    return neg ? '-$base' : base;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isPrep = phase.kind == GuidedPhaseKind.prep;
    // Pendant la PRÉPA, le chrono principal reste figé à 0 (l'overlay 3·2·1·GO assure le décompte).
    // Il « démarre » réellement à GO, à l'entrée de la première phase de travail — jamais de chrono
    // qui tourne pendant la prep puis se remet à zéro.
    final d = isPrep ? Duration.zero : runner.displayTime;
    final text = fmt(d);

    // Avertissement « 3 dernières secondes » d'une phase à rebours : couleur warn.
    final remaining = runner.remainingInPhase;
    final warning = remaining != null && remaining.inSeconds <= 3 && !isPrep;
    final color = warning ? HiColors.warn : HiColors.textPrimary;

    return Semantics(
      liveRegion: false,
      label: t.a11yGuidedTimeValue(text),
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: HiType.displayXL.copyWith(color: color)),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.runner, required this.phase});
  final GuidedRunner runner;
  final GuidedPhase phase;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final plan = runner.plan;
    String? text;
    String? a11y;

    if (plan.showManualRoundCounter) {
      // for_time multi-tours / amrap : compteur de tours manuel (masqué si un seul tour).
      final n = runner.manualRounds;
      if (plan.totalRounds != null && plan.totalRounds! > 0) {
        text = t.guidedRoundOf(n.clamp(0, plan.totalRounds!), plan.totalRounds!);
      } else {
        text = t.guidedRoundsDone(n);
      }
      a11y = t.a11yGuidedRound(n);
    } else if (!plan.manualRoundCounter && phase.roundIndex != null) {
      final k = phase.roundIndex!;
      final n = plan.totalRounds ?? plan.workPhaseCount;
      switch (plan.format) {
        case 'emom':
          text = t.guidedMinuteOf(k, n);
          a11y = t.a11yGuidedMinute(k);
          break;
        case 'strength':
          text = t.guidedSetOf(k, n);
          a11y = t.a11yGuidedSet(k);
          break;
        default:
          text = t.guidedRoundOf(k, n);
          a11y = t.a11yGuidedRound(k);
      }
    }

    if (text == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: a11y,
      child: Text(text, style: HiType.numericM.copyWith(color: HiColors.textSecondary)),
    );
  }
}

class _CuesPanel extends StatelessWidget {
  const _CuesPanel({required this.cues, required this.runner});
  final List<GuidedCue> cues;
  final GuidedRunner runner;

  @override
  Widget build(BuildContext context) {
    // Surlignage : pour les formats à phases (interval/tabata/emom/strength) on surligne la ligne
    // qui correspond au tour courant ; pour for_time/amrap, on déroule simplement la liste.
    final highlight = runner.plan.manualRoundCounter ? -1 : ((runner.currentPhase.roundIndex ?? 1) - 1);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: HiSpace.sm),
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.lg),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: cues.length,
        separatorBuilder: (_, __) => const SizedBox(height: HiSpace.sm),
        itemBuilder: (_, i) {
          final c = cues[i];
          final on = i == highlight;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 7, right: HiSpace.sm),
                decoration: BoxDecoration(
                  color: on ? HiColors.brandPrimary : HiColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.text,
                      style: (on ? HiType.bodyStrong : HiType.body).copyWith(
                        color: on ? HiColors.textPrimary : HiColors.textSecondary,
                      ),
                    ),
                    if (c.detail != null && c.detail!.isNotEmpty)
                      Text(c.detail!, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// VUE TERMINÉ (célébration + complétion auto)
// ============================================================================

class _FinishedView extends StatelessWidget {
  const _FinishedView({
    required this.runner,
    required this.credit,
    required this.reduceMotion,
    required this.onRetry,
  });

  final GuidedRunner runner;
  final _Credit credit;
  final bool reduceMotion;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final total = _Chrono.fmt(runner.totalElapsed);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(HiSpace.lg),
            decoration: BoxDecoration(
              color: HiColors.accentVictory.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              boxShadow: reduceMotion ? null : HiShadow.glowVictory(0.5),
            ),
            child: Icon(Icons.check_rounded, size: 56, color: HiColors.accentVictory),
          ),
          const SizedBox(height: HiSpace.lg),
          Text(t.guidedDone, style: HiType.titleL.copyWith(color: HiColors.accentVictory)),
          const SizedBox(height: HiSpace.sm),
          Text(
            t.guidedTotalTime(total),
            style: HiType.numericL.copyWith(color: HiColors.textPrimary),
          ),
          const SizedBox(height: HiSpace.lg),
          _CreditChip(credit: credit, onRetry: onRetry, t: t),
        ],
      ),
    );
  }
}

class _CreditChip extends StatelessWidget {
  const _CreditChip({required this.credit, required this.onRetry, required this.t});
  final _Credit credit;
  final VoidCallback onRetry;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    switch (credit) {
      case _Credit.idle:
        return const SizedBox.shrink();
      case _Credit.saving:
        return Text(t.guidedValidating, style: HiType.label.copyWith(color: HiColors.textTertiary));
      case _Credit.ok:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: HiSpace.sm),
          decoration: BoxDecoration(
            color: HiColors.success.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(HiRadius.pill),
          ),
          child: Text(t.guidedStreakCredited, style: HiType.label.copyWith(color: HiColors.success)),
        );
      case _Credit.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(t.guidedCreditFailed, style: HiType.label.copyWith(color: HiColors.warn))),
            const SizedBox(width: HiSpace.sm),
            TextButton(
              onPressed: onRetry,
              child: Text(t.guidedRetry, style: HiType.button.copyWith(color: HiColors.brandPrimary)),
            ),
          ],
        );
    }
  }
}

// ============================================================================
// CONTRÔLES
// ============================================================================

class _Controls extends StatelessWidget {
  const _Controls({
    required this.runner,
    required this.started,
    required this.finished,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSkip,
    required this.onAddRound,
    required this.onFinish,
    required this.onDone,
    required this.onFinishAction,
    required this.finishActionLabel,
    required this.labelStart,
    required this.labelPause,
    required this.labelResume,
    required this.labelSkip,
    required this.labelFinish,
    required this.labelAddRound,
    required this.labelSetDone,
    required this.labelDone,
  });

  final GuidedRunner runner;
  final bool started;
  final bool finished;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onAddRound;
  final VoidCallback onFinish;
  final VoidCallback onDone;
  /// Action de fin EXPLICITE (ex. enregistrer le temps). Null = pas de bouton primaire dédié.
  final VoidCallback? onFinishAction;
  final String? finishActionLabel;
  final String labelStart;
  final String labelPause;
  final String labelResume;
  final String labelSkip;
  final String labelFinish;
  final String labelAddRound;
  final String labelSetDone;
  final String labelDone;

  @override
  Widget build(BuildContext context) {
    if (finished) {
      // Écran « Séance terminée » : RESTE affiché jusqu'à une action explicite.
      // - WOD (action de fin fournie) : bouton primaire « Enregistrer mon temps » + « Fermer ».
      // - Sinon (séance coach) : un seul bouton « Fermer ».
      final action = onFinishAction;
      if (action != null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              width: double.infinity,
              child: HiButton(
                label: finishActionLabel ?? labelDone,
                icon: Icons.timer_outlined,
                onPressed: action,
              ),
            ),
            const SizedBox(height: HiSpace.sm),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: HiButtonSecondary(label: labelDone, onPressed: onDone),
            ),
          ],
        );
      }
      return SizedBox(
        height: 64,
        width: double.infinity,
        child: HiButton(label: labelDone, onPressed: onDone),
      );
    }
    if (!started) {
      return SizedBox(
        height: 64,
        width: double.infinity,
        child: HiButton(label: labelStart, icon: Icons.play_arrow_rounded, onPressed: onStart),
      );
    }

    final plan = runner.plan;
    final paused = runner.isPaused;
    // Bouton central OPTIONNEL : Tour +1 (for_time multi-tours / amrap) · Série faite (strength) ·
    // Skip (emom/interval/tabata). Pour une séance à UN SEUL tour (for_time simple, séance coach
    // « free »), aucun bouton central : on n'affiche pas de « Tour +1 » parasite (cf. bug compteur).
    Widget? middle;
    if (plan.manualRoundCounter) {
      if (plan.showManualRoundCounter) {
        middle = HiButtonSecondary(label: labelAddRound, icon: Icons.add_rounded, onPressed: onAddRound);
      }
    } else if (plan.format == 'strength') {
      middle = HiButtonSecondary(label: labelSetDone, icon: Icons.check_rounded, onPressed: onSkip);
    } else {
      middle = HiButtonSecondary(label: labelSkip, icon: Icons.skip_next_rounded, onPressed: onSkip);
    }

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: paused
                ? HiButton(label: labelResume, icon: Icons.play_arrow_rounded, onPressed: onResume)
                : HiButtonSecondary(label: labelPause, icon: Icons.pause_rounded, onPressed: onPause),
          ),
          const SizedBox(width: HiSpace.sm),
          if (middle != null) ...[
            Expanded(child: middle),
            const SizedBox(width: HiSpace.sm),
          ],
          Expanded(
            child: HiButtonSecondary(label: labelFinish, icon: Icons.flag_rounded, onPressed: onFinish),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BARRE DE PROGRESSION SÉANCE
// ============================================================================

class _SessionProgressBar extends StatelessWidget {
  const _SessionProgressBar({required this.value, required this.reduceMotion});
  final double value;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: LayoutBuilder(
        builder: (_, c) {
          final w = (c.maxWidth * value).clamp(0.0, c.maxWidth);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: HiColors.strokeSubtle,
                  borderRadius: BorderRadius.circular(HiRadius.pill),
                ),
              ),
              AnimatedContainer(
                duration: reduceMotion ? Duration.zero : HiMotion.fast,
                width: w,
                decoration: BoxDecoration(
                  gradient: HiColors.brandGradient,
                  borderRadius: BorderRadius.circular(HiRadius.pill),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// OVERLAY 3-2-1 GO
// ============================================================================

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.digit, required this.reduceMotion});
  final int digit;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isGo = digit <= 0;
    final label = isGo ? t.guidedCountdownGo : '$digit';
    final color = isGo ? HiColors.accentVictory : HiColors.textPrimary;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: HiColors.bgBase.withValues(alpha: 0.86),
          alignment: Alignment.center,
          child: Semantics(
            liveRegion: true,
            label: isGo ? t.guidedCountdownGo : t.a11yGuidedCountdown(digit),
            child: Text(
              label,
              style: HiType.displayXL.copyWith(
                color: color,
                fontSize: isGo ? 120 : 180,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
