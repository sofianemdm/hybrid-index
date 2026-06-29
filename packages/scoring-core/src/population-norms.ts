import type { AttributeKey, Goal, Sex } from "@hybrid-index/contracts";
import { percentile, type PointTableModel } from "./distribution";
import { WEIGHTS_V1 } from "./weights";
import type { AttributeResult } from "./attribute";

/**
 * `popnorm-v2` — percentile dans la POPULATION GÉNÉRALE adulte (distinct de la distribution
 * COMPÉTITIVE qui produit l'Index/le rang). Sert UNIQUEMENT au message valorisant
 * « tu fais partie des X% des humains les plus en forme ».
 *
 * Fondé sur des normes publiées (ACSM/Cooper VO2max, OMS inactivité, ACSM/APFT pompes & sit-ups,
 * ExRx/NSCA force & saut, RunRepeat 5k). Voir docs/population-norms-sources.md.
 *
 * Tables par attribut (calibrage) : pour chaque attribut on dispose d'une table
 * {subScore → percentile population} par sexe, calibrée en alignant un repère physique sourcé
 * (ex. « 20 pompes = ~médiane H ») sur le sous-score que cette performance produit déjà dans la
 * chaîne compétitive. On REUTILISE le `PointTableModel` + `percentile()` existants :
 * nœuds {p: popP, r: subScore}, dir = +1 (sous-score plus haut ⇒ meilleur percentile population).
 * Ces tables sont INCHANGÉES depuis v1 : elles notent déjà très bien un attribut isolé (un
 * cardio élite ressort à ~0.99). Le défaut de v1 était l'AGRÉGATION, pas les tables.
 *
 * ───────────────────────────────────────────────────────────────────────────────────────────
 * NOUVEAUTÉ v2 — AGRÉGATION « top-lourde gardée » (le cœur du correctif)
 * ───────────────────────────────────────────────────────────────────────────────────────────
 * Problème v1 : moyenne pondérée des percentiles → un athlète ÉLITE sur 1-2 systèmes (cardio
 * 0.999, vitesse 0.999, endurance ~0.98) mais NON entraîné en force/puissance (~0.05-0.18)
 * tombait à ~0.69 → « top 35% ». C'est faux vs la population GÉNÉRALE : la grande majorité des
 * adultes est sédentaire (OMS 2022 : ~27,5% insuffisamment actifs ; et la médiane ne court pas
 * 3 km du tout). Quelqu'un qui court 3 km en 11:30 est dans une petite élite, point.
 *
 * Raisonnement physiologique : « être en forme vs la population générale » n'est PAS une moyenne
 * de tous les systèmes — c'est dominé par tes MEILLEURS marqueurs. Un sédentaire n'a AUCUN
 * marqueur élevé ; dès qu'un adulte possède un attribut réellement élite, il a franchi un cap que
 * ~90-95% des gens n'atteignent jamais, indépendamment de ses lacunes. La rareté se mesure par le
 * haut. C'est exactement ce que capte une MOYENNE DE PUISSANCE (power mean / Hölder) avec p>1, qui
 * pondère davantage les valeurs hautes (cf. inégalité des moyennes : M_p croît avec p ; p→∞ → max).
 *
 * Mais p>1 seul propulserait aussi un débutant (un attribut un peu moins nul tirerait tout vers le
 * haut). On ajoute donc un GARDE-FOU de cohérence : la composante « top-lourde » n'est mélangée
 * que proportionnellement à la présence d'un attribut RÉELLEMENT élevé (gate sur le max). Un vrai
 * débutant (aucun attribut au-dessus du seuil) reste sur une moyenne ~classique → médiane.
 *
 * Formule (par sexe, sur les attributs débloqués, pondérés par les poids de l'Index — cohérence) :
 *   pi   = popPercentileAttr(i)                         // percentile pop de l'attribut i
 *   Mp   = ( Σ w_i · pi^P ) / ( Σ w_i ) )^(1/P)         // moyenne de puissance, P = TOP_HEAVY_P
 *   Mwa  = ( Σ w_i · pi ) / ( Σ w_i )                   // moyenne pondérée classique (= v1)
 *   g    = clamp01( (max_i pi − GATE_LO) / (GATE_HI − GATE_LO) )   // « as-tu un point fort ? »
 *   pIndex = (1 − g)·Mwa + g·Mp
 * → débutant (max pi bas) : g≈0 → Mwa (médiane, honnête). Athlète à point(s) fort(s) : g≈1 → Mp
 *   (top-lourd, valorise la rareté). Athlète complet : Mwa≈Mp déjà haut → top 1-3%.
 *
 * Calibration (vérifiée dans population-norms.test.ts) :
 *   - sofiane (engine/speed ~0.999, ME/hybrid ~0.98, strength/power ~0.05-0.18) → ~top 6-8%.
 *   - débutant générique (tous attributs 150-300) → reste « en construction » / ~top 45-55%.
 *   - athlète complet (tous 700-900) → ~top 1-3%.
 *   - profil moyen équilibré (tous ~500) → ~top 20-30%.
 *
 * Confiance : `estimate` (chaque ancre est sourcée, l'agrégation reste un modèle assumé). Référence
 * d'âge : adulte ~30-39 ans (l'ajustement fin par tranche d'âge est documenté comme évolution).
 */
