/** Extraction de l'IP cliente derrière le proxy Railway/Netlify (partagé rate-limit + visit-log). */

/** Sous-ensemble de la requête HTTP nécessaire (évite la dépendance aux types express). */
export interface IpAwareRequest {
  headers: Record<string, string | string[] | undefined>;
  ip?: string;
}

/** IP cliente : 1re IP de x-forwarded-for si présente (proxy), sinon req.ip. */
export function clientIp(req: IpAwareRequest): string {
  const fwd = req.headers["x-forwarded-for"];
  const first = Array.isArray(fwd) ? fwd[0] : (fwd ?? "").split(",")[0].trim();
  return first || req.ip || "unknown";
}
