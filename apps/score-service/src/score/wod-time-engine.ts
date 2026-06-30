import { MOVEMENTS_BY_ID, type MovementDef } from "../wods/movements.data";
import type { AttributeKey, Sex } from "@hybrid-index/contracts";
import { percentileFromInternal } from "@hybrid-index/scoring-core";

/**
 * Moteur de temps PAR MOUVEMENT (sport-science) — socle unique de l'estimation.
 *
 * Ce module extrait la mécanique qui vivait inline dans `computeEstimate` (scoring.service.ts) afin
 * qu'UNE SEULE implémentation (cadence × charge × fatigue × coupures × transitions × dégradation
 * inter-tours) serve à la fois la création de WOD custom (mode « niveau ») ET, à terme, la
 * prédiction du temps d'un benchmark pour un athlète réel (mode « athlète », Inc. 2).
 *
 * GARDE-FOU INC. 1 — ISO-COMPORTEMENT : ce fichier ne fait que DÉPLACER la logique existante. Le
 * mode `level` reproduit à l'identique les sorties de `computeEstimate`. La pénalité de charge
 * relative, la capacité par mouvement et la sortie en fourchette arriveront à l'Inc. 2 — ici on ne
 * change AUCUNE valeur.
 *
 * SÉPARATION ESTIMATION ≠ NOTATION : ce moteur ne touche jamais `computeIndex` / `scoreResult` /
 * les distributions `bySex.model` utilisées pour NOTER un résultat réel. Il ne produit que des
 * estimations de temps/volume.
 */

/** Un bloc résolu prêt pour le moteur : mouvement validé + quantité native + charge éventuelle. */
export interface ResolvedBlock {
  movement: MovementDef;
  /** Quantité native (reps OU mètres OU calories OU secondes selon `movement.unit`). */
  amount: number;
  /** Charge externe en kg (mouvements chargés). Absente ⇒ pas de pénalité de charge. */
  loadKg?: number;
  /**
   * Bloc « non compté » dans le SCORE (mais compté dans le TEMPS du tour) : ex. la course imposée
   * d'un AMRAP « course + reps » où seules les reps sont scorées (Le Moteur). Le bloc prend du temps
   * (`roundTimeSec`) mais n'entre PAS dans le `workPerRound` (volume scoré). Sans effet sur les WODs
   * « for time » (où le score EST le temps). Défaut : compté.
   */
  unscored?: boolean;
}

/** Poids de corps de réf par sexe (kg) — sert au 1RM estimé et à la charge Rx de réf. */
const BODYWEIGHT: Record<Sex, number> = { male: 80, female: 65 };

/** Constantes de format calibrées sport-science (23 juin). Conservées telles quelles en Inc. 1. */
export const TRANSITION_SEC = 3.5; // s entre deux blocs
export const BREAK_SEC = { champion: 3.0, intermediate: 3.0, occasional: 4.0 } as const; // pause/coupure
export const ROUND_DECAY = { champion: 0.08, intermediate: 0.06, occasional: 0.04 } as const; // inter-tours

export type Level = "champion" | "intermediate" | "occasional";

/** Scores d'attribut /1000 de l'athlète (sous-scores internes), pour le mode « athlète ». */
export type AttrScores = Partial<Record<AttributeKey, number>>;

/**
 * Mode « cadence » :
 *  - `level` : niveau discret (création de WOD custom) → `movement.rate[level][sex]` (historique).
 *  - `athlete` : on lit la cadence au PERCENTILE DE CAPACITÉ DU MOUVEMENT (B.2) et on applique la
 *    PÉNALITÉ DE CHARGE RELATIVE (B.3, 1RM estimé via la FORCE) → temps réaliste pour CET athlète.
 */
export type PaceMode = { kind: "level"; level: Level } | { kind: "athlete"; scores: AttrScores };

/**
 * Résolveur de débit (unité/s) pour un mouvement donné, sous le mode de cadence courant. En mode
 * `level` : `movement.rate[level][sex]` (comportement historique). En mode `athlete` : le débit lu
 * au percentile de capacité du mouvement (B.2).
 */
export type RateResolver = (movement: MovementDef, sex: Sex, pace: PaceMode) => number;

