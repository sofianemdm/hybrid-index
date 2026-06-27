/**
 * Club « principal » d'un athlète, pour l'afficher À CÔTÉ de son nom dans les classements.
 * Un athlète peut être dans plusieurs clubs : on retient le PREMIER rejoint (rows triées par
 * joinedAt asc) et seulement si le club est `visible`. Pur (mapping) — la requête reste côté service.
 */
export function primaryClubNameByUserId(
  rows: Array<{ userId: string; club: { name: string; status: string } | null }>,
): Map<string, string> {
  const map = new Map<string, string>();
  for (const m of rows) {
    if (m.club && m.club.status === "visible" && !map.has(m.userId)) {
      map.set(m.userId, m.club.name);
    }
  }
  return map;
}
