import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Anneau d'Index : LE point focal. Grand chiffre central (Rajdhani tabular) + anneau gradient
/// qui se remplit (count-up easeOutExpo) + halo cyan qui respire derrière. `value` = OVR ∈ [0,100].
class IndexRing extends StatefulWidget {
  final int value;
  final double percentile;
  final double size;
  final Duration duration;
  const IndexRing({
    super.key,
    required this.value,
    required this.percentile,
    this.size = 264,
    this.duration = HiMotion.reveal,
  });

  @override
  State<IndexRing> createState() => _IndexRingState();
}

class _IndexRingState extends State<IndexRing> with SingleTickerProviderStateMixin {
  late final AnimationController _glow =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _glowStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion : on fige le halo (pas de respiration) ; sinon il pulse en boucle.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      if (_glowStarted) _glow.stop();
      _glow.value = 0.5; // halo statique, intensité médiane
      _glowStarted = false;
    } else if (!_glowStarted) {
      _glow.repeat(reverse: true);
      _glowStarted = true;
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final top = (100 - widget.percentile * 100).clamp(1, 100).round();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.value.toDouble()),
      // Reduce-motion : pas de count-up, l'Index s'affiche directement.
      duration: reduceMotion ? Duration.zero : widget.duration,
      curve: HiMotion.countUp,
      builder: (context, animated, _) {
        return AnimatedBuilder(
          animation: _glow,
          builder: (context, child) {
            final glowAlpha = 0.18 + 0.17 * _glow.value; // respiration 0.18 → 0.35
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halo radial derrière l'anneau.
                  Container(
                    width: widget.size * 1.05,
                    height: widget.size * 1.05,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: HiColors.brandPrimary.withValues(alpha: glowAlpha),
                          blurRadius: 48,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  child!,
                ],
              ),
            );
          },
          child: CustomPaint(
            painter: _RingPainter(animated / 100.0),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      animated.round().toString(),
                      style: HiType.displayXL.copyWith(
                        fontSize: widget.size * 0.34,
                        color: HiColors.textPrimary,
                      ),
                    ),
                    Text('ATHLETE INDEX', style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text('TOP $top %', style: HiType.numericM.copyWith(color: HiColors.brandPrimary, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const stroke = 14.0;
    const start = -math.pi / 2;

    final track = Paint()
      ..color = HiColors.bgElevated2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [HiColors.brandPrimaryDeep, HiColors.brandPrimary, HiColors.brandPrimaryBright],
        transform: const GradientRotation(start),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
