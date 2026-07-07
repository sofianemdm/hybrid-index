import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/cosmetics.dart';
import '../data/dicebear.dart';
import '../theme/tokens.dart';
import 'net_avatar_image.dart';

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

/// Avatar de l'athlète avec cadre de rang : photo de profil si présente, sinon image DiceBear
/// avataaars (seul système d'avatar — l'ancien avatar « dessiné » a été supprimé le 07/07).
/// Sans configuration, repli sur un avataaars générique stable (seed 'athlete').
class HiAvatar extends StatelessWidget {
  final AvatarConfig config;
  final String rank;
  final double size;
  final bool showRing;
  /// Cosmétiques débloqués (aura). Si null → rendu historique par rang (rétrocompatible).
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
    // Aura : cosmétiques débloqués si fournis et non vides, sinon repli historique par rang
    // (diamant/élite) — un élite fraîchement promu garde sa lueur même sans badge attribué.
    final auraColor = (cosmetics != null && cosmetics!.ids.isNotEmpty)
        ? cosmetics!.aura?.color
        : (rank == 'diamond' || rank == 'elite')
            ? ringColor
            : null;

    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      border: showRing ? Border.all(color: ringColor, width: size * 0.04) : null,
      boxShadow: auraColor != null
          ? [BoxShadow(color: auraColor.withValues(alpha: 0.6), blurRadius: size * 0.16, spreadRadius: size * 0.03)]
          : null,
    );

    // Photo de profil : prioritaire, avec cadre de rang.
    if (photo != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: decoration,
          child: ClipOval(
            child: Image.memory(photo, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
      );
    }

    // Image DiceBear avataaars : options personnalisées si présentes, sinon rendu par seed
    // (repli générique 'athlete' pour les configs vides — quasi jamais atteint après backfill).
    final url = (config.diceOptions != null && config.diceOptions!.isNotEmpty)
        ? avataaarsUrl(options: config.diceOptions!, seed: config.diceSeed ?? 'athlete', size: (size * 2).round())
        : diceBearUrl(style: 'avataaars', seed: config.diceSeed ?? 'athlete', size: (size * 2).round());
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: decoration,
        child: ClipOval(
          // Cache DISQUE sur mobile (NetAvatarImage) : l'avatar n'est plus re-téléchargé à chaque
          // rebuild/écran (classements, feed, Ligue…) — affichage instantané dès le 2e passage.
          child: NetAvatarImage(
            url,
            width: size,
            height: size,
            placeholder: (_) => Container(color: HiColors.bgElevated2),
            error: (_) => Container(color: HiColors.bgElevated2),
          ),
        ),
      ),
    );
  }
}
