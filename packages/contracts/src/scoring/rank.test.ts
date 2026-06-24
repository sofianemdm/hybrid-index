import { describe, expect, it } from "vitest";
import { RANK_BANDS } from "../enums";
import { clampIndex, rankBandFromIndex, rankFromIndex, rankProgress } from "./rank";

// Bandes sur l'échelle d'AFFICHAGE /100 (note dérivée display-v2 ; les bornes elles-mêmes sont stables) :
// rookie [40,55) bronze [55,65) silver [65,72) gold [72,79) platinum [79,85) diamond [85,92) elite [92,100].
describe("rankFromIndex", () => {
  it("mappe chaque OVR /100 sur le bon rang", () => {
    expect(rankFromIndex(40)).toBe("rookie");
    expect(rankFromIndex(54)).toBe("rookie");
    expect(rankFromIndex(55)).toBe("bronze");
    expect(rankFromIndex(64)).toBe("bronze");
    expect(rankFromIndex(65)).toBe("silver");
    expect(rankFromIndex(67)).toBe("silver");
    expect(rankFromIndex(72)).toBe("gold");
    expect(rankFromIndex(79)).toBe("platinum");
    expect(rankFromIndex(82)).toBe("platinum");
    expect(rankFromIndex(85)).toBe("diamond");
    expect(rankFromIndex(92)).toBe("elite");
    expect(rankFromIndex(100)).toBe("elite");
  });

  it("est ordonné (monotone) sur toute la plage", () => {
    let lastOrdinal = -1;
    for (let v = 40; v <= 100; v += 2) {
      const ordinal = RANK_BANDS.findIndex((b) => b.rank === rankFromIndex(v));
      expect(ordinal).toBeGreaterThanOrEqual(lastOrdinal);
      lastOrdinal = ordinal;
    }
  });

  it("chaque borne basse de bande donne ce rang", () => {
    for (const band of RANK_BANDS) {
      expect(rankFromIndex(band.min)).toBe(band.rank);
      const justBelowMax = band.rank === "elite" ? band.max : band.max - 0.1;
      expect(rankFromIndex(justBelowMax)).toBe(band.rank);
    }
  });
});

describe("clampIndex", () => {
  it("clampe dans [40,100] (plancher 40, jamais 0)", () => {
    expect(clampIndex(-50)).toBe(40);
    expect(clampIndex(1500)).toBe(100);
    expect(clampIndex(Number.NaN)).toBe(40);
    expect(rankFromIndex(-10)).toBe("rookie");
    expect(rankFromIndex(2000)).toBe("elite");
  });
});

describe("rankProgress", () => {
  it("calcule la progression vers le rang suivant", () => {
    const p = rankProgress(75); // en Or [72,79)
    expect(p.current).toBe("gold");
    expect(p.next).toBe("platinum");
    expect(p.pointsToNext).toBe(4); // « Encore 4 pts avant PLATINE » (79 - 75)
    expect(p.progress).toBeCloseTo((75 - 72) / (79 - 72), 5);
  });

  it("au rang max (elite), pas de suivant", () => {
    const p = rankProgress(95);
    expect(p.current).toBe("elite");
    expect(p.next).toBeNull();
    expect(p.pointsToNext).toBeNull();
    expect(p.progress).toBe(1);
  });

  it("renvoie le bon band complet", () => {
    expect(rankBandFromIndex(80)).toEqual({ rank: "platinum", min: 79, max: 85 });
  });
});
