import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/cosmetics.dart';
import '../theme/tokens.dart';

/// Palettes de l'avatar (indices stockés côté serveur).
class AvatarPalettes {
  AvatarPalettes._();
  static const skin = <Color>[
    Color(0xFFFFE0BD), Color(0xFFF5CFA0), Color(0xFFE8B68A), Color(0xFFC68642),
    Color(0xFF8D5524), Color(0xFF5C3A21), Color(0xFFEFC9B0), Color(0xFF3D2314),
  ];
  static const hair = <Color>[
    Color(0xFF1A1A1A), Color(0xFF4B3621), Color(0xFF8B5A2B), Color(0xFFD4A017),
    Color(0xFFB22222), Color(0xFFBFBFBF), Color(0xFF6A4E9C), Color(0xFF2E8B57),
  ];
  static const hairStyleLabels = ['Chauve', 'Court', 'Mi-long', 'Long', 'Piquant', 'Afro'];
  static const beardStyleLabels = ['Aucune', 'Barbe naissante', 'Barbe pleine', 'Bouc', 'Moustache'];

  /// Fonds d'avatar (index 0 = neutre). Couleurs sobres, cohérentes avec le thème sombre.
  static const backgroundLabels = ['Neutre', 'Ardoise', 'Cyan', 'Violet', 'Or', 'Émeraude', 'Rubis', 'Nuit'];
  static const background = <Color>[
    Color(0xFF20283A), Color(0xFF334155), Color(0xFF0E7490), Color(0xFF6D28D9),
    Color(0xFFB7791F), Color(0xFF047857), Color(0xFFB91C1C), Color(0xFF0B1220),
  ];
}