/** Résolveur de charge par défaut : `movement.rate[level][sex]` (mode niveau) ou cadence athlète. */
export const defaultRateResolver: RateResolver = (movement, sex, pace) =>
  pace.kind === "level" ? movement.rate[pace.level][sex] : athleteRate(movement, sex, pace.scores);

// ───────────────────────────────────────────────────────────────────────────────────────────────
// MODE ATHLÈTE — capacité par mouvement (B.2) + pénalité de charge relative (B.3)
// Calibré (sport-science, 30 juin) sur les benchmarks : Fran H, profil « soso » (force 661 /
// power 737 / ME 971, 40 kg) → ~9m47, élite rapide, débutant lent, monotonie par niveau préservée.
// SÉPARATION ESTIMATION ≠ NOTATION : tout ce bloc ne sert QUE l'estimation de temps ; il ne touche
// jamais `computeIndex` / `scoreResult` / `bySex.model`.
// ───────────────────────────────────────────────────────────────────────────────────────────────

/** Pénalité de charge : seuil sous lequel la charge est neutre (≈ travail léger / sous-Rx). */
export const LOAD_NEUTRAL_X = 0.35;
/** Plafond du multiplicateur de cadence à charge quasi-maximale (1 rep ≈ 1 mini-série). */
export const LOAD_MULT_MAX = 6.5;
/** Raideur (A) et exposant (q) de la montée de la pénalité de charge sur [LOAD_NEUTRAL_X, 1]. */
const LOAD_MULT_A = 4.8;
const LOAD_MULT_Q = 2.0;
/** Saturation de la forme rationnelle (asymptote en u → 1/SAT). */
const LOAD_MULT_SAT = 0.85;

/**
 * Multiplicateur de cadence dû à la charge relative `x = loadKg / 1RM_estimé`. Forme CONTINUE,
 * CROISSANTE et BORNÉE (B.3) : neutre sous `LOAD_NEUTRAL_X`, puis montée rationnelle qui s'effondre
 * (le temps par rep explose) quand x → 1, plafonnée à `LOAD_MULT_MAX`. Pas de pôle interne (forme
 * lisse, robuste aux petites variations de 1RM, contrairement à `((x-0.6)/(0.9-x))²`).
 */
export function loadMult(x: number): number {
  if (!Number.isFinite(x) || x <= LOAD_NEUTRAL_X) return 1;
  const u = Math.min(1, (x - LOAD_NEUTRAL_X) / (1 - LOAD_NEUTRAL_X)); // 0 à x0 → 1 à x=1
  const m = 1 + (LOAD_MULT_A * Math.pow(u, LOAD_MULT_Q)) / (1 - LOAD_MULT_SAT * u);
  return Math.min(LOAD_MULT_MAX, m);
}

/**
 * 1RM de RÉFÉRENCE ÉLITE par mouvement chargé, en fraction du poids de corps de réf (B.3/B.4). La
 * charge max est une qualité de FORCE pure → on échelonne par le percentile de force (`strScale`),
 * pas par la capacité (mix d'attributs) du mouvement. Mouvements ABSENTS = pas de pénalité relative
 * (charge légère traitée comme neutre par `loadMult`, x faible).
 */
export const ELITE_1RM_FACTOR: Readonly<Record<string, number>> = {
  thruster: 0.94,
  thruster_db: 0.94,
  clean_and_jerk: 1.5,
  clean: 1.5,
  snatch: 1.1,
  deadlift: 2.4,
  front_squat: 1.7,
  overhead_squat: 1.2,
  shoulder_to_overhead: 1.2,
  kettlebell_swing: 0.55,
  wall_ball: 0.3,
};

/**
 * Échelle du 1RM par le percentile de FORCE de l'athlète : monotone, bornée, calibrée pour que la
 * référence (p≈0.98) atteigne le 1RM élite et qu'un athlète moyen (p≈0.5) tourne à ~0.58 de l'élite.
 */
export function strScale(pStr: number): number {
  const nodes: Array<[number, number]> = [
    [0.0, 0.3],
    [0.15, 0.4],
    [0.5, 0.58],
    [0.98, 1.0],
    [1.0, 1.04],
  ];
  const p = Math.max(0, Math.min(1, pStr));
  for (let i = 0; i < nodes.length - 1; i++) {
    const [p1, v1] = nodes[i];
    const [p2, v2] = nodes[i + 1];
    if (p <= p2) return v1 + ((p - p1) / (p2 - p1)) * (v2 - v1);
  }
  return nodes[nodes.length - 1][1];
}

