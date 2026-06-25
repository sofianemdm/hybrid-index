import {
  leagueWeekPoints,
  bestWeekPoints,
  leagueMonthScore,
  LEAGUE_PART_BONUS,
  LEAGUE_WEEK_POINTS_MAX,
} from "../src/modules/league/league-points.logic";

describe("leagueWeekPoints — points d'une tentative (dérivés du sous-score 0–1000)", () => {
  it("absence (subScore null) ⇒ 0 (jamais de malus)", () => {
    expect(leagueWeekPoints(null)).toBe(0);
  });

  it("plancher : effort valide au plus bas (s=0) ⇒ bonus de participation seul (100)", () => {
    expect(leagueWeekPoints(0)).toBe(LEAGUE_PART_BONUS);
  });

  it("plafond : s=1000 ⇒ 1000", () => {
    expect(leagueWeekPoints(1000)).toBe(LEAGUE_WEEK_POINTS_MAX);
  });

  it("milieu : s=500 ⇒ 100 + round(900*0.5) = 550", () => {
    expect(leagueWeekPoints(500)).toBe(550);
  });

  it("élite ~ s=950 ⇒ ~955 (cohérent avec l'exemple Fran de la spec)", () => {
    expect(leagueWeekPoints(950)).toBe(955);
  });

  it("intermédiaire ~ s=600 ⇒ 640", () => {
    expect(leagueWeekPoints(600)).toBe(640);
  });

  it("monotonie : un meilleur sous-score donne plus de points", () => {
    expect(leagueWeekPoints(600)).toBeGreaterThan(leagueWeekPoints(400));
    expect(leagueWeekPoints(800)).toBeGreaterThan(leagueWeekPoints(600));
  });

  it("borné : sous-score aberrant > 1000 ⇒ clamp à 1000", () => {
    expect(leagueWeekPoints(1200)).toBe(LEAGUE_WEEK_POINTS_MAX);
  });

  it("borné : sous-score négatif (ne devrait pas arriver) ⇒ clamp à 0 ⇒ bonus seul", () => {
    expect(leagueWeekPoints(-50)).toBe(LEAGUE_PART_BONUS);
  });

  it("NaN (donnée corrompue) ⇒ 0 (traité comme absence)", () => {
    expect(leagueWeekPoints(Number.NaN)).toBe(0);
  });
});

describe("bestWeekPoints — meilleur effort de la semaine (max, jamais la somme)", () => {
  it("retient la meilleure tentative", () => {
    // s=700 ⇒ 730, qui doit l'emporter sur 400 (460) et 550 (595)
    expect(bestWeekPoints([400, 700, 550])).toBe(leagueWeekPoints(700));
  });

  it("aucune tentative ⇒ 0 (absence)", () => {
    expect(bestWeekPoints([])).toBe(0);
    expect(bestWeekPoints([null, null])).toBe(0);
  });

  it("ignore les tentatives invalides et garde la valide", () => {
    expect(bestWeekPoints([null, 500, null])).toBe(leagueWeekPoints(500));
  });
});

describe("leagueMonthScore — cumul mensuel (somme des semaines)", () => {
  it("somme les 4 semaines", () => {
    expect(leagueMonthScore([955, 640, 0, 730])).toBe(2325);
  });

  it("mois vide ⇒ 0", () => {
    expect(leagueMonthScore([])).toBe(0);
  });

  it("un débutant RÉGULIER (4×~330) bat un intermédiaire IRRÉGULIER (1×640) — effet voulu", () => {
    const debutantRegulier = leagueMonthScore([330, 330, 330, 330]); // 1320
    const intermediaireIrregulier = leagueMonthScore([640, 0, 0, 0]); // 640
    expect(debutantRegulier).toBeGreaterThan(intermediaireIrregulier);
  });

  it("plafond mensuel plausible : 4 semaines au max ⇒ 4000", () => {
    expect(leagueMonthScore([1000, 1000, 1000, 1000])).toBe(4000);
  });
});