export const POPNORM_VERSION = "popnorm-v2";

/**
 * Exposant de la moyenne de puissance (top-lourde). P>1 favorise les attributs élevés.
 * P=5 : un attribut élite (~0.99) domine nettement deux attributs non entraînés (~0.05) sans
 * pour autant ignorer le reste (P→∞ donnerait le pur max, trop binaire). Calibré sur les 4 cibles
 * ci-dessus — notamment le cas sofiane (2 systèmes élite + endurance, force/puissance nulles) qui
 * doit ressortir ~top 8% et non ~top 35%.
 */
const TOP_HEAVY_P = 5;

/**
 * Gate de cohérence anti-débutant : g monte de 0→1 quand le MEILLEUR attribut passe de GATE_LO à
 * GATE_HI (en percentile population). En dessous de GATE_LO (~top 50%, soit un attribut au mieux
 * médian dans la population) on reste sur la moyenne classique → un débutant ne décolle pas. Au
 * dessus de GATE_HI (~top 15%, un attribut clairement au-dessus du tout-venant) la composante
 * top-lourde s'applique pleinement. GATE_LO/HI choisis pour que tous-attributs≈300 (max pop ≈0.55)
 * reste quasi-classique, et qu'un seul attribut élite (≥0.85) débloque la valorisation.
 */
const GATE_LO = 0.55;
const GATE_HI = 0.85;

function clamp01(x: number): number {
  return x < 0 ? 0 : x > 1 ? 1 : x;
}

/** Nœuds {subScore, popP} → PointTableModel exploitable par `percentile()`. */
function table(nodes: ReadonlyArray<readonly [subScore: number, popP: number]>): PointTableModel {
  return { kind: "pointTable", dir: 1, nodes: nodes.map(([r, p]) => ({ p, r })) };
}

/**
 * Tables population par sexe et par attribut (popnorm-v2 ; cf. spec sport-science §2).
 * Chaque ligne = [sousScore, percentilePopulation]. P croissant ⇔ sousScore croissant.
 *
 * RECALIBRAGE v2 du milieu de table (band 350-650). v1 mappait l'utilisateur médian de l'app
 * (sous-score ≈ 450) vers ~top 15-17%, ce qui rendait le bas/median trop généreux une fois
 * combiné à l'agrégation top-lourde (tout le monde « top 10% »). On réaligne sur l'intention
 * documentée : sous-score 450 (médiane COMPÉTITIVE) ≈ top 32-35% de la population générale,
 * 600 ≈ top 12-15%. Le PLANCHER (sédentaires, OMS 2022 : ~27,5% insuffisamment actifs) et le
 * HAUT de table (cardio/force élite à ~0.99) sont conservés depuis v1 : un attribut réellement
 * élite ressort toujours à ~top 1%. Cf. docs/population-norms-sources.md (§ popnorm-v2).
 */
