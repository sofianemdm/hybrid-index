import {
  monthIndexFromKey,
  monthKeyOf,
  monthBounds,
  addDaysUTC,
  pickMonthlyWods,
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
