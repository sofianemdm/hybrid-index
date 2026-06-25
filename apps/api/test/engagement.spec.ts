import { addWeeks, isoWeekKey, isoWeekKeyToMonday, weekStart } from "../src/modules/engagement/iso-week";
import { BADGES, matchesCondition, type BadgeContext } from "../src/modules/engagement/badges.data";

describe("iso-week (semaines ISO-8601, UTC)", () => {
  it("clé ISO d'un lundi connu", () => {
    expect(isoWeekKey(new Date("2026-01-05T12:00:00Z"))).toBe("2026-W02");
    expect(isoWeekKey(new Date("2026-01-01T00:00:00Z"))).toBe("2026-W01");
  });

  it("weekStart renvoie le lundi 00:00 UTC", () => {
    const monday = weekStart(new Date("2026-01-07T15:30:00Z")); // mercredi
    expect(monday.toISOString()).toBe("2026-01-05T00:00:00.000Z");
  });

  it("addWeeks décale de N semaines", () => {
    expect(addWeeks(new Date("2026-01-05T00:00:00Z"), 2).toISOString()).toBe("2026-01-19T00:00:00.000Z");
    expect(addWeeks(new Date("2026-01-05T00:00:00Z"), -1).toISOString()).toBe("2025-12-29T00:00:00.000Z");
  });

  it("isoWeekKeyToMonday est l'inverse de isoWeekKey (round-trip)", () => {
    for (const key of ["2026-W01", "2026-W02", "2026-W26", "2025-W52"]) {
      expect(isoWeekKey(isoWeekKeyToMonday(key))).toBe(key);
    }
  });
});

describe("matchesCondition (moteur de badges)", () => {
  const base: BadgeContext = {
    logCount: 10,
    followersCount: 6,
    leagueTotal: 250,
    distinctWods: 6,
    equipmentFreeCount: 8,
    rank: "gold",
    index: 76,
    percentile: 96,
    humanityTopPercent: 4,
    attributesAllUnlocked: true,
    streakCurrent: 5,
    streakBest: 12,
    isLeaguePioneer: false,
  };

  it("« league_pioneer » (Pionnier) : vrai seulement si inscrit à la 1re saison de Ligue", () => {
    expect(matchesCondition("league_pioneer", base)).toBe(false);
    expect(matchesCondition("league_pioneer", { ...base, isLeaguePioneer: true })).toBe(true);
  });

  it("« logs>=5 » (athlète confirmé) = 5 séances, sans exigence sociale", () => {
    expect(matchesCondition("logs>=5", base)).toBe(true); // 10 séances
    expect(matchesCondition("logs>=5", { ...base, logCount: 3 })).toBe(false);
  });

  it("« has_index » (premier Index) = un Index existe (> plancher)", () => {
    expect(matchesCondition("has_index", base)).toBe(true);
    expect(matchesCondition("has_index", { ...base, index: 0 })).toBe(false);
  });

  it("« followers>=N » = nombre de followers (pas de suivis)", () => {
    expect(matchesCondition("followers>=1", base)).toBe(true); // 6 followers
    expect(matchesCondition("followers>=10", base)).toBe(false);
  });

  it("« humanity<=X » : top X% des humains", () => {
    expect(matchesCondition("humanity<=5", base)).toBe(true); // top 4%
    expect(matchesCondition("humanity<=2", base)).toBe(false);
    expect(matchesCondition("humanity<=25", base)).toBe(true);
  });

  it("comparateurs >= sur rang/index/percentile/streak/wods", () => {
    expect(matchesCondition("rank>=gold", base)).toBe(true);
    expect(matchesCondition("rank>=diamond", base)).toBe(false);
    expect(matchesCondition("index>=75", base)).toBe(true); // OVR /100
    expect(matchesCondition("index>=90", base)).toBe(false);
    expect(matchesCondition("percentile>=95", base)).toBe(true);
    expect(matchesCondition("percentile>=99", base)).toBe(false);
    expect(matchesCondition("streak>=4", base)).toBe(true);
    expect(matchesCondition("streak_best>=12", base)).toBe(true);
    expect(matchesCondition("wods_distinct>=5", base)).toBe(true);
    expect(matchesCondition("equipment_free_count>=7", base)).toBe(true);
  });

  it("conditions spéciales et non implémentées", () => {
    expect(matchesCondition("attribute_unlocked:all", base)).toBe(true);
    expect(matchesCondition("attribute_unlocked:all", { ...base, attributesAllUnlocked: false })).toBe(false);
    expect(matchesCondition("pro_gap<=10", base)).toBe(false); // non implémenté → jamais vrai
  });
});

describe("catalogue de badges (garde-fous audit)", () => {
  const indexThresholds = BADGES.filter((b) => /^index>=/.test(b.condition)).map((b) => Number(b.condition.slice(7)));

  it("aucun palier d'Index inatteignable (>98) ni auto-débloqué (<=35) — G-05/G-06", () => {
    for (const t of indexThresholds) {
      expect(t).toBeGreaterThan(35); // plancher display-v2
      expect(t).toBeLessThanOrEqual(98); // plafond display-v2
    }
  });

  it("ids uniques", () => {
    const ids = BADGES.map((b) => b.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("first-index et all-attributes ont des conditions DIFFÉRENTES — G-09", () => {
    const first = BADGES.find((b) => b.id === "first-index")!;
    const all = BADGES.find((b) => b.id === "all-attributes")!;
    expect(first.condition).not.toBe(all.condition);
  });

  it("humanity-25 et humanity-15 reclassés common — G-10", () => {
    expect(BADGES.find((b) => b.id === "humanity-25")!.rarity).toBe("common");
    expect(BADGES.find((b) => b.id === "humanity-15")!.rarity).toBe("common");
  });

  it("catégories consistency et social non vides — G-04", () => {
    expect(BADGES.some((b) => b.category === "consistency")).toBe(true);
    expect(BADGES.some((b) => b.category === "social")).toBe(true);
  });

  it("tout cosmeticUnlock est rendu par le designer (pas de cosmétique mort) — G-03", () => {
    // Doit correspondre EXACTEMENT au catalogue de cosmetics.dart côté Flutter.
    const rendered = new Set([
      "avatar_glow_gold",
      "avatar_aura_diamond",
      "avatar_aura_top5",
      "avatar_aura_top1",
      "avatar_crown_elite",
      "avatar_badge_arsenal",
      "radar_skin_full",
    ]);
    for (const b of BADGES) {
      if (b.cosmeticUnlock) expect(rendered.has(b.cosmeticUnlock)).toBe(true);
    }
  });
});
