import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Anneau d'Index : grand chiffre central + anneau de progression gradient qui se remplit
/// (animation du reveal). `value` ∈ [0, 1000].
class IndexRing extends StatelessWidget {
  final int value;
  final double percentile;
  final double size;
  final Duration duration;
  const IndexRing({
    super.key,
    required this.value,
    required this.percentile,
    this.size = 240,
    this.duration = const Duration(milliseconds: 1600),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(animated / 1000.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    animated.round().toString(),
                    style: TextStyle(
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w800,
                      color: HiColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('HYBRID INDEX',
                      style: TextStyle(color: HiColors.textSecondary, fontSize: 11, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text(
                    'Top ${(100 - percentile * 100).clamp(0, 100).toStringAsFixed(0)} %',
                    style: TextStyle(color: HiColors.brandPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
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
    final radius = size.width / 2 - 8;
    const stroke = 12.0;
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
        colors: [HiColors.brandPrimary, HiColors.brandSecondary, HiColors.brandPrimary],
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
