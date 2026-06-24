import { describe, expect, it } from "vitest";
import type { AttributeKey, Sex } from "@hybrid-index/contracts";
import type { AttributeResult } from "./attribute";
import { P_MAX, P_MIN } from "./distribution";
import {
  POP_BAND_ORDER,
  POP_NORMS_V1,
  POPNORM_VERSION,
  bandFromP,
  popPercentileAttr,
  popPercentileIndex,
} from "./population-norms";

const ATTRS: AttributeKey[] = ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"];
const SEXES: Sex[] = ["male", "female"];

const attr = (attribute: AttributeKey, score: number, opts: Partial<AttributeResult> = {}): AttributeResult => ({
  attribute,
  score,
  unlocked: true,
  isEstimated: false,
  isStale: false,
  bestAgeWeeks: 0,
  ...opts,
});

describe("POP_BAND_ORDER — cohérence avec bandFromP (régression BUG-006)", () => {
  it("toute bande renvoyée par bandFromP existe dans POP_BAND_ORDER", () => {
    for (let i = 0; i <= 1000; i++) {
      const popP = i / 1000;
      const { band } = bandFromP(popP);
      expect(POP_BAND_ORDER).toContain(band);
    }
  });

  it("une montée de bande est détectable (index strictement décroissant = meilleur)", () => {
    // pop_top_50 (large) doit être APRÈS pop_top_15 (plus rare) dans l'ordre best→worst.
    expect(POP_BAND_ORDER.indexOf("pop_top_15")).toBeLessThan(POP_BAND_ORDER.indexOf("pop_top_50"));
    expect(POP_BAND_ORDER.indexOf("pop_top_50")).toBeLessThan(POP_BAND_ORDER.indexOf("pop_building"));
    // Les bandes réellement produites 15/25/35 sont présentes (l'ancien BAND_ORDER les omettait).
    for (const b of ["pop_top_15", "pop_top_25", "pop_top_35"]) expect(POP_BAND_ORDER).toContain(b);
  });
});

describe("popnorm-v1 — version + tables", () => {
  it("est versionné", () => {
    expect(POPNORM_VERSION).toBe("popnorm-v1");
  });

  it("couvre les 6 attributs pour les 2 sexes", () => {
    for (const sex of SEXES) {
      for (const a of ATTRS) {
        expect(POP_NORMS_V1[sex][a]).toBeDefined();
        expect(POP_NORMS_V1[sex][a].nodes.length).toBeGreaterThanOrEqual(5);
      }
    }
  });
});

describe("popPercentileAttr — monotonie & bornes", () => {
  it("croît strictement avec le sous-score (meilleur effort ⇒ meilleur percentile population)", () => {
    for (const sex of SEXES) {
      for (const a of ATTRS) {
        let prev = -1;
        for (const s of [100, 250, 400, 550, 700, 850, 1000]) {
          const p = popPercentileAttr(sex, a, s);
          expect(p).toBeGreaterThan(prev);
          prev = p;
        }
      }
    }
  });

  it("reste borné dans [P_MIN, P_MAX] même hors plage (0 et 1000+)", () => {
    for (const sex of SEXES) {
      for (const a of ATTRS) {
        expect(popPercentileAttr(sex, a, 0)).toBeGreaterThanOrEqual(P_MIN);
        expect(popPercentileAttr(sex, a, 2000)).toBeLessThanOrEqual(P_MAX);
      }
    }
  });
});

describe("invariant produit — un débutant de l'app est déjà bien placé dans la population", () => {
  it("sous-score médian compétitif (450) ⇒ déjà ≥ top 40% des humains", () => {
    // Le plancher population est structurellement élevé (médiane compétitive ≈ 450 ≫ adulte médian).
    for (const sex of SEXES) {
      const radar = ATTRS.map((a) => attr(a, 450));
      const p = popPercentileIndex(sex, "all_round", radar);
      expect(p).toBeGreaterThanOrEqual(0.6);
    }
  });
});

describe("popPercentileIndex — agrégation no-drop", () => {
  it("ignore les attributs verrouillés (ne tirent jamais vers le bas)", () => {
    const sex: Sex = "male";
    const strong = attr("engine", 850);
    const withLocked = popPercentileIndex(sex, "all_round", [strong, attr("strength", 0, { unlocked: false })]);
    const aloneUnlocked = popPercentileIndex(sex, "all_round", [strong]);
    expect(withLocked).toBeCloseTo(aloneUnlocked, 6);
  });

  it("défaut prudent (~top 70%) si aucun attribut débloqué", () => {
    const p = popPercentileIndex("female", "hyrox", [attr("engine", 800, { unlocked: false })]);
    expect(p).toBeCloseTo(0.3, 6);
  });

  it("un meilleur radar donne un meilleur percentile population", () => {
    const sex: Sex = "male";
    const weak = ATTRS.map((a) => attr(a, 300));
    const strong = ATTRS.map((a) => attr(a, 800));
    expect(popPercentileIndex(sex, "all_round", strong)).toBeGreaterThan(
      popPercentileIndex(sex, "all_round", weak),
    );
  });
});

describe("bandFromP — paliers honnêtes", () => {
  it("arrondit au palier atteint, jamais de décimale sous 1%", () => {
    expect(bandFromP(0.991)).toEqual({ topPercent: 1, band: "pop_top_1" });
    expect(bandFromP(0.985)).toEqual({ topPercent: 2, band: "pop_top_2" });
    expect(bandFromP(0.962)).toEqual({ topPercent: 5, band: "pop_top_5" });
    expect(bandFromP(0.91)).toEqual({ topPercent: 10, band: "pop_top_10" });
    expect(bandFromP(0.88)).toEqual({ topPercent: 15, band: "pop_top_15" }); // palier 15 (recalibrage population)
    expect(bandFromP(0.7)).toEqual({ topPercent: 35, band: "pop_top_35" }); // bandes affinées : 30 → 35
    expect(bandFromP(0.5)).toEqual({ topPercent: 50, band: "pop_top_50" });
  });

  it("sous la médiane ⇒ bande « en construction » (pas de top%)", () => {
    expect(bandFromP(0.4)).toEqual({ topPercent: null, band: "pop_building" });
    expect(bandFromP(0.001)).toEqual({ topPercent: null, band: "pop_building" });
  });

  it("monter en percentile fait baisser (ou maintenir) le top% affiché", () => {
    const a = bandFromP(0.92).topPercent ?? 100;
    const b = bandFromP(0.97).topPercent ?? 100;
    expect(b).toBeLessThanOrEqual(a);
  });
});