/// Décode une data URL base64 (« data:image/...;base64,xxxx ») en octets.
Uint8List? decodeAvatarPhoto(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  try {
    final comma = dataUrl.indexOf(',');
    final b64 = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

/// Avatar stylisé dessiné (peau/cheveux/barbe) avec cadre de rang. Pas d'assets : tout est vectoriel.
class HiAvatar extends StatelessWidget {
  final AvatarConfig config;
  final String rank;
  final double size;
  final bool showRing;
  /// Cosmétiques débloqués (aura/couronne/pastille). Si null → rendu historique par rang
  /// (rétrocompatible). Si fourni → l'aura/la couronne suivent les cosmétiques (récompenses badges).
  final CosmeticSet? cosmetics;
  const HiAvatar({
    super.key,
    required this.config,
    this.rank = 'rookie',
    this.size = 96,
    this.showRing = true,
    this.cosmetics,
  });

  @override
  Widget build(BuildContext context) {
    final photo = decodeAvatarPhoto(config.photoData);
    final ringColor = HiColors.rank(rank);

    // Photo de profil : remplace l'avatar dessiné, avec cadre de rang.
    if (photo != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: showRing
              ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ringColor, width: size * 0.04))
              : null,
          child: ClipOval(
            child: Image.memory(photo, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
      );
    }

    // Avatar dessiné, avec fond personnalisé optionnel (index 0 = neutre).
    final bg = config.background > 0 && config.background < AvatarPalettes.background.length
        ? AvatarPalettes.background[config.background]
        : null;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          if (bg != null)
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: bg))),
          CustomPaint(size: Size(size, size), painter: _AvatarPainter(config, ringColor, rank, showRing, cosmetics)),
        ],
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final AvatarConfig c;
  final Color rankColor;
  final String rank;
  final bool showRing;
  final CosmeticSet? cosmetics;
  _AvatarPainter(this.c, this.rankColor, this.rank, this.showRing, this.cosmetics);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final skin = AvatarPalettes.skin[c.skinTone % AvatarPalettes.skin.length];
    final hair = AvatarPalettes.hair[c.hairColor % AvatarPalettes.hair.length];

    // Aura cosmétique selon le rang (l'avatar évolue avec la progression).
    // Aura : pilotée par les cosmétiques débloqués si fournis ET non vides (récompense de badge),
    // sinon repli historique sur le rang (diamant/élite). Un set VIDE ne masque pas l'aura de rang
    // (un élite fraîchement promu, badge pas encore attribué, garde sa couronne). Rendu statique.
    final cos = (cosmetics != null && cosmetics!.ids.isNotEmpty) ? cosmetics : null;
    if (cos != null) {
      final aura = cos.aura;
      if (aura != null) {
        canvas.drawCircle(
          Offset(cx, cx),
          s * 0.49,
          Paint()
            ..color = aura.color.withValues(alpha: aura.color2 != null ? 0.34 : 0.28)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
        );
      }
    } else if (rank == 'diamond' || rank == 'elite') {
      canvas.drawCircle(
        Offset(cx, cx),
        s * 0.49,
        Paint()
          ..color = rankColor.withValues(alpha: rank == 'elite' ? 0.45 : 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
      );
    }

    // Fond + cadre de rang.
    final bg = Paint()..color = HiColors.bgElevated2;
    canvas.drawCircle(Offset(cx, cx), s * 0.48, bg);
    if (showRing) {
      final ring = Paint()
        ..color = rankColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * (rank == 'elite' ? 0.05 : 0.04);
      canvas.drawCircle(Offset(cx, cx), s * 0.46, ring);
    }

    final headR = s * 0.22;
    final headCy = s * 0.44;

    // Épaules / buste (couleur marque sombre).
    final torso = Paint()..color = HiColors.brandPrimaryDeep;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - s * 0.26, s * 0.66, s * 0.52, s * 0.30), Radius.circular(s * 0.12)),
      torso,
    );

    // Afro (derrière la tête).
    if (c.hairStyle == 5) {
      canvas.drawCircle(Offset(cx, headCy - headR * 0.2), headR * 1.45, Paint()..color = hair);
    }

    // Tête.
    final head = Paint()..color = skin;
    canvas.drawCircle(Offset(cx, headCy), headR, head);

    // Cheveux (selon le style).
    _drawHair(canvas, cx, headCy, headR, hair);

    // Couronne Élite (cosmétique du plus haut rang).
    final showCrown = cos != null ? cos.hasCrown : rank == 'elite';
    if (showCrown) {
      final gold = Paint()..color = const Color(0xFFF3C13A);
      final topY = headCy - headR * (c.hairStyle == 0 ? 1.05 : 1.25);
      final w = headR * 0.9;
      final crown = Path()
        ..moveTo(cx - w, topY + headR * 0.28)
        ..lineTo(cx - w, topY)
        ..lineTo(cx - w * 0.5, topY + headR * 0.16)
        ..lineTo(cx, topY - headR * 0.08)
        ..lineTo(cx + w * 0.5, topY + headR * 0.16)
        ..lineTo(cx + w, topY)
        ..lineTo(cx + w, topY + headR * 0.28)
        ..close();
      canvas.drawPath(crown, gold);
    }

    // Yeux.
    final eye = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(Offset(cx - headR * 0.38, headCy + headR * 0.05), headR * 0.10, eye);
    canvas.drawCircle(Offset(cx + headR * 0.38, headCy + headR * 0.05), headR * 0.10, eye);

    // Barbe.
    final beard = c.beardStyle ?? 0;
    if (beard > 0) {
      final p = Paint()..color = hair;
      if (beard == 4) {
        // Moustache.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, headCy + headR * 0.42), width: headR * 0.7, height: headR * 0.18),
            Radius.circular(headR * 0.1),
          ),
          p,
        );
      } else {
        // Barbe (arc bas du visage) ; plus dense selon le style.
        final rect = Rect.fromCircle(center: Offset(cx, headCy), radius: headR);
        final sweep = beard == 1 ? 0.7 : (beard == 3 ? 0.5 : 1.0);
        final start = math.pi / 2 - (math.pi * sweep) / 2;
        final path = Path()
          ..addArc(rect, start, math.pi * sweep)
          ..close();
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        canvas.drawPath(path, p..color = hair.withValues(alpha: beard == 1 ? 0.55 : 1.0));
        canvas.restore();
      }
    }
  }

  void _drawHair(Canvas canvas, double cx, double cy, double r, Color hair) {
    if (c.hairStyle == 0) return; // chauve
    final p = Paint()..color = hair;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Casquette de cheveux : arc couvrant le haut de la tête.
    final coverage = switch (c.hairStyle) {
      1 => 0.95, // court
      2 => 1.15, // mi-long
      3 => 1.25, // long
      4 => 0.9, // piquant
      _ => 1.1,
    };
    final path = Path()..addArc(rect, math.pi, math.pi);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect.inflate(r * 0.04)));
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy - r * (coverage - 1)), radius: r), math.pi, math.pi, false,
        p..style = PaintingStyle.fill);
    canvas.restore();
    path.reset();

    if (c.hairStyle == 3) {
      // Mèches longues sur les côtés.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - r * 1.02, cy - r * 0.2, r * 0.22, r * 1.2), Radius.circular(r * 0.1)),
        p,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx + r * 0.80, cy - r * 0.2, r * 0.22, r * 1.2), Radius.circular(r * 0.1)),
        p,
      );
    } else if (c.hairStyle == 4) {
      // Pointes piquantes.
      for (var i = -2; i <= 2; i++) {
        final x = cx + i * r * 0.38;
        final tri = Path()
          ..moveTo(x - r * 0.16, cy - r * 0.85)
          ..lineTo(x + r * 0.16, cy - r * 0.85)
          ..lineTo(x, cy - r * 1.25)
          ..close();
        canvas.drawPath(tri, p);
      }
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.c.skinTone != c.skinTone ||
      old.c.hairStyle != c.hairStyle ||
      old.c.hairColor != c.hairColor ||
      old.c.beardStyle != c.beardStyle ||
      old.rank != rank ||
      old.rankColor != rankColor ||
      old.cosmetics?.ids.join() != cosmetics?.ids.join();
}
