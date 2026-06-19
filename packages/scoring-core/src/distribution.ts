import { normalCdf } from "./math/normal";
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