/** Capacité spécifique au mouvement (0-1000) : Σ poids·score sur les attributs du mouvement (B.2). */
export function movementCapacity(m: MovementDef, scores: AttrScores): number {
  let cap = 0;
  let wTot = 0;
  for (const a of m.attributes) {
    const s = scores[a.attribute];
    if (s === undefined) continue;
    cap += a.weight * s;
    wTot += a.weight;
  }
  // Si certains attributs manquent, on renormalise sur ceux disponibles (jamais de capacité gonflée).
  return wTot > 0 ? cap / wTot : 0;
}

/**
 * Cadence soutenable (unité/s) de CET athlète sur CE mouvement (B.2) : on lit `m.rate` au percentile
 * de capacité du mouvement, par interpolation LOG-LINÉAIRE sur les 3 nœuds calibrés
 * (occasional≈P0.15, intermediate≈P0.5, champion≈P0.98), extrapolation BORNÉE aux extrêmes.
 */
export function athleteRate(m: MovementDef, sex: Sex, scores: AttrScores): number {
  const p = Math.max(0.02, Math.min(0.999, percentileFromInternal(movementCapacity(m, scores))));
  const nodes: Array<[number, number]> = [
    [0.15, m.rate.occasional[sex]],
    [0.5, m.rate.intermediate[sex]],
    [0.98, m.rate.champion[sex]],
  ];
  const logInterp = (p1: number, r1: number, p2: number, r2: number, at: number) =>
    Math.exp(Math.log(r1) + ((at - p1) / (p2 - p1)) * (Math.log(r2) - Math.log(r1)));
  if (p <= nodes[0][0]) return logInterp(nodes[0][0], nodes[0][1], nodes[1][0], nodes[1][1], p);
  for (let i = 0; i < nodes.length - 1; i++) {
    if (p <= nodes[i + 1][0]) return logInterp(nodes[i][0], nodes[i][1], nodes[i + 1][0], nodes[i + 1][1], p);
  }
  return logInterp(nodes[1][0], nodes[1][1], nodes[2][0], nodes[2][1], p);
}

/**
 * 1RM estimé (kg) de l'athlète sur un mouvement chargé : `ELITE_1RM_FACTOR · BW · strScale(p_force)`
 * (B.3). Renvoie `null` si le mouvement n'a pas de référence élite (→ pas de pénalité relative).
 */
export function estimateOneRepMax(m: MovementDef, sex: Sex, scores: AttrScores): number | null {
  const factor = ELITE_1RM_FACTOR[m.id];
  if (!factor) return null;
  const strength = scores.strength ?? 0;
  return factor * BODYWEIGHT[sex] * strScale(percentileFromInternal(strength));
}

export interface BlockLineCost {
  attrs: MovementDef["attributes"];
  cost: number;
}

export interface EstimateBlocksResult {
  /** Temps d'UN tour (transitions incluses), en secondes. */
  roundTimeSec: number;
  /** Travail natif agrégé d'un tour (reps + mètres + calories + secondes), pour les formats AMRAP. */
  workPerRound: number;
  /** Coût et attributs par ligne (pour la répartition d'attributs / attrShare). */
  lineCosts: BlockLineCost[];
}

/**
 * Coûte UN tour des blocs fournis sous une cadence donnée. Reproduit EXACTEMENT la boucle interne
 * de `computeEstimate` (cf. scoring.service.ts, modèle de temps recalibré 23 juin) :
 *  - course/sprint en mètres : Riegel ;
 *  - maintien (unit second) : durée directe ;
 *  - sinon : (amount / rate) × loadMult × fatMult + coupures × BREAK_SEC.
 *
 * Le `workPerRound` agrège toutes les unités natives (reps + cal + sec + mètres) comme l'original,
 * pour que les AMRAP cardio (course/cal/temps) ne dégénèrent pas à 0.
 */
