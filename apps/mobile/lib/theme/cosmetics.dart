import 'package:flutter/material.dart';

/// Récompenses cosmétiques débloquées par les badges (cf. badges.data.ts `cosmeticUnlock`).
/// Centralise le mapping id → effet visuel (testable, réutilisable). Source unique : tout
/// `cosmeticUnlock` côté API DOIT exister ici (un test garde-fou le vérifie côté backend).
enum CosmeticType { aura, glow, crown, badge, radarSkin }

class Cosmetic {
  final String id;
  final CosmeticType type;
  final Color color; // teinte principale
  final Color? color2; // pour les auras bi-tons
  final bool animated; // respiration/rotation (profil seulement)
  const Cosmetic(this.id, this.type, this.color, {this.color2, this.animated = false});
}

const Map<String, Cosmetic> kCosmeticCatalog = {
  'avatar_glow_gold': Cosmetic('avatar_glow_gold', CosmeticType.glow, Color(0xFFF3C13A)),
  'avatar_aura_diamond': Cosmetic('avatar_aura_diamond', CosmeticType.aura, Color(0xFFB98CFF), animated: true),
  'avatar_aura_top5': Cosmetic('avatar_aura_top5', CosmeticType.aura, Color(0xFF22D3EE), animated: true),
  'avatar_aura_top1': Cosmetic('avatar_aura_top1', CosmeticType.aura, Color(0xFF22D3EE), color2: Color(0xFFE879F9), animated: true),
  'avatar_crown_elite': Cosmetic('avatar_crown_elite', CosmeticType.crown, Color(0xFFF3C13A)),
  'avatar_badge_arsenal': Cosmetic('avatar_badge_arsenal', CosmeticType.badge, Color(0xFFF3C13A)),
  'radar_skin_full': Cosmetic('radar_skin_full', CosmeticType.radarSkin, Color(0xFF22D3EE)),
};

/// Une seule aura est rendue à la fois (priorité décroissante) — jamais surcharger l'avatar.
const List<String> _auraPriority = ['avatar_aura_top1', 'avatar_aura_top5', 'avatar_aura_diamond', 'avatar_glow_gold'];

/// Ensemble de cosmétiques actifs d'un utilisateur (ids débloqués).
class CosmeticSet {
  final List<String> ids;
  const CosmeticSet(this.ids);
  static const empty = CosmeticSet([]);

  /// L'aura dominante à afficher (ou null). `glow_gold` est traité comme une aura faible.
  Cosmetic? get aura {
    for (final id in _auraPriority) {
      if (ids.contains(id)) return kCosmeticCatalog[id];
    }
    return null;
  }

  bool get hasCrown => ids.contains('avatar_crown_elite');
  bool get hasArsenal => ids.contains('avatar_badge_arsenal');
  bool get hasRadarSkin => ids.contains('radar_skin_full');
  bool get isEmpty => ids.isEmpty;
}
