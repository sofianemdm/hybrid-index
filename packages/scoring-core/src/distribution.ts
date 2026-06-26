import { normalCdf, normInv } from "./math/normal";
import { type CurveParams, SIGMOID_V1, subScoreFromPercentile } from "./curve";

/**
 * Distributions de référence par sexe + fonction percentile (cf. sport-science §3).
 * `dir` encode le sens : -1 = plus bas meilleur (temps), +1 = plus haut meilleur (reps/charge/distance).
 */
export type Direction = -1 | 1;

export interface LognormalModel {
  kind: "lognormal";
  muLn: number;
  sigmaLn: number;
  dir: Direction;
}
export interface NormalModel {
  kind: "normal";
  mu: number;
  sigma: number;
  dir: Direction;
}
export interface PointTableNode {
  p: number;
  r: number;
}
export interface PointTableModel {
  kind: "pointTable";
  /** Nœuds {P → R}, P croissant. R monotone (décroissant si dir=-1, croissant si dir=+1). */
  nodes: ReadonlyArray<PointTableNode>;
  dir: Direction;
}

export type DistributionModel = LognormalModel | NormalModel | PointTableModel;

export const P_MIN = 0.001;
export const P_MAX = 0.999;

export function clampPercentile(p: number): number {
  if (Number.isNaN(p)) return P_MIN;
  return Math.min(P_MAX, Math.max(P_MIN, p));
}

/** Construit les paramètres log à partir d'une médiane (= exp(µ_ln)) et d'un σ_ln. */
export function lognormalFromMedian(median: number, sigmaLn: number, dir: Direction = -1): LognormalModel {
  return { kind: "lognormal", muLn: Math.log(median), sigmaLn, dir };
}

/**
 * Percentile P ∈ (0,1) : fraction de la population de même sexe battue par le résultat R.
 * Toujours clampé dans [P_MIN, P_MAX] (évite les sous-scores dégénérés 0/1000).
 */
export function percentile(r: number, model: DistributionModel): number {
  switch (model.kind) {
    case "lognormal": {
      if (r <= 0) return model.dir === -1 ? P_MAX : P_MIN;
      const z = (Math.log(r) - model.muLn) / model.sigmaLn;
      const p = model.dir === -1 ? 1 - normalCdf(z) : normalCdf(z);
      return clampPercentile(p);
    }
    case "normal": {
      const z = (r - model.mu) / model.sigma;
      const p = model.dir === 1 ? normalCdf(z) : 1 - normalCdf(z);
      return clampPercentile(p);
    }
    case "pointTable":
      return clampPercentile(invertPointTable(r, model));
  }
}

/**
 * Quantile : INVERSE de `percentile()`. Étant donné un percentile P ∈ (0,1), renvoie le résultat
 * brut R correspondant pour ce modèle/sexe. Respecte `dir` exactement comme `percentile()` :
 * dir=-1 (temps : plus bas meilleur) → P haut donne R petit ; dir=+1 (reps/charge/distance) →
 * P haut donne R grand. P est clampé dans [P_MIN, P_MAX] (cohérent avec `percentile`). Sert à
 * PRÉDIRE le temps/reps qu'un athlète ferait, à partir de son percentile courant.
 *
 * Propriété de réciprocité : `quantile(percentile(r)) ≈ r` (à la précision de l'inverse normale,
 * et tant que r n'est pas clampé par P_MIN/P_MAX). Le clamp aux bornes physiologiques
 * [hardMin, hardMax] reste à la charge de l'appelant (le modèle ne les connaît pas).
 */
export function quantile(p: number, model: DistributionModel): number {
  const pc = clampPercentile(p);
  switch (model.kind) {
    case "lognormal": {
      // percentile : P = dir===-1 ? 1-Φ(z) : Φ(z), avec z = (ln R − µ)/σ.
      // Inverse : z = dir===-1 ? Φ⁻¹(1−P) : Φ⁻¹(P), puis R = exp(µ + σ·z).
      const z = model.dir === -1 ? normInv(1 - pc) : normInv(pc);
      return Math.exp(model.muLn + model.sigmaLn * z);
    }
    case "normal": {
      // percentile : P = dir===1 ? Φ(z) : 1-Φ(z), avec z = (R − µ)/σ.
      // Inverse : z = dir===1 ? Φ⁻¹(P) : Φ⁻¹(1−P), puis R = µ + σ·z.
      const z = model.dir === 1 ? normInv(pc) : normInv(1 - pc);
      return model.mu + model.sigma * z;
    }
    case "pointTable":
      return interpPointTable(pc, model);
  }
}

