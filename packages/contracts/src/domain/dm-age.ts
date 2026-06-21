/**
 * Sécurité des messages privés (mineurs ≥13, conformité DSA) — logique PURE et testée.
 * Politique : SÉPARATION STRICTE PAR ÂGE (décision produit). Un mineur ne peut échanger en privé
 * qu'avec des mineurs ; un adulte ne peut pas initier de DM vers un mineur. Donc DM autorisé
 * uniquement si les deux comptes sont dans la MÊME tranche (tous deux mineurs OU tous deux adultes).
 * À faire valider par un juriste avant lancement public (sujet sensible).
 */

export const ADULT_AGE_YEARS = 18;

/** Vrai si la personne est mineure (< 18 ans) à la date `now`. */
export function isMinor(dateOfBirth: Date, now: Date): boolean {
  const adultThreshold = new Date(now.getTime());
  adultThreshold.setFullYear(adultThreshold.getFullYear() - ADULT_AGE_YEARS);
  // Mineur si né APRÈS la date seuil (n'a pas encore 18 ans).
  return dateOfBirth.getTime() > adultThreshold.getTime();
}

/** Vrai si A et B peuvent s'écrire en privé du point de vue de l'âge (même tranche). */
export function dmAgeAllowed(birthA: Date, birthB: Date, now: Date): boolean {
  return isMinor(birthA, now) === isMinor(birthB, now);
}
