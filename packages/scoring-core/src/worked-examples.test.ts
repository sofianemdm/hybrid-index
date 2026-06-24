import { describe, expect, it } from "vitest";
import { type DistributionModel, type PointTableModel, subScore } from "./distribution";
import { type ScoredEffort, computeRadar } from "./attribute";
import { hybridIndex } from "./index-score";
import { rankFromIndex } from "@hybrid-index/contracts";

/**
 * Reproduction bout-en-bout des worked examples de sport-science §9 (R brut → Index).
 * Les distributions ci-dessous sont seedées depuis §2.2/§2.3. Les sous-scores dépendent de
 * la précision de Φ et des arrondis : on vérifie donc l'Index à ±3 de la cible de la spec
 * (les tests d'agrégation exacts sont dans index-score.test.ts).
 */

// --- Distributions de référence utilisées par les exemples ---
const graceH: DistributionModel = {
  kind: "lognormal",
  muLn: Math.log(203) - 0.43 ** 2 / 2,
  sigmaLn: 0.43,
  dir: -1,
};
const pushupsH: DistributionModel = { kind: "normal", mu: 25, sigma: 11, dir: 1 };
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
const rowF: DistributionModel = { kind: "lognormal", muLn: Math.log(510), sigmaLn: 0.085, dir: -1 };
const pushupsF: DistributionModel = { kind: "normal", mu: 12, sigma: 7, dir: 1 };
const benchmarkZeroF: PointTableModel = {
  kind: "pointTable",
  dir: -1,
  nodes: [
    { p: 0.1, r: 1380 },
    { p: 0.25, r: 1140 },
    { p: 0.5, r: 960 },
    { p: 0.75, r: 810 },
    { p: 0.9, r: 720 },
    { p: 0.99, r: 630 },
  ],
};

describe("Worked example A — Homme, objectif 'Partout', 3 efforts → ~499 interne / OVR 57 (SILVER)", () => {
  it("reproduit l'Index (D2 : Grace fait autorité sur le proxy pompes)", () => {
    const grace = subScore(270, graceH); // ~76 (strength + power)
    const fiveK = subScore(1440, fiveKH); // 884 (engine)
    const pushups = subScore(40, pushupsH); // 958 (muscular_endurance + strength PROXY)

    const efforts: ScoredEffort[] = [
      { subScore: grace, ageWeeks: 1, tags: [{ attribute: "power", estimated: false }, { attribute: "strength", estimated: false }] },
      { subScore: fiveK, ageWeeks: 1, tags: [{ attribute: "engine", estimated: false }] },
      { subScore: pushups, ageWeeks: 1, tags: [{ attribute: "muscular_endurance", estimated: false }, { attribute: "strength", estimated: true }] },
    ];

    const radar = computeRadar(["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"], efforts);
    const strength = radar.find((a) => a.attribute === "strength")!;
    // D2 : strength = Grace (réel), PAS le proxy pompes 958.
    expect(strength.score).toBe(grace);
    expect(strength.isEstimated).toBe(false);

    const index = hybridIndex(radar, "all_round", 3);
    expect(index.value).toBeGreaterThanOrEqual(496);
    expect(index.value).toBeLessThanOrEqual(500);
    expect(index.radarCoverage).toBe(4);
    expect(index.isProvisional).toBe(false);
    // Affichage /100 (display-v2, recalibration pro) : index interne ~499 (P≈0.54) → OVR 57 = silver (médian régulier).
    expect(index.ratingInt).toBe(57);
    expect(rankFromIndex(index.ratingInt!)).toBe("silver");
  });
});

describe("Worked example B — Femme, objectif 'HYROX', 3 efforts → ~775 interne / OVR 64 (GOLD)", () => {
  it("reproduit l'Index (Force en proxy → isEstimated)", () => {
    const row = subScore(480, rowF); // ~825/827 (engine)
    const bz = subScore(900, benchmarkZeroF); // 597 (engine, muscular_endurance, hybrid)
    const pushups = subScore(18, pushupsF); // ~871/872 (muscular_endurance + strength PROXY)

    const efforts: ScoredEffort[] = [
      { subScore: row, ageWeeks: 1, tags: [{ attribute: "engine", estimated: false }] },
      {
        subScore: bz,
        ageWeeks: 1,
        tags: [
          { attribute: "engine", estimated: false },
          { attribute: "muscular_endurance", estimated: false },
          { attribute: "hybrid", estimated: false },
        ],
      },
      { subScore: pushups, ageWeeks: 1, tags: [{ attribute: "muscular_endurance", estimated: false }, { attribute: "strength", estimated: true }] },
    ];

    const radar = computeRadar(["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"], efforts);
    const strength = radar.find((a) => a.attribute === "strength")!;
    expect(strength.isEstimated).toBe(true); // aucun test chargé

    const index = hybridIndex(radar, "hyrox", 3);
    expect(index.value).toBeGreaterThanOrEqual(772);
    expect(index.value).toBeLessThanOrEqual(778);
    expect(index.isEstimated).toBe(true);
    // Affichage /100 (display-v2, recalibration pro) : index interne ~775 (P≈0.72) → OVR 64 = gold.
    expect(index.ratingInt).toBe(64);
    expect(rankFromIndex(index.ratingInt!)).toBe("gold");
  });
});
