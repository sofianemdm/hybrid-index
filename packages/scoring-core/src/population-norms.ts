import type { AttributeKey, Goal, Sex } from "@hybrid-index/contracts";
import { percentile, type PointTableModel } from "./distribution";
import { WEIGHTS_V1 } from "./weights";
import type { AttributeResult } from "./attribute";

/**
 * `popnorm-v1` — percentile dans la POPULATION GÉNÉRALE adulte (distinct de la distribution
 * COMPÉTITIVE qui produit l'Index/le rang). Sert UNIQUEMENT au message valorisant
 * « tu fais partie des X% des humains les plus en forme ».
 *
 * Fondé sur des normes publiées (ACSM/Cooper VO2max, OMS inactivité, ACSM/APFT pompes & sit-ups,
 * ExRx/NSCA force & saut, RunRepeat 5k). Voir docs/population-norms-sources.md.
 *
 * Méthode : pour chaque attribut on dispose d'une table {subScore → percentile population} par
 * sexe, calibrée en alignant un repère physique sourcé (ex. « 20 pompes = ~médiane H ») sur le
 * sous-score que cette performance produit déjà dans la chaîne compétitive. On REUTILISE le
 * `PointTableModel` + `percentile()` existants : nœuds {p: popP, r: subScore}, dir = +1
 * (sous-score plus haut ⇒ meilleur percentile population).
 *
 * Confiance : `estimate` (chaque ancre est sourcée, mais l'agrégation reste un modèle). Référence
 * d'âge : adulte ~30-39 ans (l'ajustement fin par tranche d'âge est documenté comme évolution).
 */
export const POPNORM_VERSION = "popnorm-v1";

/** Nœuds {subScore, popP} → PointTableModel exploitable par `percentile()`. */
function table(nodes: ReadonlyArray<readonly [subScore: number, popP: number]>): PointTableModel {
  return { kind: "pointTable", dir: 1, nodes: nodes.map(([r, p]) => ({ p, r })) };
}

/**
 * Tables population par sexe et par attribut (cf. spec sport-science §2, popnorm-v1).
 * Chaque ligne = [sousScore, percentilePopulation]. P croissant ⇔ sousScore croissant.
 */
export const POP_NORMS_V1: Record<Sex, Record<AttributeKey, PointTableModel>> = {
  male: {
    // Engine : base la plus « accessible » de la population (marcher/courir un peu existe).
    // 300 = débutant qui finit un metcon scaled ≈ top 36% ; 450 = amateur régulier ≈ top 17%.
    engine: table([
      [150, 0.18], [300, 0.64], [450, 0.83], [600, 0.91], [750, 0.96], [880, 0.985], [950, 0.995],
    ]),
    // Endurance musculaire (pompes/sit-ups) : très clivant — bcp d'adultes < 10 pompes strictes.
    muscular_endurance: table([
      [150, 0.2], [330, 0.66], [450, 0.84], [600, 0.92], [720, 0.96], [850, 0.99], [950, 0.997],
    ]),
    // Force : compétence la PLUS rare dans la population (~3/4 des adultes ne font aucun renfo).
    // 350 (médian compétitif) déjà ≈ top 17% ; 1.0x BW (~500) ≈ top 12% ; 1.5x BW (~700) ≈ top 5%.
    strength: table([
      [150, 0.22], [350, 0.83], [500, 0.88], [680, 0.94], [820, 0.985], [950, 0.998],
    ]),
    power: table([
      [200, 0.25], [360, 0.82], [560, 0.9], [740, 0.95], [880, 0.99], [950, 0.997],
    ]),
    speed: table([
      [200, 0.24], [360, 0.81], [520, 0.88], [700, 0.94], [870, 0.99], [950, 0.997],
    ]),
    hybrid: table([
      [150, 0.2], [350, 0.83], [500, 0.89], [680, 0.94], [820, 0.985], [950, 0.998],
    ]),
  },
  female: {
    engine: table([
      [150, 0.2], [300, 0.66], [450, 0.85], [600, 0.92], [750, 0.965], [880, 0.987], [950, 0.996],
    ]),
    muscular_endurance: table([
      [150, 0.22], [330, 0.68], [450, 0.86], [600, 0.93], [720, 0.965], [850, 0.99], [950, 0.997],
    ]),
    strength: table([
      [150, 0.24], [350, 0.85], [500, 0.9], [680, 0.95], [820, 0.987], [950, 0.998],
    ]),
    power: table([
      [200, 0.27], [360, 0.84], [560, 0.91], [740, 0.96], [880, 0.99], [950, 0.997],
    ]),
    speed: table([
      [200, 0.26], [360, 0.83], [520, 0.89], [700, 0.95], [870, 0.99], [950, 0.997],
    ]),
    hybrid: table([
      [150, 0.22], [350, 0.85], [500, 0.9], [680, 0.95], [820, 0.987], [950, 0.998],
    ]),
  },
};

