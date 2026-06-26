import { describe, expect, it } from "vitest";
import { erf, normalCdf, normInv } from "./normal";

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

describe("normInv (Φ⁻¹)", () => {
  it("Φ⁻¹(0.5) = 0", () => {
    expect(normInv(0.5)).toBeCloseTo(0, 6);
  });

  it("valeurs de référence connues", () => {
    expect(normInv(0.975)).toBeCloseTo(1.959964, 4);
    expect(normInv(0.8413)).toBeCloseTo(1, 3);
    expect(normInv(0.1587)).toBeCloseTo(-1, 3);
    expect(normInv(0.99)).toBeCloseTo(2.326348, 4);
  });

  it("réciproque de normalCdf (aller-retour sur tout le domaine)", () => {
    // Tolérance 3 décimales : la PRÉCISION DE L'ALLER-RETOUR est bornée par l'erreur de la CDF
    // directe (erf A&S, ~1.5e-7), amplifiée dans les queues où la pente de Φ⁻¹ est forte.
    // `normInv` lui-même est exact à ~1e-9 (cf. les valeurs de référence ci-dessus).
    for (const z of [-3, -2.1, -1, -0.3, 0, 0.857, 1.5, 2.32, 3]) {
      expect(normInv(normalCdf(z))).toBeCloseTo(z, 3);
    }
  });

  it("réciproque dans l'autre sens : normalCdf(normInv(p)) ≈ p", () => {
    for (const p of [0.001, 0.02, 0.1, 0.5, 0.9, 0.98, 0.999]) {
      expect(normalCdf(normInv(p))).toBeCloseTo(p, 4);
    }
  });

  it("antisymétrie Φ⁻¹(p) = −Φ⁻¹(1−p)", () => {
    for (const p of [0.05, 0.2, 0.37, 0.48]) {
      expect(normInv(p)).toBeCloseTo(-normInv(1 - p), 6);
    }
  });

  it("clampe les extrêmes (reste fini)", () => {
    expect(Number.isFinite(normInv(0))).toBe(true);
    expect(Number.isFinite(normInv(1))).toBe(true);
    expect(normInv(0)).toBeLessThan(0);
    expect(normInv(1)).toBeGreaterThan(0);
  });
});
