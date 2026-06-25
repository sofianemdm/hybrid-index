import {
  monthIndexFromKey,
  monthKeyOf,
  monthBounds,
  addDaysUTC,
  pickMonthlyWods,
  isoWeeksOfMonth,
} from "../src/modules/league/league.rotation";

describe("league.rotation — sélection déterministe des WODs du mois", () => {
  const pool = ["benchmark_zero", "burpees_7min", "max_air_squats_2min", "max_pushups", "run_3k", "run_5k"];

  it("monthIndexFromKey est monotone et ordonné", () => {
    expect(monthIndexFromKey("2026-08") - monthIndexFromKey("2026-07")).toBe(1);
    expect(monthIndexFromKey("2027-01") - monthIndexFromKey("2026-12")).toBe(1);
  });

  it("monthKeyOf : clé UTC d'une date", () => {
    expect(monthKeyOf(new Date(Date.UTC(2026, 6, 15)))).toBe("2026-07");
    expect(monthKeyOf(new Date(Date.UTC(2026, 0, 1)))).toBe("2026-01");
  });

  it("monthBounds : début du mois → début du mois suivant", () => {
    const { opensAt, closesAt } = monthBounds("2026-07");
    expect(opensAt.toISOString()).toBe("2026-07-01T00:00:00.000Z");
    expect(closesAt.toISOString()).toBe("2026-08-01T00:00:00.000Z");
  });

  it("addDaysUTC ajoute des jours sans muter", () => {
    const d = new Date(Date.UTC(2026, 6, 1));
    expect(addDaysUTC(d, 7).toISOString()).toBe("2026-07-08T00:00:00.000Z");
    expect(d.toISOString()).toBe("2026-07-01T00:00:00.000Z"); // non muté
  });

  it("déterministe : même mois ⇒ mêmes WODs", () => {
    expect(pickMonthlyWods(pool, "2026-07")).toEqual(pickMonthlyWods(pool, "2026-07"));
  });

  it("4 WODs distincts (pas de répétition intra-mois)", () => {
    const wods = pickMonthlyWods(pool, "2026-07", 4);
    expect(wods).toHaveLength(4);
    expect(new Set(wods).size).toBe(4);
  });

  it("la rotation avance d'un mois à l'autre", () => {
    expect(pickMonthlyWods(pool, "2026-07")).not.toEqual(pickMonthlyWods(pool, "2026-08"));
  });

  it("pool plus petit que count ⇒ cappé sans répétition", () => {
    expect(pickMonthlyWods(["a", "b"], "2026-07", 4)).toEqual(["a", "b"]);
  });

  it("pool vide ⇒ aucun WOD", () => {
    expect(pickMonthlyWods([], "2026-07")).toEqual([]);
  });
});

describe("isoWeeksOfMonth — couvre TOUTES les semaines ISO du mois (corrige B1)", () => {
  const covers = (weeks: Date[], d: Date) => weeks.some((w) => w <= d && d < addDaysUTC(w, 7));

  // 2026-08 : le 1er est un samedi ⇒ le mois chevauche 6 semaines ISO (cas qui révélait le trou).
  it("août 2026 (1er = samedi) : aucun jour du mois sans semaine imposée", () => {
    const weeks = isoWeeksOfMonth("2026-08");
    const { opensAt, closesAt } = monthBounds("2026-08");
    const lastDay = new Date(closesAt.getTime() - 1);
    expect(weeks.length).toBeGreaterThanOrEqual(5); // > 4 : c'est tout l'intérêt du correctif
    expect(covers(weeks, opensAt)).toBe(true); // 1er du mois couvert
    expect(covers(weeks, lastDay)).toBe(true); // dernier jour du mois couvert
  });

  it("toutes les semaines débutent un lundi (UTC) et sont consécutives (+7 j)", () => {
    const weeks = isoWeeksOfMonth("2026-08");
    expect(weeks.every((w) => w.getUTCDay() === 1)).toBe(true);
    for (let i = 1; i < weeks.length; i++) {
      expect(weeks[i].getTime() - weeks[i - 1].getTime()).toBe(7 * 86_400_000);
    }
  });

  it("février 2026 : chaque jour du mois est couvert par une semaine", () => {
    const weeks = isoWeeksOfMonth("2026-02");
    const { opensAt, closesAt } = monthBounds("2026-02");
    for (let d = new Date(opensAt); d < closesAt; d = addDaysUTC(d, 1)) {
      expect(covers(weeks, d)).toBe(true);
    }
  });
});
