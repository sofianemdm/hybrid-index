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
  /** Série progressive (index/rank/league/humanity) → l'app n'affiche que le palier atteint + le suivant. */
  series?: string;
  /** Position dans la série (croissante) pour ordonner les paliers. */
  seriesOrder?: number;
}

export const BADGES: BadgeDef[] = [
  // PROGRESSION
  { id: "first-index", category: "progression", name: "Premier Index", description: "Tu as obtenu ton premier HYBRID INDEX.", rarity: "common", condition: "has_index", cosmeticUnlock: null },
  { id: "confirmed-athlete", category: "progression", name: "Athlète confirmé", description: "5 séances loggées — un membre actif.", rarity: "common", condition: "logs>=5", cosmeticUnlock: null },
  { id: "rank-bronze", category: "progression", name: "Bronze", description: "Atteins le rang Bronze.", rarity: "common", condition: "rank>=bronze", cosmeticUnlock: null },
  { id: "rank-gold", category: "progression", name: "Or", description: "Atteins le rang Or.", rarity: "rare", condition: "rank>=gold", cosmeticUnlock: "avatar_glow_gold" },
  { id: "rank-diamond", category: "progression", name: "Diamant", description: "Atteins le rang Diamant.", rarity: "epic", condition: "rank>=diamond", cosmeticUnlock: "avatar_aura_diamond" },
  { id: "rank-elite", category: "progression", name: "Élite", description: "Atteins le rang Élite. L'air se raréfie ici.", rarity: "legendary", condition: "rank>=elite", cosmeticUnlock: "avatar_crown_elite" },
  // Paliers d'Index (display-v2 : plancher ~35, plafond 98). Rapprochés en bas (récompense rapide
  // juste au-dessus du plancher), espacés et rares en haut. PAS de palier <=35 (toujours vrai) ni
  // >=100 (inatteignable : la courbe plafonne à 98). cf. audit G-05/06/07.
  { id: "index-45", category: "progression", name: "Seuil 45", description: "Franchis un HYBRID INDEX de 45.", rarity: "common", condition: "index>=45", cosmeticUnlock: null, series: "index", seriesOrder: 1 },
  { id: "index-52", category: "progression", name: "Seuil 52", description: "Franchis un HYBRID INDEX de 52.", rarity: "common", condition: "index>=52", cosmeticUnlock: null, series: "index", seriesOrder: 2 },
  { id: "index-60", category: "progression", name: "Seuil 60", description: "Franchis un HYBRID INDEX de 60.", rarity: "common", condition: "index>=60", cosmeticUnlock: null, series: "index", seriesOrder: 3 },
  { id: "index-68", category: "progression", name: "Seuil 68", description: "Franchis un HYBRID INDEX de 68.", rarity: "rare", condition: "index>=68", cosmeticUnlock: null, series: "index", seriesOrder: 4 },
  { id: "index-75", category: "progression", name: "Seuil 75", description: "Franchis un HYBRID INDEX de 75.", rarity: "rare", condition: "index>=75", cosmeticUnlock: null, series: "index", seriesOrder: 5 },
  { id: "index-82", category: "progression", name: "Seuil 82", description: "Franchis un HYBRID INDEX de 82.", rarity: "epic", condition: "index>=82", cosmeticUnlock: null, series: "index", seriesOrder: 6 },
  { id: "index-88", category: "progression", name: "Seuil 88", description: "Franchis un HYBRID INDEX de 88.", rarity: "epic", condition: "index>=88", cosmeticUnlock: null, series: "index", seriesOrder: 7 },
  { id: "index-92", category: "progression", name: "Seuil 92", description: "Franchis un HYBRID INDEX de 92. Tu touches l'élite.", rarity: "epic", condition: "index>=92", cosmeticUnlock: null, series: "index", seriesOrder: 8 },
  { id: "index-95", category: "progression", name: "Seuil 95", description: "Franchis un HYBRID INDEX de 95. Très peu y arrivent.", rarity: "legendary", condition: "index>=95", cosmeticUnlock: null, series: "index", seriesOrder: 9 },
  { id: "index-98", category: "progression", name: "Seuil 98", description: "Tu frôles le plafond théorique de l'Index. L'extrême sommet.", rarity: "legendary", condition: "index>=98", cosmeticUnlock: null, series: "index", seriesOrder: 10 },
  // COLLECTION
  { id: "explorer-5", category: "collection", name: "Explorateur", description: "Complète 5 séances différentes.", rarity: "common", condition: "wods_distinct>=5", cosmeticUnlock: null },
  { id: "all-attributes", category: "collection", name: "Profil complet", description: "Débloque les 6 attributs du radar.", rarity: "rare", condition: "attribute_unlocked:all", cosmeticUnlock: "radar_skin_full" },
  { id: "full-arsenal", category: "collection", name: "Arsenal complet", description: "Complète 15 séances de référence.", rarity: "epic", condition: "wods_distinct>=15", cosmeticUnlock: "avatar_badge_arsenal" },
  { id: "no-gear-hero", category: "collection", name: "Sans matériel", description: "Logue 7 séances sans matériel. Aucune excuse.", rarity: "rare", condition: "equipment_free_count>=7", cosmeticUnlock: null },
  // PERFORMANCE — classement de ligue (top X% de ta ligue)
  { id: "top-50", category: "performance", name: "Top 50 %", description: "Entre dans la moitié haute de ta ligue.", rarity: "common", condition: "percentile>=50", cosmeticUnlock: null },
  { id: "top-25", category: "performance", name: "Top 25 %", description: "Entre dans le top 25 % de ta ligue.", rarity: "rare", condition: "percentile>=75", cosmeticUnlock: null },
  { id: "top-5", category: "performance", name: "Top 5 %", description: "Entre dans le top 5 % de ta ligue.", rarity: "epic", condition: "percentile>=95", cosmeticUnlock: "avatar_aura_top5" },
  { id: "top-1", category: "performance", name: "Top 1 %", description: "Le très haut du panier. Top 1 % de ta ligue.", rarity: "legendary", condition: "percentile>=99", cosmeticUnlock: "avatar_aura_top1" },
  // PERFORMANCE — % des humains les plus en forme (normes de population)
  { id: "humanity-25", category: "performance", name: "Top 25 % mondial", description: "Plus en forme que 75 % des humains.", rarity: "common", condition: "humanity<=25", cosmeticUnlock: null },
  { id: "humanity-15", category: "performance", name: "Top 15 % mondial", description: "Tu fais partie des 15 % des humains les plus en forme.", rarity: "common", condition: "humanity<=15", cosmeticUnlock: null },
  { id: "humanity-10", category: "performance", name: "Top 10 % mondial", description: "Tu fais partie des 10 % des humains les plus en forme.", rarity: "epic", condition: "humanity<=10", cosmeticUnlock: null },
  { id: "humanity-5", category: "performance", name: "Top 5 % mondial", description: "Tu fais partie des 5 % des humains les plus en forme.", rarity: "epic", condition: "humanity<=5", cosmeticUnlock: null },
  { id: "humanity-2", category: "performance", name: "Top 2 % mondial", description: "Tu fais partie des 2 % des humains les plus en forme.", rarity: "legendary", condition: "humanity<=2", cosmeticUnlock: null },
  { id: "humanity-1", category: "performance", name: "Top 1 % mondial", description: "Tu fais partie des 1 % des humains les plus en forme.", rarity: "legendary", condition: "humanity<=1", cosmeticUnlock: null },
  // RÉGULARITÉ (streak HEBDOMADAIRE — régularité, jamais volume ; cf. streak.service.ts). Le repos
  // planifié et les jetons de gel maintiennent la série : on récompense la constance saine (G-04).
  { id: "streak-1", category: "consistency", name: "Première semaine", description: "Une semaine d'entraînement régulier validée. C'est parti.", rarity: "common", condition: "streak>=1", cosmeticUnlock: null, series: "streak", seriesOrder: 1 },
  { id: "streak-4", category: "consistency", name: "Régulier (1 mois)", description: "4 semaines de régularité d'affilée. L'habitude s'installe.", rarity: "common", condition: "streak>=4", cosmeticUnlock: null, series: "streak", seriesOrder: 2 },
  { id: "streak-12", category: "consistency", name: "Discipliné (3 mois)", description: "12 semaines de constance. La régularité paie.", rarity: "rare", condition: "streak>=12", cosmeticUnlock: null, series: "streak", seriesOrder: 3 },
  { id: "streak-26", category: "consistency", name: "Inarrêtable (6 mois)", description: "26 semaines de régularité. Une routine en acier.", rarity: "epic", condition: "streak>=26", cosmeticUnlock: null, series: "streak", seriesOrder: 4 },
  { id: "streak-52", category: "consistency", name: "Une année pleine", description: "52 semaines de régularité consécutives. Le marathon, pas le sprint.", rarity: "legendary", condition: "streak>=52", cosmeticUnlock: null, series: "streak", seriesOrder: 5 },
  { id: "streak-best-12", category: "consistency", name: "Meilleure série : 3 mois", description: "Ta meilleure série a atteint 12 semaines. Elle reste gravée.", rarity: "rare", condition: "streak_best>=12", cosmeticUnlock: null, series: "streak_best", seriesOrder: 1 },
  // SOCIAL (n'apparaît que si le social est actif). ATTENTION : followersCount = athlètes qui te SUIVENT.
  { id: "first-follower", category: "social", name: "Premier supporter", description: "Un premier athlète te suit. Ton parcours inspire.", rarity: "common", condition: "followers>=1", cosmeticUnlock: null },
  { id: "rising-figure", category: "social", name: "Figure montante", description: "10 athlètes te suivent. Tu deviens une référence.", rarity: "rare", condition: "followers>=10", cosmeticUnlock: null, series: "social", seriesOrder: 1 },
];

