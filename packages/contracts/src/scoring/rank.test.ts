import { describe, expect, it } from "vitest";
import { RANK_BANDS } from "../enums";
import { clampIndex, rankBandFromIndex, rankFromIndex, rankProgress } from "./rank";

// Bandes recalibrées display-v2 (2026-06-24) :
// rookie [40,44) bronze [44,52) silver [52,64) gold [64,73) platinum [73,85) diamond [85,92) elite [92,100].
describe("rankFromIndex", () => {
  it("mappe chaque OVR /100 sur le bon rang", () => {
    expect(rankFromIndex(40)).toBe("rookie");
    expect(rankFromIndex(43)).toBe("rookie");
    expect(rankFromIndex(44)).toBe("bronze"); // débutant display-v2
    expect(rankFromIndex(51)).toBe("bronze");
    expect(rankFromIndex(52)).toBe("silver");
    expect(rankFromIndex(57)).toBe("silver"); // médian display-v2
    expect(rankFromIndex(63)).toBe("silver"); // au-dessus de la moyenne
    expect(rankFromIndex(64)).toBe("gold");
    expect(rankFromIndex(72)).toBe("gold");
    expect(rankFromIndex(73)).toBe("platinum");
    expect(rankFromIndex(77)).toBe("platinum"); // BON pratiquant display-v2
    expect(rankFromIndex(84)).toBe("platinum"); // très bon amateur
    expect(rankFromIndex(85)).toBe("diamond");
    expect(rankFromIndex(88)).toBe("diamond"); // élite nationale display-v2
    expect(rankFromIndex(92)).toBe("elite");
    expect(rankFromIndex(93)).toBe("elite"); // pro / élite internationale
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
    const p = rankProgress(70); // en Or [64,73)
    expect(p.current).toBe("gold");
    expect(p.next).toBe("platinum");
    expect(p.pointsToNext).toBe(3); // « Encore 3 pts avant PLATINE » (73 - 70)
    expect(p.progress).toBeCloseTo((70 - 64) / (73 - 64), 5);
  });

  it("au rang max (elite), pas de suivant", () => {
    const p = rankProgress(95);
    expect(p.current).toBe("elite");
    expect(p.next).toBeNull();
    expect(p.pointsToNext).toBeNull();
    expect(p.progress).toBe(1);
  });

  it("renvoie le bon band complet", () => {
    expect(rankBandFromIndex(80)).toEqual({ rank: "platinum", min: 73, max: 85 });
  });
});
