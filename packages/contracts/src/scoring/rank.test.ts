import { describe, expect, it } from "vitest";
import { RANK_BANDS } from "../enums";
import { clampIndex, rankBandFromIndex, rankFromIndex, rankProgress } from "./rank";

describe("rankFromIndex", () => {
  it("mappe les valeurs de référence du cahier (§9.2)", () => {
    expect(rankFromIndex(0)).toBe("rookie");
    expect(rankFromIndex(149)).toBe("rookie");
    expect(rankFromIndex(150)).toBe("bronze");
    expect(rankFromIndex(299)).toBe("bronze");
    expect(rankFromIndex(300)).toBe("argent");
    expect(rankFromIndex(450)).toBe("or");
    expect(rankFromIndex(499)).toBe("or"); // exemple A après correctif D2
    expect(rankFromIndex(600)).toBe("platine");
    expect(rankFromIndex(719)).toBe("platine");
    expect(rankFromIndex(750)).toBe("diamant");
    expect(rankFromIndex(775)).toBe("diamant"); // exemple B
    expect(rankFromIndex(900)).toBe("elite");
    expect(rankFromIndex(1000)).toBe("elite");
  });

  it("est monotone : le rang ne régresse jamais quand l'Index augmente", () => {
    let lastOrdinal = -1;
    for (let v = 0; v <= 1000; v += 1) {
      const ordinal = RANK_BANDS.findIndex((b) => b.rank === rankFromIndex(v));
      expect(ordinal).toBeGreaterThanOrEqual(lastOrdinal);
      lastOrdinal = ordinal;
    }
  });

  it("respecte exactement les bornes [min, max) de chaque bande", () => {
    for (const band of RANK_BANDS) {
      expect(rankFromIndex(band.min)).toBe(band.rank);
      const justBelowMax = band.rank === "elite" ? band.max : band.max - 1;
      expect(rankFromIndex(justBelowMax)).toBe(band.rank);
    }
  });

  it("clampe les valeurs hors plage", () => {
    expect(clampIndex(-50)).toBe(0);
    expect(clampIndex(1500)).toBe(1000);
    expect(clampIndex(Number.NaN)).toBe(0);
    expect(rankFromIndex(-10)).toBe("rookie");
    expect(rankFromIndex(2000)).toBe("elite");
  });
});

describe("rankProgress", () => {
  it("calcule les points avant le prochain rang", () => {
    const p = rankProgress(553); // en Or [450,600)
    expect(p.current).toBe("or");
    expect(p.next).toBe("platine");
    expect(p.pointsToNext).toBe(47); // « Encore 47 pts avant PLATINE » (cahier §4.3)
    expect(p.progress).toBeCloseTo((553 - 450) / 150, 5);
  });

  it("gère le dernier rang (elite) sans suivant", () => {
    const p = rankProgress(950);
    expect(p.current).toBe("elite");
    expect(p.next).toBeNull();
    expect(p.pointsToNext).toBeNull();
    expect(p.progress).toBe(1);
  });

  it("renvoie le bon band complet", () => {
    expect(rankBandFromIndex(600)).toEqual({ rank: "platine", min: 600, max: 750 });
  });
});
