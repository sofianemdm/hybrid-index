import { describe, expect, it } from "vitest";
import {
  type PointTableModel,
  clampPercentile,
  lognormalFromMedian,
  percentile,
  quantile,
  subScore,
} from "./distribution";

describe("percentile — log-normal (temps, dir=-1)", () => {
  // Grace H : µ_ln = ln(203) − 0.43²/2, σ_ln = 0.43 (worked example A).
  const graceH = { kind: "lognormal" as const, muLn: Math.log(203) - 0.43 ** 2 / 2, sigmaLn: 0.43, dir: -1 as const };

  it("plus rapide = meilleur percentile", () => {
    expect(percentile(150, graceH)).toBeGreaterThan(percentile(300, graceH));
  });

  it("R=270 s ≈ P 0.19 (cf. exemple A)", () => {
    expect(percentile(270, graceH)).toBeCloseTo(0.19, 1);
  });

  it("helper lognormalFromMedian pose la médiane à P≈0.5", () => {
    const m = lognormalFromMedian(200, 0.3, -1);
    expect(percentile(200, m)).toBeCloseTo(0.5, 2);
  });
});

describe("percentile — normal (reps, dir=+1)", () => {
  const pushupsH = { kind: "normal" as const, mu: 25, sigma: 11, dir: 1 as const };

  it("plus de reps = meilleur percentile", () => {
    expect(percentile(40, pushupsH)).toBeGreaterThan(percentile(25, pushupsH));
  });

  it("R=40 → P≈0.91 (cf. exemple A)", () => {
    expect(percentile(40, pushupsH)).toBeCloseTo(0.91, 1);
  });

  it("à la moyenne → P≈0.5", () => {
    expect(percentile(25, pushupsH)).toBeCloseTo(0.5, 2);
  });
});

describe("percentile — pointTable", () => {
  // 5 km H (RunRepeat) : nœuds {P→R(s)} P croissant, R décroissant (temps).
  const fiveKH: PointTableModel = {
    kind: "pointTable",
    dir: -1,
    nodes: [
      { p: 0.1, r: 3202 },
      { p: 0.5, r: 1878 },
      { p: 0.9, r: 1326 },
      { p: 0.99, r: 1069 },
    ],
  };

  it("interpole P entre deux nœuds (R=1440 → 0.817, cf. exemple A)", () => {
    expect(percentile(1440, fiveKH)).toBeCloseTo(0.817, 2);
  });

  it("aux nœuds exacts, renvoie le P du nœud", () => {
    expect(percentile(1878, fiveKH)).toBeCloseTo(0.5, 3);
    expect(percentile(1326, fiveKH)).toBeCloseTo(0.9, 3);
  });

  it("extrapole et clampe au-delà des extrêmes", () => {
    expect(percentile(500, fiveKH)).toBeLessThanOrEqual(0.999);
    expect(percentile(500, fiveKH)).toBeGreaterThan(0.9);
    expect(percentile(9999, fiveKH)).toBeGreaterThanOrEqual(0.001);
  });
});

describe("clamp & sous-score bout-en-bout", () => {
  const pushupsH = { kind: "normal" as const, mu: 25, sigma: 11, dir: 1 as const };

  it("percentile toujours dans [0.001, 0.999]", () => {
    expect(clampPercentile(2)).toBe(0.999);
    expect(clampPercentile(-1)).toBe(0.001);
    expect(clampPercentile(Number.NaN)).toBe(0.001);
  });

  it("subScore(R) = courbe(percentile(R)) — pompes H R=40 → ~958", () => {
    // ±2 : aux percentiles extrêmes, l'arrondi entier dépend de la précision de Φ (957–958).
    expect(subScore(40, pushupsH)).toBeGreaterThanOrEqual(956);
    expect(subScore(40, pushupsH)).toBeLessThanOrEqual(959);
  });
});

describe("quantile — inverse de percentile", () => {
  const graceH = { kind: "lognormal" as const, muLn: Math.log(203) - 0.43 ** 2 / 2, sigmaLn: 0.43, dir: -1 as const };
  const pushupsH = { kind: "normal" as const, mu: 25, sigma: 11, dir: 1 as const };
  const fiveKH: PointTableModel = {
    kind: "pointTable",
    dir: -1,
    nodes: [
      { p: 0.1, r: 3202 },
      { p: 0.5, r: 1878 },
      { p: 0.9, r: 1326 },
      { p: 0.99, r: 1069 },
    ],
  };

  it("lognormal (temps, dir=-1) : aller-retour quantile(percentile(r)) ≈ r", () => {
    // ~3 décimales : l'aller-retour est borné par la précision de la CDF directe (erf A&S),
    // amplifiée dans les queues. Suffisant pour prouver la réciprocité quantile∘percentile=id.
    for (const r of [150, 203, 270, 350]) {
      expect(quantile(percentile(r, graceH), graceH)).toBeCloseTo(r, 3);
    }
  });

  it("lognormal : à P=0.5 renvoie la médiane (= exp(muLn))", () => {
    const m = lognormalFromMedian(200, 0.3, -1);
    expect(quantile(0.5, m)).toBeCloseTo(200, 6);
  });

  it("lognormal : dir=-1 ⇒ percentile plus haut = temps plus bas (meilleur)", () => {
    expect(quantile(0.9, graceH)).toBeLessThan(quantile(0.5, graceH));
  });

  it("normal (reps, dir=+1) : aller-retour quantile(percentile(r)) ≈ r", () => {
    // ~3 décimales (idem) : borné par la CDF directe, surtout aux valeurs extrêmes (r=55 ≈ P0.997).
    for (const r of [10, 25, 40, 55]) {
      expect(quantile(percentile(r, pushupsH), pushupsH)).toBeCloseTo(r, 3);
    }
  });

  it("normal : à P=0.5 renvoie la moyenne ; dir=+1 ⇒ P haut = plus de reps", () => {
    expect(quantile(0.5, pushupsH)).toBeCloseTo(25, 6);
    expect(quantile(0.9, pushupsH)).toBeGreaterThan(quantile(0.5, pushupsH));
  });

  it("pointTable : aux nœuds exacts, renvoie le R du nœud", () => {
    expect(quantile(0.5, fiveKH)).toBeCloseTo(1878, 6);
    expect(quantile(0.9, fiveKH)).toBeCloseTo(1326, 6);
  });

  it("pointTable : aller-retour entre deux nœuds (R=1440)", () => {
    expect(quantile(percentile(1440, fiveKH), fiveKH)).toBeCloseTo(1440, 6);
  });

  it("clampe P aux extrêmes (reste fini, monotone)", () => {
    expect(Number.isFinite(quantile(0, graceH))).toBe(true);
    expect(Number.isFinite(quantile(1, graceH))).toBe(true);
    // P=1 (clampé à 0.999) ⇒ temps le plus bas atteignable.
    expect(quantile(1, graceH)).toBeLessThan(quantile(0.5, graceH));
  });
});
