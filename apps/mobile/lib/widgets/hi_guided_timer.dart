import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'hi_button.dart';

/// `HiGuidedTimer` — chrono plein écran du « Mode guidé » (design-system §2.12 / §6.4).
///
/// Point focal : un grand chrono mono (Rajdhani, figures tabulaires) qui sert de repère
/// pendant l'effort. Deux modes :
///  - **compte à rebours** si une [durationMin] cible est fournie (la séance a une durée) —
///    le chrono descend de la cible vers 0 puis déclenche [onFinished] ;
///  - **chrono libre** sinon — le temps écoulé monte sans limite ; l'athlète termine à la main.
///
/// API volontairement minimale et réutilisable : [title], [durationMin] optionnelle, [onFinished].
/// Respecte reduce-motion (pas de pulsation du halo si désactivé) et les cibles tactiles
/// d'effort (boutons ≥ 64 dp, plus grands que le minimum a11y de 48 dp).
class HiGuidedTimer extends StatefulWidget {
  const HiGuidedTimer({
    super.key,
    required this.title,
    this.durationMin,
    this.onFinished,
  });

  /// Titre de la séance / du benchmark affiché sous le chrono (ex. « Benchmark Zéro »).
  final String title;

  /// Durée cible en minutes. Si fournie (> 0) → compte à rebours ; sinon → chrono libre.
  final int? durationMin;

  /// Appelé quand la séance est terminée (cible atteinte ou « Terminer »).
  /// Reçoit le temps réellement écoulé.
  final ValueChanged<Duration>? onFinished;

  /// Ouvre le chrono guidé en plein écran (route opaque). Renvoie le temps écoulé,
  /// ou `null` si l'athlète a quitté sans terminer.
  static Future<Duration?> push(
    BuildContext context, {
    required String title,
    int? durationMin,
  }) {
    return Navigator.of(context).push<Duration>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => HiGuidedTimer(
          title: title,
          durationMin: durationMin,
          onFinished: (elapsed) => Navigator.of(context).pop(elapsed),
        ),
      ),
    );
  }

  @override
  State<HiGuidedTimer> createState() => _HiGuidedTimerState();
}

enum _TimerPhase { ready, running, paused, finished }

