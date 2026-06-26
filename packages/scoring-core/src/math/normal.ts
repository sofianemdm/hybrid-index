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

/**
 * Φ⁻¹(p) — fonction quantile (inverse) de la normale standard, via l'approximation rationnelle
 * d'Acklam (erreur relative < ~1.15e-9 sur (0,1)). Réciproque de `normalCdf` : sert à INVERSER
 * la chaîne de scoring (percentile → résultat brut prédit). `p` est clampé dans (0,1) pour rester
 * fini (Φ⁻¹(0)=−∞, Φ⁻¹(1)=+∞).
 */
export function normInv(p: number): number {
  if (Number.isNaN(p)) return Number.NaN;
  // Clamp strict : aux extrêmes la fonction diverge. ε aligné sur la précision double.
  const EPS = 1e-12;
  const pc = Math.min(1 - EPS, Math.max(EPS, p));

  // Coefficients d'Acklam.
  const a = [-3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2, 1.383577518672690e2, -3.066479806614716e1, 2.506628277459239];
  const b = [-5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2, 6.680131188771972e1, -1.328068155288572e1];
  const c = [-7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838, -2.549732539343734, 4.374664141464968, 2.938163982698783];
  const d = [7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996, 3.754408661907416];

  // Bornes des régions (queues vs centre).
  const pLow = 0.02425;
  const pHigh = 1 - pLow;

  if (pc < pLow) {
    // Queue basse : transformation logarithmique.
    const q = Math.sqrt(-2 * Math.log(pc));
    return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  if (pc <= pHigh) {
    // Région centrale : rationnelle directe.
    const q = pc - 0.5;
    const r = q * q;
    return ((((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q) / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
  }
  // Queue haute : symétrique de la queue basse.
  const q = Math.sqrt(-2 * Math.log(1 - pc));
  return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
}
