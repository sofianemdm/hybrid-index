import { describe, expect, it } from "vitest";
import type { AttributeResult } from "./attribute";
import { hybridIndex, indexPercentile, projectedIndex } from "./index-score";

const attr = (
  attribute: AttributeResult["attribute"],
  score: number,
  opts: Partial<AttributeResult> = {},
): AttributeResult => ({
  attribute,
  score,
  unlocked: true,
  isEstimated: false,
  isStale: false,
  bestAgeWeeks: 1,
  ...opts,
});

describe("hybridIndex", () => {
  it("moyenne pondérée sur attributs débloqués (poids égaux 'all_round')", () => {
    const radar = [attr("engine", 884), attr("strength", 76), attr("power", 76), attr("muscular_endurance", 958)];
    const r = hybridIndex(radar, "all_round", 3);
    expect(r.value).toBe(499); // (884+76+76+958)/4
    expect(r.radarCoverage).toBe(4);
  });

  it("ignore les attributs verrouillés (ne les compte pas comme 0)", () => {
    const radar = [attr("engine", 800), attr("strength", 0, { unlocked: false })];
    const r = hybridIndex(radar, "all_round", 1);
    expect(r.value).toBe(800);
    expect(r.radarCoverage).toBe(1);
  });

  it("applique les poids HYROX (surpondère engine + hybrid)", () => {
    const radar = [attr("engine", 825), attr("strength", 871), attr("muscular_endurance", 871), attr("hybrid", 597)];
    const r = hybridIndex(radar, "hyrox", 3);
    expect(r.value).toBe(775); // (1.5·825+0.7·871+1.3·871+1.5·597)/5
  });

  it("provisoire : < 4 attributs ET < 3 efforts", () => {
    expect(hybridIndex([attr("engine", 500)], "all_round", 1).isProvisional).toBe(true);
    expect(hybridIndex([attr("engine", 500)], "all_round", 3).isProvisional).toBe(false); // 3 efforts
    expect(
      hybridIndex([attr("engine", 1), attr("speed", 1), attr("strength", 1), attr("power", 1)], "all_round", 1)
        .isProvisional,
    ).toBe(false); // 4 attributs
  });

  it("isEstimated si un attribut entrant est estimé (proxy Force)", () => {
    const radar = [attr("engine", 825), attr("strength", 871, { isEstimated: true })];
    expect(hybridIndex(radar, "hyrox", 2).isEstimated).toBe(true);
  });

  it("aucun attribut débloqué → 0, provisoire", () => {
    const r = hybridIndex([], "all_round", 0);
    expect(r.value).toBe(0);
    expect(r.isProvisional).toBe(true);
  });
});

describe("indexPercentile (N(450,140))", () => {
  it("Index médian (450) ≈ 50e percentile", () => {
    expect(indexPercentile(450)).toBeCloseTo(0.5, 2);
  });
  it("Index élevé → percentile élevé (775 → ~99 %)", () => {
    expect(indexPercentile(775)).toBeGreaterThan(0.97);
  });
});

describe("projectedIndex", () => {
  it("simule l'Index si un attribut atteignait une cible (jamais < à l'actuel)", () => {
    const radar = [attr("engine", 884), attr("strength", 76), attr("power", 76), attr("muscular_endurance", 958)];
    const base = hybridIndex(radar, "all_round", 3).value; // 499
    const projected = projectedIndex(radar, "all_round", "strength", 800, 3).value;
    expect(projected).toBeGreaterThan(base); // amener la Force à 800 remonte l'Index
  });

  it("peut débloquer un attribut verrouillé pour la projection", () => {
    const radar = [attr("engine", 600)];
    const projected = projectedIndex(radar, "all_round", "hybrid", 800, 1);
    expect(projected.radarCoverage).toBe(2);
    expect(projected.value).toBe(700); // (600+800)/2
  });
});
