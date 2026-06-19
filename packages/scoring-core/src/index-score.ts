import type { AttributeKey, Goal } from "@hybrid-index/contracts";
import { normalCdf } from "./math/normal";
import { clampPercentile } from "./distribution";
import { WEIGHTS_V1 } from "./weights";
import type { AttributeResult } from "./attribute";

/**
 * Agrégation HYBRID INDEX (cf. sport-science §6) :
 *   INDEX = Σ_{A débloqués} w_A · score(A) / Σ_{A débloqués} w_A
 * - Moyenne pondérée sur les attributs DÉBLOQUÉS uniquement (un verrouillé ne tire pas vers le bas).
 * - `isProvisional` tant que couverture insuffisante (< 4 attributs ET < 3 efforts).
 * - `isEstimated` si au moins un attribut entrant est estimé (proxy Force).
 */

export const INDEX_MU = 450;
export const INDEX_SIGMA = 140;
export const PROVISIONAL_MIN_ATTRIBUTES = 4;
export const PROVISIONAL_MIN_EFFORTS = 3;

export interface IndexResult {
  value: number;
  percentile: number;
  isProvisional: boolean;
  isEstimated: boolean;
  radarCoverage: number;
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
    return { value: 0, percentile: indexPercentile(0), isProvisional: true, isEstimated: false, radarCoverage: 0 };
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
    return { value: 0, percentile: indexPercentile(0), isProvisional: true, isEstimated: false, radarCoverage: coverage };
  }
  const value = Math.round(num / den);

  const isProvisional = !(coverage >= PROVISIONAL_MIN_ATTRIBUTES || totalValidEfforts >= PROVISIONAL_MIN_EFFORTS);
  const isEstimated = unlocked.some((a) => a.isEstimated);

  return { value, percentile: indexPercentile(value), isProvisional, isEstimated, radarCoverage: coverage };
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
