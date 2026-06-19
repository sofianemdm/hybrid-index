/**
 * Courbe de calibration f(P) → sous-score [0,1000] (cf. sport-science §4).
 * `f = sigmoid-v1` : logistique recentrée puis renormalisée sur [0,1].
 *
 *   raw(P) = 1 / (1 + exp(−k·(P − P0)))
 *   f(P)   = (raw(P) − raw(0)) / (raw(1) − raw(0))     (clampée [0,1])
 *   subScore = round(1000 · f(P))
 *
 * VERSIONNÉE : tout changement de k/P0/forme ⇒ nouvelle version + recalcul historique.
 */

export interface CurveParams {
  /** Pente (raideur centrale). */
  k: number;
  /** Centre de la sigmoïde (>0.5 → médiane P=0.5 ≈ 450, pas 500). */
  p0: number;
}

/** Paramètres par défaut `sigmoid-v1` (cf. sport-science §4.2). */
export const SIGMOID_V1: CurveParams = { k: 6.0, p0: 0.55 };

/** Identifiant de version de la courbe (porté par scoringVersion côté service). */
export const CURVE_VERSION = "sigmoid-v1";

function rawSigmoid(p: number, { k, p0 }: CurveParams): number {
  return 1 / (1 + Math.exp(-k * (p - p0)));
}

/** f(P) ∈ [0,1], monotone croissante, f(0)=0, f(1)=1 après renormalisation. */
export function curveF(p: number, params: CurveParams = SIGMOID_V1): number {
  const r0 = rawSigmoid(0, params);
  const r1 = rawSigmoid(1, params);
  const f = (rawSigmoid(p, params) - r0) / (r1 - r0);
  return Math.min(1, Math.max(0, f));
}

/** Sous-score entier [0,1000] à partir d'un percentile P ∈ [0,1]. */
export function subScoreFromPercentile(p: number, params: CurveParams = SIGMOID_V1): number {
  return Math.round(1000 * curveF(p, params));
}
