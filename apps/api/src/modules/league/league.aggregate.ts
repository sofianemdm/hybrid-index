/**
 * Agrégation du classement mensuel de Ligue, à partir du ledger `league_points`.
 *
 * Règle (décision produit) : le total mensuel d'un athlète = somme du MEILLEUR effort de chaque
 * semaine (jamais la somme de toutes les tentatives). Tri déterministe : points décroissants, puis
 * userId croissant (départage stable, identique au leaderboard Index).
 *
 * Pur et testé. Au lancement (population faible), l'agrégation se fait en mémoire ; à l'échelle, elle
 * migrera vers SQL/Redis sans changer ce contrat.
 */

export interface PointRow {
  userId: string;
  weekId: string;
  points: number;
}

export interface UserTotal {
  userId: string;
  total: number;
  weeksPlayed: number;
}

/** Total par utilisateur = Σ (meilleur effort de chaque semaine). */
export function totalsBestPerWeek(rows: PointRow[]): UserTotal[] {
  const perUser = new Map<string, Map<string, number>>();
  for (const r of rows) {
    const wk = perUser.get(r.userId) ?? new Map<string, number>();
    wk.set(r.weekId, Math.max(wk.get(r.weekId) ?? 0, r.points));
    perUser.set(r.userId, wk);
  }
  return [...perUser.entries()].map(([userId, wk]) => ({
    userId,
    total: [...wk.values()].reduce((a, b) => a + b, 0),
    weeksPlayed: wk.size,
  }));
}

/** Tri déterministe : points desc, puis userId asc. */
export function rankTotals<T extends { userId: string; total: number }>(totals: T[]): T[] {
  return [...totals].sort((a, b) => b.total - a.total || (a.userId < b.userId ? -1 : 1));
}
