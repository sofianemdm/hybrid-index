import { describe, expect, it } from "vitest";
import { ratingFromPercentile, ratingFromInternal, percentileFromInternal, subScoreFromPercentile } from "./curve";

/**
 * display-v2 : note /100 « type FIFA » CALIBRÉE NIVEAU PRO (recalibration 24 juin).
 * On verrouille la forme (plancher, médiane plus basse, sommet réservé au quasi record-du-monde)
 * et la monotonie. Le sommet (~97) n'est atteint QUE pour un niveau quasi record-du-monde.
 */
describe("ratingFromPercentile — courbe d'affichage /100 (display-v2)", () => {
  it("plancher ~35 au plus bas, sommet ~98 (< 100) au plus haut", () => {
    expect(ratingFromPercentile(0)).toBeCloseTo(35, 1);
    expect(ratingFromPercentile(1)).toBeGreaterThan(96);
    expect(ratingFromPercentile(1)).toBeLessThan(100);
  });

  it("barème exigeant : sédentaire ~37, débutant ~45, médiane ~57, bon ~77, top box ~84", () => {
    // P=0.1 = bas de population (sédentaire) → ~37 ; un débutant est plutôt vers P=0.3 → ~45.
    expect(ratingFromPercentile(0.1)).toBeGreaterThanOrEqual(35);
    expect(ratingFromPercentile(0.1)).toBeLessThanOrEqual(40);
    expect(ratingFromPercentile(0.3)).toBeGreaterThanOrEqual(43);
    expect(ratingFromPercentile(0.3)).toBeLessThanOrEqual(47);
    expect(ratingFromPercentile(0.5)).toBeGreaterThanOrEqual(55);
    expect(ratingFromPercentile(0.5)).toBeLessThanOrEqual(59);
    // « bon mais pas élite » (~P0.85) plafonne autour de 77, JAMAIS dans les 90.
    expect(ratingFromPercentile(0.85)).toBeGreaterThanOrEqual(74);
    expect(ratingFromPercentile(0.85)).toBeLessThanOrEqual(80);
    // « top box » (~P0.9) ~84.
    expect(ratingFromPercentile(0.9)).toBeGreaterThanOrEqual(82);
    expect(ratingFromPercentile(0.9)).toBeLessThanOrEqual(86);
  });

  it("sommet réservé à l'élite : top box (P≈0.9) ~84, élite nationale (P≈0.97) ~88, pro (P≈0.99) ~94, record (P≈0.999) ~97", () => {
    expect(ratingFromPercentile(0.97)).toBeGreaterThanOrEqual(86);
    expect(ratingFromPercentile(0.97)).toBeLessThanOrEqual(90);
    expect(ratingFromPercentile(0.99)).toBeGreaterThanOrEqual(92);
    expect(ratingFromPercentile(0.99)).toBeLessThanOrEqual(95);
    expect(ratingFromPercentile(0.999)).toBeGreaterThanOrEqual(96);
    expect(ratingFromPercentile(0.999)).toBeLessThan(98.5);
    // Différenciation préservée entre « top box » et « élite nationale » (≥ 3 points d'écart).
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

  it("la médiane interne (~433) redonne bien P≈0.5 → OVR ~57 (display-v2)", () => {
    const sub = subScoreFromPercentile(0.5); // ~433
    expect(ratingFromInternal(sub)).toBeGreaterThanOrEqual(56);
    expect(ratingFromInternal(sub)).toBeLessThanOrEqual(58);
  });
});