const RANK_ORDER = ["rookie", "bronze", "silver", "gold", "platinum", "diamond", "elite"];

export interface BadgeContext {
  logCount: number;
  followersCount: number; // nombre d'athlètes qui SUIVENT l'utilisateur (followers)
  distinctWods: number;
  equipmentFreeCount: number;
  rank: string;
  index: number;
  percentile: number; // 0..100 — rang dans la ligue (app)
  leagueTotal: number; // effectif de la ligue (même sexe) ayant un Index
  humanityTopPercent: number; // 1..100 — « top X% » de la population générale (normes)
  attributesAllUnlocked: boolean;
  streakCurrent: number;
  streakBest: number;
}

/** Évalue une condition machine contre le contexte de l'utilisateur. */
export function matchesCondition(condition: string, ctx: BadgeContext): boolean {
  if (condition === "attribute_unlocked:all") return ctx.attributesAllUnlocked;
  // « Premier Index » : au moins un attribut débloqué → un Index existe (> plancher).
  if (condition === "has_index") return ctx.index > 0;

  // « humanity<=X » : faire partie des X% des humains les plus en forme.
  const le = condition.match(/^humanity<=(.+)$/);
  if (le) return ctx.humanityTopPercent <= Number(le[1]);

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
      case "logs":
        return ctx.logCount >= Number(valRaw);
      case "followers":
        return ctx.followersCount >= Number(valRaw);
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
