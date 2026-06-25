import { weekStart } from "../engagement/iso-week";

/**
 * Sélection DÉTERMINISTE des WODs imposés d'un mois + bornes temporelles d'une saison.
 *
 * Au lancement, le pool est constitué des WODs sans matériel (passé en argument depuis la DB).
 * Déterminisme : un même `monthKey` produit toujours les mêmes WODs (rejouable, testable).
 * Rotation FIFO par fenêtre glissante ⇒ au fil des mois, tous les WODs du pool défilent sans
 * répétition à l'intérieur d'un même mois.
 *
 * Pur et testé — aucune dépendance.
 */

/** "2026-07" → index de mois monotone (année*12 + mois), pour ordonner/décaler la rotation. */
export function monthIndexFromKey(monthKey: string): number {
  const [y, m] = monthKey.split("-").map((n) => parseInt(n, 10));
  return y * 12 + (m - 1);
}

/** Clé de mois UTC d'une date, ex. "2026-07". */
export function monthKeyOf(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

/** Bornes [début du mois, début du mois suivant) en UTC. */
export function monthBounds(monthKey: string): { opensAt: Date; closesAt: Date } {
  const [y, m] = monthKey.split("-").map((n) => parseInt(n, 10));
  return {
    opensAt: new Date(Date.UTC(y, m - 1, 1, 0, 0, 0)),
    closesAt: new Date(Date.UTC(y, m, 1, 0, 0, 0)),
  };
}

/** Ajoute `days` jours à une date (UTC, immutable). */
export function addDaysUTC(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 86_400_000);
}

/**
 * Choisit `count` WODs du pool pour le mois donné, sans répétition intra-mois.
 * @param pool ids de WODs, ordre stable (ex. tri par id).
 */
export function pickMonthlyWods(pool: string[], monthKey: string, count = 4): string[] {
  if (pool.length === 0) return [];
  const n = Math.min(count, pool.length); // jamais de répétition intra-mois
  const start = (monthIndexFromKey(monthKey) * n) % pool.length;
  const out: string[] = [];
  for (let i = 0; i < n; i++) out.push(pool[(start + i) % pool.length]);
  return out;
}

/**
 * Lundis (UTC) de TOUTES les semaines ISO qui chevauchent le mois — pas seulement 4.
 * Garantit qu'aucun jour du mois ne tombe dans une semaine sans WOD imposé (corrige le trou de la
 * dernière semaine civile quand le 1er ne tombe pas un lundi).
 */
export function isoWeeksOfMonth(monthKey: string): Date[] {
  const { opensAt, closesAt } = monthBounds(monthKey);
  const out: Date[] = [];
  let cur = weekStart(opensAt); // lundi de la semaine ISO contenant le 1er
  while (cur < closesAt) {
    out.push(cur);
    cur = addDaysUTC(cur, 7);
  }
  return out;
}
