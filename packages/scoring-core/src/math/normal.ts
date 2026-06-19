/**
 * Fonction de répartition normale standard Φ, via une approximation de erf
 * (Abramowitz & Stegun 7.1.26, erreur max ~1.5e-7) — suffisant pour les percentiles.
 */

/** erf(x) — fonction d'erreur. */
export function erf(x: number): number {
  const sign = x < 0 ? -1 : 1;
  const ax = Math.abs(x);
  const t = 1 / (1 + 0.3275911 * ax);
  const y =
    1 -
    ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t +
      0.254829592) *
      t *
      Math.exp(-ax * ax);
  return sign * y;
}

/** Φ(z) — CDF normale standard. */
export function normalCdf(z: number): number {
  return 0.5 * (1 + erf(z / Math.SQRT2));
}
