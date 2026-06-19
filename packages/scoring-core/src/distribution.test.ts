import { describe, expect, it } from "vitest";
import {
  type PointTableModel,
  clampPercentile,
  lognormalFromMedian,
  percentile,
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
