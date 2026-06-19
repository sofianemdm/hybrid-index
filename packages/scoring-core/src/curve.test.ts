import { describe, expect, it } from "vitest";
import { curveF, SIGMOID_V1, subScoreFromPercentile } from "./curve";

describe("curveF / subScoreFromPercentile (sigmoid-v1, k=6, P0=0.55)", () => {
  // Valeurs EXACTES recalculées depuis la formule (source de vérité, versionnée).
  // NB : corrige l'erratum de la table illustrative §4.3 de sport-science-scoring.md
  // (qui affichait 22/115/969 au lieu de 30/118/949). Le worked example A de la spec, lui,
  // utilise la formule correctement.
  const table: Array<[number, number]> = [
    [0.01, 2],
    [0.1, 30],
    [0.25, 118],
    [0.5, 433], // cible « médiane population ≈ 450 »
    [0.55, 515],
    [0.75, 813],
    [0.9, 949],
    [0.99, 996],
  ];

  it.each(table)("P=%d → sous-score %d", (p, expected) => {
    expect(subScoreFromPercentile(p)).toBe(expected);
  });

  it("f(0)=0 et f(1)=1 (renormalisation des extrêmes)", () => {
    expect(curveF(0)).toBeCloseTo(0, 6);
    expect(curveF(1)).toBeCloseTo(1, 6);
  });

  it("strictement monotone croissante sur [0,1]", () => {
    let prev = -1;
    for (let p = 0; p <= 1.00001; p += 0.01) {
      const f = curveF(Math.min(1, p));
      expect(f).toBeGreaterThan(prev);
      prev = f;
    }
  });

  it("borne le sous-score dans [0,1000]", () => {
    expect(subScoreFromPercentile(0)).toBeGreaterThanOrEqual(0);
    expect(subScoreFromPercentile(1)).toBeLessThanOrEqual(1000);
    expect(subScoreFromPercentile(1)).toBe(1000);
  });

  it("la médiane (P=0.5) tombe dans la cible 430–470", () => {
    const s = subScoreFromPercentile(0.5);
    expect(s).toBeGreaterThanOrEqual(430);
    expect(s).toBeLessThanOrEqual(470);
  });

  it("gains rapides au milieu, lents aux extrêmes (pente)", () => {
    const slopeMid = curveF(0.6) - curveF(0.4);
    const slopeLow = curveF(0.15) - curveF(0.05);
    const slopeHigh = curveF(0.95) - curveF(0.85);
    expect(slopeMid).toBeGreaterThan(slopeLow);
    expect(slopeMid).toBeGreaterThan(slopeHigh);
  });

  it("les paramètres par défaut sont sigmoid-v1", () => {
    expect(SIGMOID_V1).toEqual({ k: 6.0, p0: 0.55 });
  });
});