class _HiGuidedTimerState extends State<HiGuidedTimer>
    with SingleTickerProviderStateMixin {
  static const _tick = Duration(milliseconds: 100);

  late final AnimationController _pulse;
  Timer? _timer;
  _TimerPhase _phase = _TimerPhase.ready;

  /// Temps écoulé depuis le démarrage (toujours croissant, quel que soit le mode).
  Duration _elapsed = Duration.zero;

  Duration? get _target =>
      (widget.durationMin != null && widget.durationMin! > 0)
          ? Duration(minutes: widget.durationMin!)
          : null;

  bool get _isCountdown => _target != null;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  /// Halo qui « respire » uniquement en course et hors reduce-motion ; figé sinon.
  void _syncPulse() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_phase == _TimerPhase.running && !reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0.5; // halo statique, intensité médiane
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() => _phase = _TimerPhase.running);
    _syncPulse();
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      setState(() => _elapsed += _tick);
      final target = _target;
      if (target != null && _elapsed >= target) {
        _elapsed = target;
        _finish();
      }
    });
  }

  void _pause() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() => _phase = _TimerPhase.paused);
    _syncPulse();
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _phase = _TimerPhase.ready;
      _elapsed = Duration.zero;
    });
    _syncPulse();
  }

  void _finish() {
    _timer?.cancel();
    final elapsed = _elapsed;
    HapticFeedback.heavyImpact();
    setState(() => _phase = _TimerPhase.finished);
    _syncPulse();
    widget.onFinished?.call(elapsed);
  }

  /// Valeur affichée : compte à rebours (cible − écoulé) ou temps écoulé.
  Duration get _display {
    final target = _target;
    if (target != null) {
      final remaining = target - _elapsed;
      return remaining.isNegative ? Duration.zero : remaining;
    }
    return _elapsed;
  }

  /// Progression [0..1] : remplissage de la barre. En chrono libre on n'a pas de cible →
  /// la barre reste pleine (repère présent mais non quantifié).
  double get _progress {
    final target = _target;
    if (target == null || target.inMilliseconds == 0) return 1;
    return (_elapsed.inMilliseconds / target.inMilliseconds).clamp(0.0, 1.0);
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final running = _phase == _TimerPhase.running;
    final finished = _phase == _TimerPhase.finished;

    return Scaffold(
      backgroundColor: HiColors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HiSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête : fermer + libellé de mode.
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: t.guidedTimerClose,
                    child: IconButton(
                      iconSize: 28,
                      color: HiColors.textSecondary,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isCountdown
                        ? t.guidedTimerCountdownLabel
                        : t.guidedTimerStopwatchLabel,
                    style: HiType.overline.copyWith(color: HiColors.textTertiary),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const Spacer(flex: 2),

              // Chrono géant — point focal, halo respirant (sauf reduce-motion).
              Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final glowAlpha = running && !reduceMotion
                        ? 0.18 + 0.22 * _pulse.value
                        : 0.22;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HiSpace.xl,
                        vertical: HiSpace.lg,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(HiRadius.xl),
                        boxShadow: HiShadow.glowBrand(glowAlpha),
                      ),
                      child: child,
                    );
                  },
                  child: Semantics(
                    label: t.a11yGuidedTimerValue(_fmt(_display)),
                    child: ExcludeSemantics(
                      child: Text(
                        _fmt(_display),
                        style: HiType.displayXL.copyWith(
                          fontSize: 96,
                          color: finished
                              ? HiColors.accentVictory
                              : HiColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: HiSpace.md),

              // Titre de la séance / benchmark.
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: HiType.titleM.copyWith(color: HiColors.textSecondary),
              ),
              const SizedBox(height: HiSpace.lg),

              // Barre de progression (grammaire HiMotion, pas de LinearProgressIndicator brut).
              _ProgressBar(value: _progress, reduceMotion: reduceMotion),

              const Spacer(flex: 3),

              // Contrôles.
              _buildControls(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(AppLocalizations t) {
    switch (_phase) {
      case _TimerPhase.ready:
        return HiButton(
          label: t.guidedTimerStart,
          icon: Icons.play_arrow_rounded,
          onPressed: _start,
        );
      case _TimerPhase.running:
        return Row(
          children: [
            Expanded(
              child: HiButtonSecondary(
                label: t.guidedTimerPause,
                icon: Icons.pause_rounded,
                onPressed: _pause,
              ),
            ),
            const SizedBox(width: HiSpace.md),
            Expanded(
              child: HiButton(
                label: t.guidedTimerFinish,
                icon: Icons.flag_rounded,
                onPressed: _finish,
              ),
            ),
          ],
        );
      case _TimerPhase.paused:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HiButton(
              label: t.guidedTimerResume,
              icon: Icons.play_arrow_rounded,
              onPressed: _start,
            ),
            const SizedBox(height: HiSpace.sm),
            Row(
              children: [
                Expanded(
                  child: HiGhostButton(
                    label: t.guidedTimerReset,
                    icon: Icons.replay_rounded,
                    onPressed: _reset,
                  ),
                ),
                const SizedBox(width: HiSpace.md),
                Expanded(
                  child: HiButtonSecondary(
                    label: t.guidedTimerFinish,
                    icon: Icons.flag_rounded,
                    onPressed: _finish,
                  ),
                ),
              ],
            ),
          ],
        );
      case _TimerPhase.finished:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.guidedTimerDone,
              textAlign: TextAlign.center,
              style: HiType.titleL.copyWith(color: HiColors.accentVictory),
            ),
            const SizedBox(height: HiSpace.md),
            HiGhostButton(
              label: t.guidedTimerReset,
              icon: Icons.replay_rounded,
              onPressed: _reset,
            ),
          ],
        );
    }
  }
}

/// Barre de progression maison (pas de LinearProgressIndicator Material) : piste arrondie +
/// remplissage dégradé marque, animée selon la grammaire HiMotion (figée en reduce-motion).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.reduceMotion});

  final double value;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(HiRadius.pill),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Container(color: HiColors.bgElevated2),
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth * value).clamp(0.0, c.maxWidth);
                final bar = Container(
                  width: w,
                  decoration: BoxDecoration(
                    gradient: HiColors.brandGradient,
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                  ),
                );
                if (reduceMotion) return bar;
                return AnimatedContainer(
                  duration: HiMotion.base,
                  curve: HiMotion.enter,
                  width: w,
                  decoration: BoxDecoration(
                    gradient: HiColors.brandGradient,
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
