import { describe, expect, it } from "vitest";
import { ratingFromPercentile, ratingFromInternal, percentileFromInternal, subScoreFromPercentile } from "./curve";

/**
 * display-v1 : note /100 « type FIFA » ancrée sur le niveau réel.
 * On verrouille la forme (plancher, médiane, compression du haut) et la monotonie.
 */
describe("ratingFromPercentile — courbe d'affichage /100", () => {
  it("plancher ~35 au plus bas, sommet ~98 (< 100) au plus haut", () => {
    expect(ratingFromPercentile(0)).toBeCloseTo(35, 1);
    expect(ratingFromPercentile(1)).toBeGreaterThan(96);
    expect(ratingFromPercentile(1)).toBeLessThan(100);
  });

  it("respecte le barème : peu entraîné ~37, débutant ~46, médiane ~63, bon niveau ~83, top box ~90", () => {
    // P=0.1 = bas de population (peu entraîné) → ~37 ; un débutant « complet » est plutôt vers P=0.3 → ~46.
    expect(ratingFromPercentile(0.1)).toBeGreaterThanOrEqual(35);
    expect(ratingFromPercentile(0.1)).toBeLessThanOrEqual(41);
    expect(ratingFromPercentile(0.3)).toBeGreaterThanOrEqual(43);
    expect(ratingFromPercentile(0.3)).toBeLessThanOrEqual(49);
    expect(ratingFromPercentile(0.5)).toBeGreaterThanOrEqual(60);
    expect(ratingFromPercentile(0.5)).toBeLessThanOrEqual(66);
    expect(ratingFromPercentile(0.75)).toBeGreaterThanOrEqual(81);
    expect(ratingFromPercentile(0.75)).toBeLessThanOrEqual(86);
    expect(ratingFromPercentile(0.9)).toBeGreaterThanOrEqual(87);
    expect(ratingFromPercentile(0.9)).toBeLessThanOrEqual(92);
  });

  it("sommet différencié : pro (P≈0.97) ~95, record (P≈0.999) ~98, sans tout aplatir", () => {
    expect(ratingFromPercentile(0.97)).toBeGreaterThanOrEqual(93);
    expect(ratingFromPercentile(0.97)).toBeLessThanOrEqual(97);
    expect(ratingFromPercentile(0.999)).toBeGreaterThanOrEqual(96);
    expect(ratingFromPercentile(0.999)).toBeLessThan(99);
    // Différenciation préservée entre « top box » et « pro » (≥ 3 points d'écart).
    expect(ratingFromPercentile(0.97) - ratingFromPercentile(0.9)).toBeGreaterThanOrEqual(3);
  });

  it("est strictement monotone croissante", () => {
    let prev = -1;
    for (let p = 0; p <= 1.0001; p += 0.05) {
      const r = ratingFromPercentile(Math.min(1, p));
      expect(r).toBeGreaterThan(prev);
      prev = r;
    }
  });
});

describe("percentileFromInternal — inverse de sigmoid-v1", () => {
  it("récupère le percentile d'origine d'un sous-score (aller-retour)", () => {
    for (const p of [0.1, 0.25, 0.5, 0.75, 0.9]) {
      const sub = subScoreFromPercentile(p);
      expect(percentileFromInternal(sub)).toBeCloseTo(p, 2);
    }
  });

  it("la médiane interne (~433) redonne bien P≈0.5 → OVR ~63", () => {
    const sub = subScoreFromPercentile(0.5); // ~433
    expect(ratingFromInternal(sub)).toBeGreaterThanOrEqual(62);
    expect(ratingFromInternal(sub)).toBeLessThanOrEqual(64);
  });
});
