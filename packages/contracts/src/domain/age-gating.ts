/**
 * Age-gating (décision D4, relevé 13→15 le 03/07/2026 pour le lancement public) : âge minimum
 * 15 ans à l'inscription = âge du consentement numérique en France (loi n° 2018-493, art. 45 RGPD).
 * En dessous de 15 ans il faudrait recueillir l'accord parental — mécanisme qu'on ne construit pas.
 * Logique PURE et partagée (api + mobile). À faire valider par un juriste avant lancement public.
 */

export const MIN_AGE_YEARS = 15;

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
