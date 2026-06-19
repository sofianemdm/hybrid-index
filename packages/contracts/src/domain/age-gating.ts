/**
 * Age-gating (décision D4) : âge minimum 13 ans à l'inscription.
 * Logique PURE et partagée (api + plus tard contrôle en base via CHECK). Sujet juridique sensible
 * (§18 RGPD/mineurs) — à faire valider par un juriste avant lancement public.
 */

export const MIN_AGE_YEARS = 13;

/** Vrai si `dateOfBirth` correspond à un âge ≥ `minYears` à la date `now`. */
export function isOldEnough(dateOfBirth: Date, now: Date, minYears: number = MIN_AGE_YEARS): boolean {
  return dateOfBirth.getTime() <= maxBirthDateFor(now, minYears).getTime();
}

/** Date de naissance la plus tardive acceptable pour avoir `minYears` ans à la date `now`. */
export function maxBirthDateFor(now: Date, minYears: number = MIN_AGE_YEARS): Date {
  const d = new Date(now.getTime());
  d.setFullYear(d.getFullYear() - minYears);
  return d;
}