/** Sous-score [0,1000] complet : R → percentile → courbe f. */
export function subScore(
  r: number,
  model: DistributionModel,
  curve: CurveParams = SIGMOID_V1,
): number {
  return subScoreFromPercentile(percentile(r, model), curve);
}

/**
 * Inversion monotone d'une table de points (interpolation linéaire en P,
 * extrapolation linéaire bornée au-delà des nœuds extrêmes).
 */
function invertPointTable(r: number, model: PointTableModel): number {
  const nodes = [...model.nodes].sort((a, b) => a.p - b.p);
  if (nodes.length < 2) {
    throw new Error("pointTable: au moins 2 nœuds requis");
  }
  const decreasing = nodes[0].r > nodes[nodes.length - 1].r; // dir=-1 (temps)

  // Recherche du segment encadrant R (en tenant compte du sens de R vs P).
  for (let i = 0; i < nodes.length - 1; i++) {
    const a = nodes[i];
    const b = nodes[i + 1];
    const lo = Math.min(a.r, b.r);
    const hi = Math.max(a.r, b.r);
    if (r >= lo && r <= hi) {
      const t = (r - a.r) / (b.r - a.r); // b.r - a.r ≠ 0 (R strictement monotone)
      return a.p + t * (b.p - a.p);
    }
  }

  // Hors plage → extrapolation linéaire bornée depuis le segment extrême adéquat.
  const first = nodes[0];
  const second = nodes[1];
  const lastM1 = nodes[nodes.length - 2];
  const last = nodes[nodes.length - 1];
  // "Meilleur que le meilleur nœud" : R au-delà de l'extrême performant.
  const beyondBest = decreasing ? r < last.r : r > last.r;
  if (beyondBest) {
    const t = (r - lastM1.r) / (last.r - lastM1.r);
    return lastM1.p + t * (last.p - lastM1.p);
  }
  // "Pire que le pire nœud".
  const t = (r - first.r) / (second.r - first.r);
  return first.p + t * (second.p - first.p);
}

/**
 * Inverse de `invertPointTable` : interpole R à partir de P (les nœuds sont {P→R}, P croissant).
 * Interpolation linéaire en P entre nœuds ; extrapolation linéaire bornée au segment extrême
 * au-delà des P extrêmes. P est supposé déjà clampé dans [P_MIN, P_MAX] par l'appelant.
 */
function interpPointTable(p: number, model: PointTableModel): number {
  const nodes = [...model.nodes].sort((a, b) => a.p - b.p);
  if (nodes.length < 2) {
    throw new Error("pointTable: au moins 2 nœuds requis");
  }
  // P sous le 1er nœud → extrapole sur le 1er segment.
  if (p <= nodes[0].p) {
    const a = nodes[0];
    const b = nodes[1];
    const t = (p - a.p) / (b.p - a.p); // b.p − a.p ≠ 0 (P strictement croissant)
    return a.r + t * (b.r - a.r);
  }
  // P au-dessus du dernier nœud → extrapole sur le dernier segment.
  const last = nodes[nodes.length - 1];
  if (p >= last.p) {
    const a = nodes[nodes.length - 2];
    const t = (p - a.p) / (last.p - a.p);
    return a.r + t * (last.r - a.r);
  }
  // Segment encadrant.
  for (let i = 0; i < nodes.length - 1; i++) {
    const a = nodes[i];
    const b = nodes[i + 1];
    if (p >= a.p && p <= b.p) {
      const t = (p - a.p) / (b.p - a.p);
      return a.r + t * (b.r - a.r);
    }
  }
  // Inatteignable (P borné par les cas ci-dessus), mais TS exige un retour.
  return last.r;
}
