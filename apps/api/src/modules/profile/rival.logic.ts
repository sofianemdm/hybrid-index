import { ratingFromInternal } from "@hybrid-index/scoring-core";

/** Candidat rival lu du classement (valeur interne /1000 + identité). */
export interface RivalCandidate {
  value: number; // valeur interne /1000
  displayName: string | null;
  rank: string | null;
}

export interface RivalView {
  displayName: string;
  rank: string;
  ovr: number; // OVR /100 du rival
  position: number; // place du rival dans la ligue
  gapPoints: number; // points d'Index pour le dépasser (>= 1)
}

/**
 * Construit la vue « rival amical » à partir de ma valeur interne, du nombre d'athlètes au-dessus
 * de moi (`above`) et du candidat immédiatement au-dessus. Pur et testable (pas d'accès DB).
 *
 * - `above <= 0` (je suis leader) ou aucun candidat ⇒ pas de rival (`null`).
 * - `position` = `above` : le rival occupe la place juste DEVANT la mienne (ma place = `above + 1`).
 * - `gapPoints` = écart d'OVR arrondi, plancher 1 (toujours « au moins 1 point » à reprendre,
 *   jamais 0 ni négatif → message toujours motivant).
 * - Profil de rival incomplet (supprimé) ⇒ repli « — » / « rookie ».
 */
export function buildRival(myValue: number, above: number, candidate: RivalCandidate | null): RivalView | null {
  if (above <= 0 || candidate === null) return null;
  const rivalOvr = Math.round(ratingFromInternal(candidate.value));
  const myOvr = Math.round(ratingFromInternal(myValue));
  return {
    displayName: candidate.displayName ?? "—",
    rank: candidate.rank ?? "rookie",
    ovr: rivalOvr,
    position: above,
    gapPoints: Math.max(1, rivalOvr - myOvr),
  };
}