export function estimateRound(blocks: ResolvedBlock[], sex: Sex, pace: PaceMode, rateResolver: RateResolver = defaultRateResolver): EstimateBlocksResult {
  const BW = BODYWEIGHT[sex];
  let roundTime = 0;
  let workPerRound = 0;
  const lineCosts: BlockLineCost[] = [];

  for (const block of blocks) {
    const m = block.movement;
    const rate = rateResolver(m, sex, pace);
    const amount = block.amount;
    let cost: number;
    if (m.unit === "second") {
      cost = amount; // maintien : durée directe
    } else if (m.unit === "meter" && (m.id === "run" || m.id === "sprint")) {
      cost = (amount / rate) * Math.pow(Math.max(amount, 1) / 400, 0.06); // Riegel
    } else if (m.category === "monostructural" && (m.unit === "meter" || m.unit === "calorie")) {
      // Cardio CONTINU (rameur/ski/bike en mètres ou calories) : effort tenu, PAS de coupures de
      // « série » ni de fatigue par-reps (sinon 2000 m de rameur = 166 fausses pauses). Mêmes
      // mécaniques que run/sprint (cadence soutenable) : coût = distance|cal / débit. Riegel léger
      // sur les mètres (allure qui dérive sur la durée), neutre sur les calories.
      const drift = m.unit === "meter" ? Math.pow(Math.max(amount, 1) / 400, 0.06) : 1;
      cost = (amount / rate) * drift;
    } else {
      // PÉNALITÉ DE CHARGE — deux modes :
      //  • level (custom WOD) : iso-comportement historique (pénalité au-dessus de la charge Rx de
      //    réf ; sous-Rx = pas de bonus). maxSet figé, BREAK_SEC par niveau.
      //  • athlete (prédiction benchmark, B.3) : charge RELATIVE au 1RM estimé de l'athlète. La
      //    cadence s'effondre quand x → 1 ET la série max chute (plus de coupures) → réalisme du
      //    « 40 kg trop lourd ». BREAK_SEC athlète figé (4 s) : pas de niveau discret.
      const maxSet = m.maxSet ?? 12;
      let chargeMult: number;
      let effectiveMaxSet: number;
      let breakSec: number;
      if (pace.kind === "athlete") {
        const oneRm = block.loadKg ? estimateOneRepMax(m, sex, pace.scores) : null;
        if (block.loadKg && oneRm && oneRm > 0) {
          const x = block.loadKg / oneRm; // % de la capacité max sollicité à chaque rep
          chargeMult = loadMult(x);
          // Plus la charge est lourde (x↑), plus la série tenable chute → davantage de coupures.
          effectiveMaxSet = Math.max(1, Math.round(maxSet * Math.max(0.15, Math.min(1, 1.1 - x))));
        } else {
          chargeMult = 1;
          effectiveMaxSet = maxSet;
        }
        breakSec = 4;
      } else {
        const refLoad = m.loadFactor ? m.loadFactor * BW : 0;
        chargeMult = block.loadKg && refLoad > 0 ? 1 + 0.6 * Math.max(0, block.loadKg / refLoad - 1) : 1;
        effectiveMaxSet = maxSet;
        breakSec = BREAK_SEC[pace.level];
      }
      // Fatigue : courbe de puissance bornée à 1 (plus de « remise » absurde pour les petites séries).
      const fatMult = Math.max(1, Math.pow(amount / 15, m.fatigueExponent - 1));
      // Coupures de série implicites (on ne tient pas 30 répétitions d'affilée).
      const breaks = amount > 0 ? Math.floor((amount - 1) / effectiveMaxSet) : 0;
      cost = (amount / rate) * chargeMult * fatMult + breaks * breakSec;
    }
    roundTime += cost;
    lineCosts.push({ attrs: m.attributes, cost });
    // Travail natif du tour : agrège reps + cal + sec + mètres (ordre d'origine préservé). Un bloc
    // `unscored` (course imposée d'un AMRAP scoré en reps) prend du TEMPS mais n'entre PAS dans le
    // volume scoré → sinon le 400 m gonflerait les « reps » prédites (Le Moteur).
    if (!block.unscored) workPerRound += block.amount;
  }
  roundTime += Math.max(0, blocks.length - 1) * TRANSITION_SEC; // transitions entre blocs
  return { roundTimeSec: roundTime, workPerRound, lineCosts };
}

