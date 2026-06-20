import { addWeeks, isoWeekKey, isoWeekKeyToMonday, weekStart } from "../src/modules/engagement/iso-week";
import { matchesCondition, type BadgeContext } from "../src/modules/engagement/badges.data";

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
    distinctWods: 6,
    equipmentFreeCount: 8,
    rank: "gold",
    index: 760,
    percentile: 96,
    attributesAllUnlocked: true,
    streakCurrent: 5,
    streakBest: 12,
    beatRival: true,
  };

  it("comparateurs >= sur rang/index/percentile/streak/wods", () => {
    expect(matchesCondition("rank>=gold", base)).toBe(true);
    expect(matchesCondition("rank>=diamond", base)).toBe(false);
    expect(matchesCondition("index>=750", base)).toBe(true);
    expect(matchesCondition("index>=900", base)).toBe(false);
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
    expect(matchesCondition("beat_rival", base)).toBe(true);
    expect(matchesCondition("beat_rival", { ...base, beatRival: false })).toBe(false);
    expect(matchesCondition("pro_gap<=10", base)).toBe(false); // non implémenté → jamais vrai
  });
});
