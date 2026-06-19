/**
 * UUID de la version de scoring active, seedée dans `scoring.scoring_version`.
 * Le score-service renvoie l'identifiant logique « scoring-v1 » ; côté persistance app.*,
 * les dérivées (index, attributs, résultats) référencent cet UUID (lien logique §3.3).
 */
export const SCORING_VERSION_UUID = "11111111-1111-1111-1111-111111111111";