/** Percentile population pour un attribut donné (fraction d'adultes du même sexe battue). */
export function popPercentileAttr(sex: Sex, attribute: AttributeKey, subScore: number): number {
  return percentile(subScore, POP_NORMS_V1[sex][attribute]);
}

/**
 * Percentile population au niveau de l'Index : moyenne pondérée NO-DROP des percentiles
 * population par attribut, avec les MÊMES poids que l'Index (cohérence Option B). Les attributs
 * verrouillés sont exclus (ne tirent jamais vers le bas). Défaut prudent si aucun débloqué.
 */
export function popPercentileIndex(
  sex: Sex,
  goal: Goal,
  radar: ReadonlyArray<AttributeResult>,
): number {
  const weights = WEIGHTS_V1[goal];
  const unlocked = radar.filter((a) => a.unlocked);
  if (unlocked.length === 0) return 0.3; // ~top 70% : prudent, jamais dévalorisant

  let num = 0;
  let den = 0;
  for (const a of unlocked) {
    const w = weights[a.attribute];
    num += w * popPercentileAttr(sex, a.attribute, a.score);
    den += w;
  }
  return den > 0 ? num / den : 0.3;
}

export interface PopulationBand {
  /** « top X% » affiché (1/2/5/10/20/30/50), ou null si sous la médiane (bande « en construction »). */
  topPercent: number | null;
  /** Clé de bande stable pour détecter les montées et router la copie : pop_top_1 … pop_building. */
  band: string;
}

/** Paliers d'affichage (du plus rare au plus large). On affiche le plus petit palier atteint.
 *  EXPORTÉ pour rester l'UNIQUE source de vérité de l'ordre des bandes (cf. BAND_ORDER côté API). */
export const DISPLAY_BANDS = [1, 2, 5, 10, 15, 25, 35, 50] as const;

/** Ordre des bandes du MEILLEUR (pop_top_1) au moins bon (pop_building), dérivé de DISPLAY_BANDS.
 *  Toute clé renvoyée par `bandFromP` y figure → les montées de bande sont toujours détectées. */
export const POP_BAND_ORDER: string[] = [...DISPLAY_BANDS.map((b) => `pop_top_${b}`), "pop_building"];

/**
 * Bande de message à partir d'un percentile population. Honnête : on n'affiche jamais de décimale
 * sous 1% et on arrondit au palier atteint (popP=0.962 → « top 5% »). Sous la médiane → bande
 * « en construction » (formulée en distance à franchir côté UI, jamais « tu es dans le bas »).
 */
export function bandFromP(popP: number): PopulationBand {
  // Arrondi anti-flottant : (1-0.7)*100 = 30.0000…4 manquerait le palier 30.
  const topPercentRaw = Math.round((1 - popP) * 1e6) / 1e4;
  if (topPercentRaw > 50) return { topPercent: null, band: "pop_building" };
  const topPercent = DISPLAY_BANDS.find((b) => b >= topPercentRaw) ?? 50;
  return { topPercent, band: `pop_top_${topPercent}` };
}
