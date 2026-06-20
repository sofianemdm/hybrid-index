/** Utilitaires de semaine ISO-8601 (lundi → dimanche), en UTC. */

export function isoWeek(d: Date): { year: number; week: number } {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = (date.getUTCDay() + 6) % 7; // lundi = 0
  date.setUTCDate(date.getUTCDate() - dayNum + 3); // jeudi de la semaine
  const firstThursday = new Date(Date.UTC(date.getUTCFullYear(), 0, 4));
  const firstDayNum = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstDayNum + 3);
  const week = 1 + Math.round((date.getTime() - firstThursday.getTime()) / (7 * 86_400_000));
  return { year: date.getUTCFullYear(), week };
}

export function isoWeekKey(d: Date): string {
  const { year, week } = isoWeek(d);
  return `${year}-W${String(week).padStart(2, "0")}`;
}

/** Lundi 00:00 UTC de la semaine contenant `d`. */
export function weekStart(d: Date): Date {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = (date.getUTCDay() + 6) % 7;
  date.setUTCDate(date.getUTCDate() - dayNum);
  return date;
}

export function addWeeks(d: Date, n: number): Date {
  const x = new Date(d);
  x.setUTCDate(x.getUTCDate() + 7 * n);
  return x;
}

/** Lundi 00:00 UTC d'une semaine ISO (à partir de sa clé "YYYY-Www"). */
export function isoWeekKeyToMonday(key: string): Date {
  const [yearStr, weekStr] = key.split("-W");
  const year = Number(yearStr);
  const week = Number(weekStr);
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const week1Monday = weekStart(jan4);
  return addWeeks(week1Monday, week - 1);
}