/**
 * Temps total « pour le temps » sur `rounds` tours, avec dégradation inter-tours :
 * Σ_{i=0..rounds-1} roundTime · (1 + decay·i). Reproduit le calcul d'origine.
 */
export function totalTimeForRounds(roundTimeSec: number, rounds: number, level: Level): number {
  let mult = 0;
  for (let i = 0; i < rounds; i++) mult += 1 + ROUND_DECAY[level] * i;
  return roundTimeSec * mult;
}

/**
 * Volume « AMRAP » : nombre de tours tenables dans le cap × travail natif par tour. Clamp final
 * identique à l'original (au moins 1 unité de travail, jamais 0/NaN).
 */
export function totalVolumeForCap(roundTimeSec: number, workPerRound: number, timeCapSec: number): number {
  const rounds = timeCapSec / Math.max(roundTimeSec, 1);
  return Math.max(1, Math.round(rounds * Math.max(workPerRound, 1)));
}

/** Résout un bloc d'entrée (movementId + quantité native) en `ResolvedBlock`. */
export function resolveBlock(movementId: string, amount: number, loadKg?: number): ResolvedBlock | null {
  const movement = MOVEMENTS_BY_ID.get(movementId);
  if (!movement) return null;
  return { movement, amount, loadKg };
}

// ───────────────────────────────────────────────────────────────────────────────────────────────
// PRÉDICTION BENCHMARK (mode athlète) — décomposition TOUR PAR TOUR (B.1/B.5/B.7)
// ───────────────────────────────────────────────────────────────────────────────────────────────

/** Un mouvement d'un blueprint résolu : reps PAR TOUR + charge éventuelle (kg, déjà par sexe). */
export interface ResolvedBlueprintBlock {
  movement: MovementDef;
  /** Reps (ou mètres/cal selon l'unité) par tour. La longueur fixe le nombre de tours. */
  repsPerRound: number[];
  loadKg?: number;
  /** Bloc compté au TEMPS mais PAS au volume scoré (course imposée d'un AMRAP reps, cf. Le Moteur). */
  unscored?: boolean;
}

/**
 * Estime le temps d'un benchmark décomposé en blocs canoniques, TOUR PAR TOUR, en mode ATHLÈTE.
 *
 * Pour chaque tour `i`, on coûte chaque mouvement à sa cadence athlète (B.2) avec la pénalité de
 * charge relative (B.3), on ajoute les transitions, puis on applique la dégradation inter-tours
 * `(1 + decay·i)` — décay fixe (0.06, équivalent « intermediate ») car le mode athlète n'a pas de
 * niveau discret. Le découpage par tour (et non un bloc plat) est nécessaire car les reps varient
 * d'un tour à l'autre (Fran 21-15-9).
 *
 * SÉPARATION ESTIMATION ≠ NOTATION : ne touche jamais l'Index ni `bySex.model`.
 */
export const ATHLETE_ROUND_DECAY = 0.06;

export function estimateBlueprintTime(blocks: ResolvedBlueprintBlock[], sex: Sex, scores: AttrScores): number {
  if (blocks.length === 0) return 0;
  const rounds = Math.max(...blocks.map((b) => b.repsPerRound.length));
  const pace: PaceMode = { kind: "athlete", scores };
  let total = 0;
  for (let i = 0; i < rounds; i++) {
    // Blocs présents à ce tour (un mouvement peut avoir moins de tours que le max → ignoré au-delà).
    const roundBlocks: ResolvedBlock[] = blocks
      .filter((b) => i < b.repsPerRound.length)
      .map((b) => ({ movement: b.movement, amount: b.repsPerRound[i], loadKg: b.loadKg, unscored: b.unscored }));
    const { roundTimeSec } = estimateRound(roundBlocks, sex, pace);
    total += roundTimeSec * (1 + ATHLETE_ROUND_DECAY * i);
  }
  return total;
}

/**
 * Estime le VOLUME d'un AMRAP en mode athlète : nb de tours tenables dans le cap. Le tour AMRAP est
 * unique (repsPerRound[0]). `scoreUnit` :
 *  - `"rounds"` : nombre de tours complets (ex. Cindy, scoré en tours) ;
 *  - `"reps"` (défaut) : tours × travail natif par tour (reps + cal + m + s agrégés).
 */
