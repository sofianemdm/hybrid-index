/** Catalogue des badges (spec gamification 20 juin). name/description vivent ici (le modèle DB
 *  ne stocke que id/category/condition/rarity/cosmeticUnlock + l'attribution via UserBadge). */
export type BadgeCategory = "progression" | "collection" | "performance" | "consistency" | "social";
export type Rarity = "common" | "rare" | "epic" | "legendary";

export interface BadgeDef {
  id: string;
  category: BadgeCategory;
  name: string;
  description: string;
  rarity: Rarity;
  condition: string;
  cosmeticUnlock: string | null;
}

export const BADGES: BadgeDef[] = [
  // PROGRESSION
  { id: "first-index", category: "progression", name: "Premier Index", description: "Tu as obtenu ton premier HYBRID INDEX complet.", rarity: "common", condition: "attribute_unlocked:all", cosmeticUnlock: null },
  { id: "confirmed-athlete", category: "progression", name: "Athlète confirmé", description: "5 séances loggées et suivi par 5 athlètes — un vrai membre actif.", rarity: "rare", condition: "confirmed", cosmeticUnlock: null },
  { id: "rank-bronze", category: "progression", name: "Bronze", description: "Atteins le rang Bronze.", rarity: "common", condition: "rank>=bronze", cosmeticUnlock: null },
  { id: "rank-gold", category: "progression", name: "Or", description: "Atteins le rang Or.", rarity: "rare", condition: "rank>=gold", cosmeticUnlock: "avatar_glow_gold" },
  { id: "rank-diamond", category: "progression", name: "Diamant", description: "Atteins le rang Diamant.", rarity: "epic", condition: "rank>=diamond", cosmeticUnlock: "avatar_aura_diamond" },
  { id: "rank-elite", category: "progression", name: "Élite", description: "Atteins le rang Élite. L'air se raréfie ici.", rarity: "legendary", condition: "rank>=elite", cosmeticUnlock: "avatar_crown_elite" },
  // Paliers d'Index : tous les 10 points de 30 à 60, puis tous les 5 points au-delà.
  { id: "index-30", category: "progression", name: "Seuil 30", description: "Franchis un HYBRID INDEX de 30.", rarity: "common", condition: "index>=30", cosmeticUnlock: null },
  { id: "index-40", category: "progression", name: "Seuil 40", description: "Franchis un HYBRID INDEX de 40.", rarity: "common", condition: "index>=40", cosmeticUnlock: null },
  { id: "index-50", category: "progression", name: "Seuil 50", description: "Franchis un HYBRID INDEX de 50.", rarity: "common", condition: "index>=50", cosmeticUnlock: null },
  { id: "index-60", category: "progression", name: "Seuil 60", description: "Franchis un HYBRID INDEX de 60.", rarity: "common", condition: "index>=60", cosmeticUnlock: null },
  { id: "index-65", category: "progression", name: "Seuil 65", description: "Franchis un HYBRID INDEX de 65.", rarity: "rare", condition: "index>=65", cosmeticUnlock: null },
  { id: "index-70", category: "progression", name: "Seuil 70", description: "Franchis un HYBRID INDEX de 70.", rarity: "rare", condition: "index>=70", cosmeticUnlock: null },
  { id: "index-75", category: "progression", name: "Seuil 75", description: "Franchis un HYBRID INDEX de 75.", rarity: "rare", condition: "index>=75", cosmeticUnlock: null },
  { id: "index-80", category: "progression", name: "Seuil 80", description: "Franchis un HYBRID INDEX de 80.", rarity: "epic", condition: "index>=80", cosmeticUnlock: null },
  { id: "index-85", category: "progression", name: "Seuil 85", description: "Franchis un HYBRID INDEX de 85.", rarity: "epic", condition: "index>=85", cosmeticUnlock: null },
  { id: "index-90", category: "progression", name: "Seuil 90", description: "Franchis un HYBRID INDEX de 90.", rarity: "epic", condition: "index>=90", cosmeticUnlock: null },
  { id: "index-95", category: "progression", name: "Seuil 95", description: "Franchis un HYBRID INDEX de 95. L'élite mondiale.", rarity: "legendary", condition: "index>=95", cosmeticUnlock: null },
  // COLLECTION
  { id: "explorer-5", category: "collection", name: "Explorateur", description: "Complète 5 WODs différents.", rarity: "common", condition: "wods_distinct>=5", cosmeticUnlock: null },
  { id: "all-attributes", category: "collection", name: "Profil complet", description: "Débloque les 6 attributs du radar.", rarity: "rare", condition: "attribute_unlocked:all", cosmeticUnlock: "radar_skin_full" },
  { id: "full-arsenal", category: "collection", name: "Arsenal complet", description: "Complète 15 WODs de référence.", rarity: "epic", condition: "wods_distinct>=15", cosmeticUnlock: "avatar_badge_arsenal" },
  { id: "no-gear-hero", category: "collection", name: "Sans matériel", description: "Logue 7 WODs sans matériel. Aucune excuse.", rarity: "rare", condition: "equipment_free_count>=7", cosmeticUnlock: null },
  // PERFORMANCE
  { id: "top-25", category: "performance", name: "Top 25 %", description: "Entre dans le top 25 % de ta ligue.", rarity: "rare", condition: "percentile>=75", cosmeticUnlock: null },
  { id: "top-5", category: "performance", name: "Top 5 %", description: "Entre dans le top 5 % de ta ligue.", rarity: "epic", condition: "percentile>=95", cosmeticUnlock: "avatar_aura_top5" },
  { id: "top-1", category: "performance", name: "Top 1 %", description: "Le très haut du panier. Top 1 % de ta ligue.", rarity: "legendary", condition: "percentile>=99", cosmeticUnlock: "avatar_aura_top1" },
];

const RANK_ORDER = ["rookie", "bronze", "silver", "gold", "platinum", "diamond", "elite"];

export interface BadgeContext {
  logCount: number;
  followsCount: number; // nombre d'athlètes suivis
  distinctWods: number;
  equipmentFreeCount: number;
  rank: string;
  index: number;
  percentile: number; // 0..100
  attributesAllUnlocked: boolean;
  streakCurrent: number;
  streakBest: number;
}

/** Évalue une condition machine contre le contexte de l'utilisateur. */
export function matchesCondition(condition: string, ctx: BadgeContext): boolean {
  if (condition === "attribute_unlocked:all") return ctx.attributesAllUnlocked;
  // « Athlète confirmé » : membre actif et réel (anti-bot) — 5 séances + 5 relations.
  if (condition === "confirmed") return ctx.logCount >= 5 && ctx.followsCount >= 5;

  const ge = condition.match(/^(\w+)>=(.+)$/);
  if (ge) {
    const [, key, valRaw] = ge;
    switch (key) {
      case "rank":
        return RANK_ORDER.indexOf(ctx.rank) >= RANK_ORDER.indexOf(valRaw);
      case "index":
        return ctx.index >= Number(valRaw);
      case "percentile":
        return ctx.percentile >= Number(valRaw);
      case "wods_distinct":
        return ctx.distinctWods >= Number(valRaw);
      case "equipment_free_count":
        return ctx.equipmentFreeCount >= Number(valRaw);
      case "streak":
        return ctx.streakCurrent >= Number(valRaw);
      case "streak_best":
        return ctx.streakBest >= Number(valRaw);
      default:
        return false;
    }
  }
  return false; // conditions non encore implémentées (ex. pro_gap)
}
