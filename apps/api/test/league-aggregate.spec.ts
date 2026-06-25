import { totalsBestPerWeek, rankTotals } from "../src/modules/league/league.aggregate";

describe("league.aggregate — total mensuel = meilleur effort par semaine", () => {
  it("retient le meilleur effort de chaque semaine (jamais la somme des tentatives)", () => {
    const rows = [
      { userId: "u1", weekId: "w1", points: 400 },
      { userId: "u1", weekId: "w1", points: 730 }, // 2e tentative meilleure même semaine
      { userId: "u1", weekId: "w2", points: 550 },
    ];
    const totals = totalsBestPerWeek(rows);
    expect(totals).toHaveLength(1);
    expect(totals[0]).toEqual({ userId: "u1", total: 730 + 550, weeksPlayed: 2 });
  });

  it("plusieurs utilisateurs agrégés indépendamment", () => {
    const rows = [
      { userId: "a", weekId: "w1", points: 900 },
      { userId: "b", weekId: "w1", points: 300 },
      { userId: "b", weekId: "w2", points: 300 },
    ];
    const totals = totalsBestPerWeek(rows);
    expect(totals.find((t) => t.userId === "a")?.total).toBe(900);
    expect(totals.find((t) => t.userId === "b")?.total).toBe(600);
  });

  it("liste vide ⇒ aucun total", () => {
    expect(totalsBestPerWeek([])).toEqual([]);
  });

  it("tri déterministe : points desc puis userId asc (départage stable)", () => {
    const ranked = rankTotals([
      { userId: "zoe", total: 500 },
      { userId: "alice", total: 800 },
      { userId: "bob", total: 500 }, // même total que zoe → bob avant zoe (userId asc)
    ]);
    expect(ranked.map((r) => r.userId)).toEqual(["alice", "bob", "zoe"]);
  });
});
