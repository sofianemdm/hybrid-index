import { describe, expect, it } from "vitest";
import { erf, normalCdf } from "./normal";

describe("normalCdf (Φ)", () => {
  it("Φ(0) = 0.5", () => {
    expect(normalCdf(0)).toBeCloseTo(0.5, 6);
  });

  it("valeurs de référence connues", () => {
    expect(normalCdf(1)).toBeCloseTo(0.8413, 3);
    expect(normalCdf(-1)).toBeCloseTo(0.1587, 3);
    expect(normalCdf(1.96)).toBeCloseTo(0.975, 3);
    expect(normalCdf(2.32)).toBeCloseTo(0.9898, 3); // exemple B : z=2.32 → ~99 %
  });

  it("symétrie Φ(z) + Φ(−z) = 1", () => {
    for (const z of [0.3, 0.857, 1.5, 2.1]) {
      expect(normalCdf(z) + normalCdf(-z)).toBeCloseTo(1, 6);
    }
  });

  it("monotone croissante", () => {
    let prev = -Infinity;
    for (let z = -4; z <= 4; z += 0.1) {
      const v = normalCdf(z);
      expect(v).toBeGreaterThanOrEqual(prev);
      prev = v;
    }
  });

  it("erf impaire", () => {
    expect(erf(0)).toBeCloseTo(0, 6);
    expect(erf(0.5)).toBeCloseTo(-erf(-0.5), 6);
  });
});