export const POP_NORMS_V1: Record<Sex, Record<AttributeKey, PointTableModel>> = {
  male: {
    // Engine : base la plus « accessible » de la population (marcher/courir un peu existe).
    // 300 = débutant qui finit un metcon scaled ≈ top 45% ; 450 = amateur régulier ≈ top 33%.
    engine: table([
      [150, 0.18], [300, 0.55], [450, 0.67], [600, 0.85], [750, 0.95], [880, 0.985], [950, 0.995],
    ]),
    // Endurance musculaire (pompes/sit-ups) : très clivant — bcp d'adultes < 10 pompes strictes.
    muscular_endurance: table([
      [150, 0.2], [330, 0.57], [450, 0.69], [600, 0.86], [720, 0.95], [850, 0.99], [950, 0.997],
    ]),
    // Force : compétence la PLUS rare dans la population (~3/4 des adultes ne font aucun renfo).
    // 350 (médian compétitif) ≈ top 38% ; 1.0x BW (~500) ≈ top 28% ; 1.5x BW (~700) ≈ top 8%.
    strength: table([
      [150, 0.22], [350, 0.62], [500, 0.72], [680, 0.9], [820, 0.985], [950, 0.998],
    ]),
    power: table([
      [200, 0.25], [360, 0.6], [560, 0.78], [740, 0.93], [880, 0.99], [950, 0.997],
    ]),
    speed: table([
      [200, 0.24], [360, 0.59], [520, 0.74], [700, 0.91], [870, 0.99], [950, 0.997],
    ]),
    hybrid: table([
      [150, 0.2], [350, 0.62], [500, 0.73], [680, 0.9], [820, 0.985], [950, 0.998],
    ]),
  },
  female: {
    engine: table([
      [150, 0.2], [300, 0.57], [450, 0.69], [600, 0.86], [750, 0.955], [880, 0.987], [950, 0.996],
    ]),
    muscular_endurance: table([
      [150, 0.22], [330, 0.59], [450, 0.71], [600, 0.87], [720, 0.955], [850, 0.99], [950, 0.997],
    ]),
    strength: table([
      [150, 0.24], [350, 0.64], [500, 0.74], [680, 0.91], [820, 0.987], [950, 0.998],
    ]),
    power: table([
      [200, 0.27], [360, 0.62], [560, 0.8], [740, 0.94], [880, 0.99], [950, 0.997],
    ]),
    speed: table([
      [200, 0.26], [360, 0.61], [520, 0.76], [700, 0.92], [870, 0.99], [950, 0.997],
    ]),
    hybrid: table([
      [150, 0.22], [350, 0.64], [500, 0.75], [680, 0.91], [820, 0.987], [950, 0.998],
    ]),
  },
};

/** Percentile population pour un attribut donné (fraction d'adultes du même sexe battue). */
export function popPercentileAttr(sex: Sex, attribute: AttributeKey, subScore: number): number {
  return percentile(subScore, POP_NORMS_V1[sex][attribute]);
}

/**
 * Percentile population au niveau de l'Index (popnorm-v2). Agrégation « top-lourde gardée » :
 * mélange entre la moyenne pondérée classique (Mwa, = v1) et une moyenne de puissance top-lourde
 * (Mp, P>1), le mélange étant piloté par un gate `g` sur le MEILLEUR attribut. Voir le rationale
 * en tête de fichier.
 *
 * - Attributs verrouillés exclus (NO-DROP : ne tirent jamais vers le bas).
 * - Poids = mêmes poids que l'Index (cohérence Option B) ; ils pondèrent num ET dénominateur des
 *   deux moyennes, donc le choix d'objectif ne change que la pondération, jamais les sous-scores.
 * - Défaut prudent si aucun attribut débloqué.
 *
 * Propriétés garanties (testées) : monotone (radar meilleur ⇒ p ≥), débutant non propulsé
 * (g≈0 ⇒ Mwa), profil à point(s) fort(s) valorisé (g≈1 ⇒ Mp).
 */
export function popPercentileIndex(
  sex: Sex,
  goal: Goal,
  radar: ReadonlyArray<AttributeResult>,
): number {
  const weights = WEIGHTS_V1[goal];
  const unlocked = radar.filter((a) => a.unlocked);
  if (unlocked.length === 0) return 0.3; // ~top 70% : prudent, jamais dévalorisant

  let den = 0;
  let sumLinear = 0; // Σ w·p        → moyenne pondérée classique
  let sumPow = 0; // Σ w·p^P      → moyenne de puissance top-lourde
  let maxP = 0; // meilleur attribut (pilote le gate)
  for (const a of unlocked) {
    const w = weights[a.attribute];
    const p = popPercentileAttr(sex, a.attribute, a.score);
    den += w;
    sumLinear += w * p;
    sumPow += w * Math.pow(p, TOP_HEAVY_P);
    if (p > maxP) maxP = p;
  }
  if (den <= 0) return 0.3;

  const mwa = sumLinear / den; // = agrégation v1
  const mp = Math.pow(sumPow / den, 1 / TOP_HEAVY_P); // top-lourde ; mp ≥ mwa toujours
  const g = clamp01((maxP - GATE_LO) / (GATE_HI - GATE_LO)); // « as-tu un vrai point fort ? »

  return (1 - g) * mwa + g * mp;
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
