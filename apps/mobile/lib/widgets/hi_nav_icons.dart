import 'package:flutter/material.dart';

/// Icônes de navigation PROPRIÉTAIRES (audit design 03/07) — le geste qui « signe » la marque,
/// à la place des glyphes Material génériques. Set cohérent : grille 24 px, trait 2 px, coins et
/// extrémités arrondis. L'état actif passe du tracé (outline) au REMPLI, comme les icônes
/// Material outlined/rounded qu'elles remplacent (l'AnimatedScale du shell fait le reste).
enum HiNavGlyph { bolt, dumbbell, community, podium }

class HiNavIcon extends StatelessWidget {
  const HiNavIcon({
    super.key,
    required this.glyph,
    required this.active,
    required this.color,
    this.size = 24,
  });

  final HiNavGlyph glyph;
  final bool active;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _HiNavIconPainter(glyph: glyph, active: active, color: color),
    );
  }
}

class _HiNavIconPainter extends CustomPainter {
  const _HiNavIconPainter({required this.glyph, required this.active, required this.color});

  final HiNavGlyph glyph;
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Tout est dessiné sur une grille 24×24 puis mis à l'échelle → un seul jeu de coordonnées.
    final s = size.width / 24.0;
    canvas.scale(s, s);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    switch (glyph) {
      case HiNavGlyph.bolt:
        _bolt(canvas, stroke, fill);
      case HiNavGlyph.dumbbell:
        _dumbbell(canvas, stroke, fill);
      case HiNavGlyph.community:
        _community(canvas, stroke, fill);
      case HiNavGlyph.podium:
        _podium(canvas, stroke, fill);
    }
  }

  /// Éclair (Accueil) : l'énergie de la séance du jour.
  void _bolt(Canvas c, Paint stroke, Paint fill) {
    final p = Path()
      ..moveTo(13.2, 2.5)
      ..lineTo(5.8, 13.4)
      ..lineTo(11.0, 13.4)
      ..lineTo(10.4, 21.5)
      ..lineTo(18.2, 10.4)
      ..lineTo(12.7, 10.4)
      ..close();
    c.drawPath(p, active ? fill : stroke);
  }

  /// Haltère (Séances) : barre + deux disques arrondis.
  void _dumbbell(Canvas c, Paint stroke, Paint fill) {
    final left = RRect.fromLTRBR(4.5, 7.0, 8.0, 17.0, const Radius.circular(1.6));
    final right = RRect.fromLTRBR(16.0, 7.0, 19.5, 17.0, const Radius.circular(1.6));
    c.drawRRect(left, active ? fill : stroke);
    c.drawRRect(right, active ? fill : stroke);
    // La barre reste un trait dans les deux états (sinon le glyphe devient un pavé illisible).
    c.drawLine(const Offset(8.0, 12.0), const Offset(16.0, 12.0), stroke);
    // Petits embouts extérieurs : la signature « pro » du glyphe.
    c.drawLine(const Offset(2.2, 10.2), const Offset(2.2, 13.8), stroke);
    c.drawLine(const Offset(21.8, 10.2), const Offset(21.8, 13.8), stroke);
  }

  /// Anneau de groupe (Communauté) : trois têtes reliées par le cercle du club.
  void _community(Canvas c, Paint stroke, Paint fill) {
    const center = Offset(12, 13);
    c.drawCircle(center, 6.6, stroke);
    // Têtes posées SUR l'anneau (haut, bas-droite, bas-gauche) — toujours pleines : ce sont les
    // athlètes ; l'état actif est porté par l'anneau rempli d'une teinte + têtes élargies.
    const heads = [Offset(12, 6.4), Offset(17.7, 16.3), Offset(6.3, 16.3)];
    if (active) {
      final tint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      c.drawCircle(center, 6.6, tint);
    }
    for (final h in heads) {
      c.drawCircle(h, active ? 3.0 : 2.5, fill);
    }
  }

  /// Podium (Ligue) : trois marches, la première au centre.
  void _podium(Canvas c, Paint stroke, Paint fill) {
    final mid = RRect.fromLTRBR(9.0, 6.5, 15.0, 20.0, const Radius.circular(1.6));
    final left = RRect.fromLTRBR(3.0, 11.5, 9.0, 20.0, const Radius.circular(1.6));
    final right = RRect.fromLTRBR(15.0, 14.0, 21.0, 20.0, const Radius.circular(1.6));
    final p = active ? fill : stroke;
    c.drawRRect(left, p);
    c.drawRRect(mid, p);
    c.drawRRect(right, p);
  }

  @override
  bool shouldRepaint(_HiNavIconPainter old) =>
      old.glyph != glyph || old.active != active || old.color != color;
}
