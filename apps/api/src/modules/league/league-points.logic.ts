/**
 * Barème de points de la LIGUE mensuelle (mode compétitif opt-in, séparé de l'Index).
 *
 * Principe (spec sport-science) : les points dérivent du SOUS-SCORE interne (0–1000) déjà calculé
 * et normalisé PAR SEXE par le score-service. On hérite donc automatiquement de :
 *   - l'équité inter-sexes (même percentile ⇒ même sous-score ⇒ mêmes points) ;
 *   - l'équité inter-WODs (tous passent par la même courbe) ;
 *   - l'anti-triche (bornes hardMin/hardMax appliquées en amont ⇒ un effort hors bornes n'a pas
 *     de sous-score, il arrive ici en `null` et vaut 0).
 *
 * Décision produit (25/06) : au lancement, mêmes WODs sans matériel pour tous, PAS de Rx/Scaled
 * ⇒ aucune décote ; tout le monde est comparable dans sa ligue de sexe.
 *
 * Formule : points d'une tentative = bonus de participation + part de performance (∝ sous-score),
 * borné [0, 1000]. Absence (aucun effort valide) = 0, JAMAIS de malus négatif.
 *
 * Pur et testé — aucune dépendance (ni DB, ni réseau).
 */

/** Plafond de la part « performance » (sur 1000 points hebdo). */
export const LEAGUE_PERF_MAX = 900;
/** Bonus fixe accordé pour tout effort valide enregistré (récompense la participation/régularité). */
export const LEAGUE_PART_BONUS = 100;
/** Borne dure des points d'une semaine. */
export const LEAGUE_WEEK_POINTS_MAX = 1000;
/** Sous-score interne maximal (échelle 0–1000). */
export const SUBSCORE_MAX = 1000;

function clamp(v: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, v));
}

/**
 * Points de Ligue d'UNE tentative sur le WOD imposé de la semaine.
 * @param subScore sous-score interne (0–1000) renvoyé par le score-service, ou `null` si absence /
 *                 effort invalide (hors bornes) ⇒ 0 point.
 */
export function leagueWeekPoints(subScore: number | null): number {
  // Absence ou donnée invalide ⇒ 0 (jamais de pénalité négative).
  if (subScore == null || !Number.isFinite(subScore)) return 0;
  const s = clamp(subScore, 0, SUBSCORE_MAX);
  const perf = Math.round(LEAGUE_PERF_MAX * (s / SUBSCORE_MAX));
  return clamp(Math.round(LEAGUE_PART_BONUS + perf), 0, LEAGUE_WEEK_POINTS_MAX);
}

/**
 * Meilleur effort de la semaine (décision : on retient le MAX, jamais la somme des tentatives).
 * @param subScores sous-scores des tentatives de la semaine (peut être vide ⇒ 0).
 */
export function bestWeekPoints(subScores: Array<number | null>): number {
  return subScores.reduce<number>((best, s) => Math.max(best, leagueWeekPoints(s)), 0);
}

/**
 * Score mensuel = somme des points hebdomadaires (≤ 4 semaines). Borné [0, 4000] en pratique.
 * @param weeklyPoints points retenus pour chaque semaine du mois.
 */
export function leagueMonthScore(weeklyPoints: number[]): number {
  return weeklyPoints.reduce((sum, p) => sum + Math.max(0, p), 0);
}
