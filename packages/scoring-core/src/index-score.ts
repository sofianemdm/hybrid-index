import type { AttributeKey, Goal } from "@hybrid-index/contracts";
import { normalCdf } from "./math/normal";
import { clampPercentile } from "./distribution";
import { percentileFromInternal, ratingFromInternal, subScoreFromPercentile } from "./curve";
import { WEIGHTS_V1 } from "./weights";
import type { AttributeResult } from "./attribute";

/**
 * Agrégation HYBRID INDEX (cf. sport-science §6) :
 *   INDEX = Σ_{A débloqués} w_A · score(A) / Σ_{A débloqués} w_A
 * - Moyenne pondérée sur les attributs DÉBLOQUÉS uniquement (un verrouillé ne tire pas vers le bas).
 * - `isProvisional` tant que couverture insuffisante (< 3 attributs ET < 3 efforts).
 * - `isEstimated` si au moins un attribut entrant est estimé (proxy Force).
 *
 * COUVERTURE PARTIELLE (cf. sport-science §6) : un seul attribut mesuré ne doit pas produire un
 * Index global égal à cet attribut (trompeur : 5/6 du profil est inconnu). L'absence de mesure
 * n'est pas neutre — son espérance est la médiane population. `coverageAdjustedValue(value, c)`
 * mélange donc, EN ESPACE PERCENTILE, les attributs mesurés avec une baseline médiane pour les NON
 * mesurés, puis re-convertit en valeur interne /1000 :
 *   P_shrunk = (c · P_obs + (N − c) · P_base) / N   →   value_ajustée = subScoreFromPercentile(P_shrunk)
 * À couverture pleine (c = N) le terme baseline s'annule → AUCUN ajustement. À couverture faible,
 * la valeur est tirée vers la médiane et remonte à chaque attribut mesuré.
 *
 * IMPORTANT : `hybridIndex()` renvoie la valeur no-drop PURE (ses tests/le score-service en
 * dépendent). C'est la couche de PERSISTANCE (API `recomputeForUser`) qui applique
 * `coverageAdjustedValue` AVANT de stocker → la valeur stockée (= clé de tri Redis/PG, affichage,
 * rang, badges) est l'Index ajusté, UNIQUE source de vérité, cohérente entre classement et OVR.
 */

export const INDEX_MU = 450;
export const INDEX_SIGMA = 140;
export const PROVISIONAL_MIN_ATTRIBUTES = 3;
export const PROVISIONAL_MIN_EFFORTS = 3;
/** Nombre total d'attributs du radar (dénominateur du shrinkage de couverture). */
export const RADAR_ATTRIBUTE_COUNT = 6;
/** Baseline = médiane population (percentile 0.5) présumée pour un attribut non mesuré. */
export const SHRINK_P_BASE = 0.5;

export interface IndexResult {
  /** Valeur interne [0,1000] (cœur de calcul, clé de tri des classements). NE PAS afficher. */
  value: number;
  /** Note d'AFFICHAGE /100 « type FIFA » (1 décimale), ou null si non mesuré (couverture 0). */
  rating: number | null;
  /** Note d'affichage arrondie à l'entier (l'OVR montré à l'utilisateur), ou null si non mesuré. */
  ratingInt: number | null;
  percentile: number;
  isProvisional: boolean;
  isEstimated: boolean;
  radarCoverage: number;
}

/**
 * Note d'affichage /100 de l'INDEX à partir de la valeur interne /1000 et de la couverture du
 * radar. Applique le shrinkage de couverture (display-v2) : à couverture faible, l'Index affiché
 * est tiré vers la médiane ; à couverture complète il rejoint la note no-drop. À utiliser PARTOUT
 * où l'on affiche l'Index (profil, classement, clubs, badges) pour rester cohérent — JAMAIS pour
 * un sous-score de WOD ou un attribut isolé (eux gardent `ratingFromInternal`).
 */
