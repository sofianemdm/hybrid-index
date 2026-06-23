import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/haptics.dart';
import '../theme/tokens.dart';

/// Radar des 6 attributs — peinture custom animée (le polygone se dessine en grandissant depuis
/// le centre, sommets à glow colorés par attribut). Liste lisible dessous (a11y + valeurs + tap).
/// `onTapAttribute` : tap sur un axe (radar ou ligne) → séances pour booster cette qualité.
class RadarView extends StatefulWidget {
  final List<RadarAttribute> radar;
  final void Function(String attribute)? onTapAttribute;
  const RadarView({super.key, required this.radar, this.onTapAttribute});

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: HiMotion.celebrate)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Tap sur le radar → axe le plus proche (par l'angle) → onTapAttribute.
  void _onTapUp(TapUpDetails d, Size size) {
    final cb = widget.onTapAttribute;
    if (cb == null) return;
    final center = Offset(size.width / 2, size.height / 2);
    final v = d.localPosition - center;
    if (v.distance < 12) return;
    final angle = math.atan2(v.dy, v.dx);
    var idx = ((angle + math.pi / 2) / (2 * math.pi / widget.radar.length)).round() % widget.radar.length;
    if (idx < 0) idx += widget.radar.length;
    HiHaptics.tap();
    cb(widget.radar[idx].attribute);
  }

  @override
  Widget build(BuildContext context) {
    final labelBase = Theme.of(context).textTheme.bodySmall;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, 260);
            return GestureDetector(
              onTapUp: widget.onTapAttribute == null ? null : (d) => _onTapUp(d, size),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  size: size,
                  painter: _RadarPainter(widget.radar, Curves.easeOutCubic.transform(_c.value), labelBase),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: HiSpace.md),
        ...widget.radar.map(_attrRow),
      ],
    );
  }

  Widget _attrRow(RadarAttribute a) {
    final color = a.unlocked ? HiColors.attribute(a.attribute) : HiColors.attrLocked;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(a.unlocked ? Icons.circle : Icons.lock, size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(HiLabels.attribute(a.attribute), style: HiType.body.copyWith(color: HiColors.textSecondary))),
          if (a.isStale && a.unlocked)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.update_rounded, size: 14, color: HiColors.warn),
            ),
          if (a.isEstimated)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('estimé', style: HiType.caption.copyWith(color: HiColors.warn)),
            ),
          Text(a.unlocked ? '${a.score}' : '—', style: HiType.numericM.copyWith(color: HiColors.textPrimary, fontSize: 16)),
          if (widget.onTapAttribute != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: HiColors.textTertiary),
          ],
        ],
      ),
    );
    if (widget.onTapAttribute == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(HiRadius.sm),
      onTap: () {
        HiHaptics.tap();
        widget.onTapAttribute!(a.attribute);
      },
      child: row,
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<RadarAttribute> radar;
  final double t; // 0..1 progression du dessin
  final TextStyle? baseLabel;
  _RadarPainter(this.radar, this.t, this.baseLabel);

  @override
  void paint(Canvas canvas, Size size) {
    final n = radar.length;
    if (n == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 38;
    Offset dir(int i, double r) {
      final a = -math.pi / 2 + i * (2 * math.pi / n);
      return center + Offset(math.cos(a), math.sin(a)) * r;
    }

    // 1) Anneaux concentriques (grille).
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = HiColors.strokeSubtle;
    for (final ring in const [0.25, 0.5, 0.75, 1.0]) {
      final p = Path();
      for (var i = 0; i < n; i++) {
        final o = dir(i, radius * ring);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      p.close();
      canvas.drawPath(p, grid);
    }
    // 2) Rayons.
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, dir(i, radius), grid);
    }

    // 3) Polygone de données (grandit depuis le centre avec t).
    final values = [for (final a in radar) (a.unlocked ? (a.score / 100.0).clamp(0.06, 1.0) : 0.06) * t];
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final o = dir(i, radius * values[i]);
      i == 0 ? dataPath.moveTo(o.dx, o.dy) : dataPath.lineTo(o.dx, o.dy);
    }
    dataPath.close();
    final fill = Paint()
      ..shader = RadialGradient(
        colors: [HiColors.brandPrimary.withValues(alpha: 0.34), HiColors.brandPrimary.withValues(alpha: 0.05)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(dataPath, fill);
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = HiColors.brandPrimary.withValues(alpha: 0.9),
    );

    // 4) Sommets (dot coloré + glow) — apparaissent en 2e moitié de l'animation.
    final dotT = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    for (var i = 0; i < n; i++) {
      final a = radar[i];
      final o = dir(i, radius * values[i]);
      final color = a.unlocked ? HiColors.attribute(a.attribute) : HiColors.attrLocked;
      if (a.unlocked) {
        canvas.drawCircle(o, 8 * dotT, Paint()..color = color.withValues(alpha: 0.22 * dotT));
      }
      canvas.drawCircle(o, 3.2 * dotT, Paint()..color = color);
      canvas.drawCircle(
        o,
        3.2 * dotT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = HiColors.bgBase,
      );
    }

    // 5) Labels (nom + valeur) à l'extérieur de chaque axe.
    final labelT = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
    if (labelT > 0) {
      for (var i = 0; i < n; i++) {
        final a = radar[i];
        final anchor = dir(i, radius + 18);
        final color = a.unlocked ? HiColors.attribute(a.attribute) : HiColors.textTertiary;
        final tp = TextPainter(
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          text: TextSpan(children: [
            TextSpan(
                text: '${HiLabels.attribute(a.attribute)}\n',
                style: (baseLabel ?? const TextStyle()).copyWith(
                    color: HiColors.textSecondary.withValues(alpha: labelT), fontSize: 11, fontWeight: FontWeight.w600)),
            TextSpan(
                text: a.unlocked ? '${a.score}' : '—',
                style: HiType.numericM.copyWith(color: color.withValues(alpha: labelT), fontSize: 14)),
          ]),
        )..layout(maxWidth: 80);
        tp.paint(canvas, anchor - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.radar != radar;
}
