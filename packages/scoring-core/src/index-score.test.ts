import { describe, expect, it } from "vitest";
import type { AttributeResult } from "./attribute";
import { coverageAdjustedValue, hybridIndex, indexPercentile, projectedIndex } from "./index-score";
import { ratingFromInternal } from "./curve";

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

  it("provisoire : < 3 attributs ET < 3 efforts", () => {
    expect(hybridIndex([attr("engine", 500)], "all_round", 1).isProvisional).toBe(true);
    expect(hybridIndex([attr("engine", 500)], "all_round", 3).isProvisional).toBe(false); // 3 efforts
    expect(
      hybridIndex([attr("engine", 1), attr("speed", 1), attr("strength", 1)], "all_round", 1).isProvisional,
    ).toBe(false); // 3 attributs (seuil abaissé 4→3, cf. « 3 séances = Index complet »)
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

describe("coverageAdjustedValue (ajustement de couverture, appliqué à la persistance)", () => {
  it("1 seul attribut : la valeur est tirée vers la médiane (l'OVR n'est plus la valeur brute)", () => {
    const adj = coverageAdjustedValue(832, 1);
    expect(adj).toBeLessThan(832); // tiré vers le bas (5/6 du profil présumé médian)
    // 832 vaut ~84 à couverture pleine ; à 1/6 mesuré l'OVR ajusté est nettement plus bas.
    expect(Math.round(ratingFromInternal(adj))).toBeGreaterThan(55);
    expect(Math.round(ratingFromInternal(adj))).toBeLessThan(78);
  });

  it("monotone : plus la couverture est élevée, plus la valeur ajustée remonte", () => {
    const c1 = coverageAdjustedValue(832, 1);
    const c3 = coverageAdjustedValue(832, 3);
    const c6 = coverageAdjustedValue(832, 6);
    expect(c3).toBeGreaterThanOrEqual(c1);
    expect(c6).toBeGreaterThanOrEqual(c3);
  });

  it("couverture pleine (6/6) : AUCUN ajustement (valeur inchangée, pas de déflation)", () => {
    expect(coverageAdjustedValue(832, 6)).toBe(832);
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