export function coverageAdjustedValue(value: number, coverage: number): number {
  const c = Math.max(0, Math.min(coverage, RADAR_ATTRIBUTE_COUNT));
  if (c >= RADAR_ATTRIBUTE_COUNT || c <= 0) return value; // 6/6 → aucun shrinkage ; 0 → value (0) tel quel
  const pObs = percentileFromInternal(value);
  const pShrunk = (c * pObs + (RADAR_ATTRIBUTE_COUNT - c) * SHRINK_P_BASE) / RADAR_ATTRIBUTE_COUNT;
  return subScoreFromPercentile(pShrunk); // re-convertit en valeur interne /1000 (clé de tri cohérente)
}

/** Note d'affichage /100 d'une valeur interne /1000 (null si non mesuré). PURE : pas de shrinkage
 *  ici — l'ajustement de couverture est déjà appliqué à la valeur stockée via `coverageAdjustedValue`. */
function display(value: number, coverage: number): { rating: number | null; ratingInt: number | null } {
  if (coverage === 0) return { rating: null, ratingInt: null };
  const rating = ratingFromInternal(value);
  return { rating, ratingInt: Math.round(rating) };
}

/** Percentile de l'Index dans la distribution par sexe N(450,140) (initial, à recalibrer). */
export function indexPercentile(value: number): number {
  return clampPercentile(normalCdf((value - INDEX_MU) / INDEX_SIGMA));
}

export function hybridIndex(
  radar: ReadonlyArray<AttributeResult>,
  goal: Goal,
  totalValidEfforts: number,
): IndexResult {
  const weights = WEIGHTS_V1[goal];
  const unlocked = radar.filter((a) => a.unlocked);
  const coverage = unlocked.length;

  if (coverage === 0) {
    return { value: 0, ...display(0, 0), percentile: indexPercentile(0), isProvisional: true, isEstimated: false, radarCoverage: 0 };
  }

  let num = 0;
  let den = 0;
  for (const a of unlocked) {
    const w = weights[a.attribute];
    num += w * a.score;
    den += w;
  }
  // Robustesse : impossible avec weights-v1 (min 0.7), mais protège des futures versions de poids.
  if (den <= 0) {
    return { value: 0, ...display(0, 0), percentile: indexPercentile(0), isProvisional: true, isEstimated: false, radarCoverage: coverage };
  }
  const value = Math.round(num / den);

  const isProvisional = !(coverage >= PROVISIONAL_MIN_ATTRIBUTES || totalValidEfforts >= PROVISIONAL_MIN_EFFORTS);
  const isEstimated = unlocked.some((a) => a.isEstimated);

  return { value, ...display(value, coverage), percentile: indexPercentile(value), isProvisional, isEstimated, radarCoverage: coverage };
}

/**
 * Index projeté (cf. sport-science §6 / cahier §4.3) : Index simulé si l'attribut `target`
 * atteignait `targetScore`. Honnête : c'est une simulation, jamais l'Index réel.
 * Déviation intentionnelle de la formule littérale : on applique `max(score actuel, cible)` pour
 * que la projection ne descende jamais sous l'Index réel (cohérent avec l'esprit no-drop / D3).
 */
export function projectedIndex(
  radar: ReadonlyArray<AttributeResult>,
  goal: Goal,
  target: AttributeKey,
  targetScore: number,
  totalValidEfforts: number,
): IndexResult {
  const has = radar.some((a) => a.attribute === target);
  const simulated: AttributeResult[] = has
    ? radar.map((a) =>
        a.attribute === target
          ? { ...a, score: Math.max(a.score, targetScore), unlocked: true }
          : a,
      )
    : [
        ...radar,
        { attribute: target, score: targetScore, unlocked: true, isEstimated: false, isStale: false, bestAgeWeeks: 0 },
      ];
  // Débloquer l'attribut cible compte comme un effort de plus pour la règle « provisoire ».
  const efforts = has ? totalValidEfforts : totalValidEfforts + 1;
  return hybridIndex(simulated, goal, efforts);
}
