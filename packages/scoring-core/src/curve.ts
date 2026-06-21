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

// ───────────────────────── Affichage /100 (display-v1) ─────────────────────────
/**
 * Échelle d'AFFICHAGE « type FIFA » du HYBRID INDEX et des sous-scores : une note /100 ancrée
 * sur le niveau RÉEL. Le cœur de calcul reste [0,1000] (sigmoid-v1, intact) ; ceci est une
 * PROJECTION pure et monotone appliquée AU BORD (cf. sport-science index-v2 §1-bis). Aucune
 * migration de données : la note est dérivée à la lecture.
 *
 * Forme : g(P) = logistique renormalisée jusqu'au pivot a, puis montée en PUISSANCE jusqu'à 98
 * (le sommet reste DIFFÉRENCIÉ : un athlète fort garde des attributs distincts, pas tous au plafond).
 * Plancher 35 (sédentaire), max ~98 (le record du monde frôle 99, jamais 100).
 * Repères : P=0→35, médiane→63, bon niveau→82, top box→90, pro→~95, record→~98.
 * VERSIONNÉE : tout changement de constantes ⇒ nouvelle version display-vX.
 */
export const DISPLAY_VERSION = "display-v1";

const DISPLAY = {
  floor: 35,
  pivot: 0.8, // percentile-pivot `a` : en dessous, montée logistique ; au-dessus, montée en puissance
  noteAtPivot: 86,
  top: 98, // note à P=1 (le record du monde frôle 99, jamais 100)
  expo: 1.5, // exposant de la branche haute (>1 ⇒ le tout-dernier % coûte le plus cher, mais le haut RESTE différencié)
  k: 6.4,
  p0: 0.5,
} as const;

/** Cœur logistique renormalisé s(P) ∈ [0,1] propre à la courbe d'affichage. */
function displayCore(p: number): number {
  const sig = (x: number): number => 1 / (1 + Math.exp(-DISPLAY.k * (x - DISPLAY.p0)));
  const s0 = sig(0);
  const s1 = sig(1);
  return (sig(p) - s0) / (s1 - s0);
}

/** Note d'affichage /100 (1 décimale) à partir d'un percentile P ∈ [0,1]. Monotone croissante. */
export function ratingFromPercentile(p: number): number {
  const pc = Math.min(1, Math.max(0, p));
  const { floor, pivot, noteAtPivot, top, expo } = DISPLAY;
  const sA = displayCore(pivot);
  const g =
    pc <= pivot
      ? floor + ((noteAtPivot - floor) / sA) * displayCore(pc)
      : noteAtPivot + (top - noteAtPivot) * Math.pow((pc - pivot) / (1 - pivot), expo);
  return Math.round(g * 10) / 10;
}

/** Percentile équivalent d'un score interne S ∈ [0,1000] (inverse analytique de sigmoid-v1). */
export function percentileFromInternal(internal: number, params: CurveParams = SIGMOID_V1): number {
  const u = Math.min(1 - 1e-6, Math.max(1e-6, internal / 1000));
  const r0 = rawSigmoid(0, params);
  const r1 = rawSigmoid(1, params);
  const raw = Math.min(1 - 1e-9, Math.max(1e-9, u * (r1 - r0) + r0));
  return params.p0 + (1 / params.k) * Math.log(raw / (1 - raw));
}

/**
 * Note d'affichage /100 (1 décimale) d'un score interne [0,1000] — sert pour l'Index ET pour
 * un score d'attribut. C'est la composition g(f⁻¹(S/1000)).
 */
export function ratingFromInternal(internal: number, params: CurveParams = SIGMOID_V1): number {
  return ratingFromPercentile(percentileFromInternal(internal, params));
}
