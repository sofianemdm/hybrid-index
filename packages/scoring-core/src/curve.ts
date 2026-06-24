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

// ───────────────────────── Affichage /100 (display-v2) ─────────────────────────
/**
 * Échelle d'AFFICHAGE « type FIFA » du HYBRID INDEX et des sous-scores : une note /100 ancrée
 * sur le niveau RÉEL et CALIBRÉE NIVEAU PRO. Le cœur de calcul reste [0,1000] (sigmoid-v1, intact) ;
 * ceci est une PROJECTION pure et monotone appliquée AU BORD. Aucune migration de données : la note
 * est dérivée à la lecture.
 *
 * display-v2 (recalibration « exigeante dans le haut », 24 juin) : la v1 récompensait trop le top
 * (un non-élite à P≈0.95 sortait à ~94/100). v2 réserve le sommet aux niveaux quasi record-du-monde.
 *
 * Forme à TROIS segments (P = percentile vs population de MÊME SEXE) :
 *   - A) P ∈ [0, 0.5]   : logistique renormalisée, 35 (sédentaire) → 57 (médiane régulière).
 *   - B) P ∈ (0.5, 0.9] : puissance β, 57 → 84 (de l'amateur médian au « top box »).
 *   - C) P ∈ (0.9, 1]   : puissance γ raide, 84 → 98 (la queue élite ; chaque dernier % coûte cher).
 *
 * Barème cible (vs même sexe) :
 *   record du monde ~P0.999 → ~97 · pro/élite intl ~P0.99 → ~94 · top box ~P0.97 → ~88
 *   très bon amateur ~P0.93 → ~84 · bon ~P0.85 → ~77 · au-dessus moyenne ~P0.70 → ~63
 *   médian ~P0.50 → 57 · débutant ~P0.27 → ~44 · sédentaire ~P0.05 → ~36.
 * Le sommet RESTE différencié (un athlète fort garde des attributs distincts, pas tous au plafond)
 * et la note ne frôle 97 QUE pour un niveau quasi record-du-monde ; 100 reste inatteignable.
 * VERSIONNÉE : tout changement de constantes ⇒ nouvelle version display-vX.
 */
export const DISPLAY_VERSION = "display-v2";

const DISPLAY = {
  floor: 35, // P=0 (sédentaire)
  // Pivot médian : fin du segment logistique A / début du segment puissance B.
  midPivot: 0.5,
  noteAtMid: 57, // P=0.5 (médiane régulière)
  // Pivot haut : fin de B / début de la queue élite C.
  highPivot: 0.9,
  noteAtHigh: 84, // P=0.9 (« top box »)
  top: 98, // P=1 (le record du monde frôle 97-98, jamais 100)
  betaMid: 2.24, // exposant segment B (médiane → top box)
  gammaTop: 3.2, // exposant segment C (queue élite : très raide ⇒ le dernier % coûte le plus cher)
  k: 5.0,
  p0: 0.5,
} as const;

/** Cœur logistique renormalisé s(P) ∈ [0,1] propre au segment bas de la courbe d'affichage. */
function displayCore(p: number): number {
  const sig = (x: number): number => 1 / (1 + Math.exp(-DISPLAY.k * (x - DISPLAY.p0)));
  const s0 = sig(0);
  const s1 = sig(1);
  return (sig(p) - s0) / (s1 - s0);
}

/** Note d'affichage /100 (1 décimale) à partir d'un percentile P ∈ [0,1]. Monotone croissante. */
export function ratingFromPercentile(p: number): number {
  const pc = Math.min(1, Math.max(0, p));
  const { floor, midPivot, noteAtMid, highPivot, noteAtHigh, top, betaMid, gammaTop } = DISPLAY;
  let g: number;
  if (pc <= midPivot) {
    // Segment A : logistique renormalisée, floor → noteAtMid.
    const coreMid = displayCore(midPivot);
    g = floor + ((noteAtMid - floor) / coreMid) * displayCore(pc);
  } else if (pc <= highPivot) {
    // Segment B : puissance, noteAtMid → noteAtHigh.
    const u = (pc - midPivot) / (highPivot - midPivot);
    g = noteAtMid + (noteAtHigh - noteAtMid) * Math.pow(u, betaMid);
  } else {
    // Segment C : queue élite, noteAtHigh → top.
    const u = (pc - highPivot) / (1 - highPivot);
    g = noteAtHigh + (top - noteAtHigh) * Math.pow(u, gammaTop);
  }
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