export function estimateBlueprintVolume(
  blocks: ResolvedBlueprintBlock[],
  sex: Sex,
  scores: AttrScores,
  timeCapSec: number,
  scoreUnit: "rounds" | "reps" = "reps",
): number {
  if (blocks.length === 0) return 1;
  const roundBlocks: ResolvedBlock[] = blocks.map((b) => ({ movement: b.movement, amount: b.repsPerRound[0], loadKg: b.loadKg, unscored: b.unscored }));
  const { roundTimeSec, workPerRound } = estimateRound(roundBlocks, sex, { kind: "athlete", scores });
  if (scoreUnit === "rounds") {
    return Math.max(1, Math.round(timeCapSec / Math.max(roundTimeSec, 1)));
  }
  return totalVolumeForCap(roundTimeSec, workPerRound, timeCapSec);
}

// ─────────────────────────────────────────────────────────────────────────────────────────────
// INC. 3 — INCERTITUDE → FOURCHETTE (B.6)
//
// L'estimation est un POINT central (mid) ; on l'enveloppe d'une fourchette [low, high] dont la
// largeur dépend de la CONFIANCE. Plus l'athlète a d'attributs ESTIMÉS (verrouillés) sur les
// mouvements du WOD, et plus le WOD comporte de blocs CHARGÉS (charge relative = source d'erreur
// principale), plus l'incertitude est grande → fourchette large, confiance basse.
//
// Cette enveloppe est purement DESCRIPTIVE : elle ne change ni le mid (predictedRaw, rétro-compat
// aller-retour), ni la notation. SÉPARATION ESTIMATION ≠ NOTATION préservée.
// ─────────────────────────────────────────────────────────────────────────────────────────────

export type PredictionConfidence = "low" | "medium" | "high";

/** Demi-largeur relative de la fourchette par niveau de confiance (mid·(1±spread)). */
export const SPREAD_BY_CONFIDENCE: Readonly<Record<PredictionConfidence, number>> = {
  high: 0.08, // ±8 %  : mouvements connus, peu/pas de charge, attributs solides
  medium: 0.14, // ±14 % : profil partiel ou WOD chargé (charge relative = bruit)
  low: 0.22, // ±22 % : couverture faible (attributs estimés et/ou plusieurs blocs chargés)
};

/**
 * Détermine la confiance d'une estimation par blueprint à partir de :
 *  - `coverage` : fraction des blocs dont TOUS les attributs pertinents sont DÉBLOQUÉS (estimés
 *    réellement, pas extrapolés) — un attribut verrouillé sur un mouvement = bruit ;
 *  - `chargedBlocks` : nb de blocs chargés (la pénalité de charge relative, B.3, est le terme le
 *    plus sensible : un 1RM mal estimé déplace fortement le temps).
 *
 * Heuristique bornée (calibrable) : couverture pleine + au plus 1 bloc chargé ⇒ `high` ;
 * couverture partielle OU ≥3 blocs chargés ⇒ `low` ; entre les deux ⇒ `medium`.
 */
export function predictionConfidence(coverage: number, chargedBlocks: number): PredictionConfidence {
  if (coverage >= 0.999 && chargedBlocks <= 1) return "high";
  if (coverage < 0.5 || chargedBlocks >= 3) return "low";
  return "medium";
}

/**
 * Calcule la couverture (∈ [0,1]) d'un blueprint pour un athlète : fraction des blocs dont CHAQUE
 * attribut pondéré du mouvement est débloqué chez l'athlète. `unlockedAttrs` = set des attributs
 * réellement estimés. Un bloc à attribut manquant compte comme NON couvert (incertitude accrue).
 */
export function blueprintCoverage(blocks: ResolvedBlueprintBlock[], unlockedAttrs: ReadonlySet<AttributeKey>): number {
  if (blocks.length === 0) return 1;
  let covered = 0;
  for (const b of blocks) {
    const attrs = b.movement.attributes ?? [];
    const allUnlocked = attrs.length > 0 && attrs.every((a) => unlockedAttrs.has(a.attribute));
    if (allUnlocked) covered++;
  }
  return covered / blocks.length;
}
