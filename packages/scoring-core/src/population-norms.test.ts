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

describe("popnorm-v2 — version + tables", () => {
  it("est versionné", () => {
    expect(POPNORM_VERSION).toBe("popnorm-v2");
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

describe("invariant produit — un pratiquant médian de l'app est déjà bien placé dans la population", () => {
  it("sous-score médian compétitif (450) ⇒ ~top 30-40% des humains (plancher structurellement élevé)", () => {
    // La médiane compétitive (≈450) ≫ adulte médian (sédentaire). En v2 on réaligne sur ~top 32%
    // (intention documentée), au lieu du ~top 15-40% trop généreux de v1.
    for (const sex of SEXES) {
      const radar = ATTRS.map((a) => attr(a, 450));
      const p = popPercentileIndex(sex, "all_round", radar);
      expect(p).toBeGreaterThanOrEqual(0.6); // ≥ top 40%
      expect(p).toBeLessThanOrEqual(0.75); // mais PAS top 25% : l'honnêteté du median tient
    }
  });
});

describe("popnorm-v2 — agrégation top-lourde gardée (cibles de calibration verrouillées)", () => {
  // Profil « sofiane » : cardio/vitesse ÉLITE + très bonne endurance, force/puissance NON entraînées.
  // v1 (moyenne pondérée) écrasait ce profil à ~top 35% (FAUX vs population générale sédentaire).
  // v2 doit le faire ressortir ~top 5-10% : la rareté se mesure par les MEILLEURS marqueurs.
  const sofiane = [
    attr("engine", 992),
    attr("speed", 992),
    attr("muscular_endurance", 813),
    attr("hybrid", 813),
    attr("strength", 137),
    attr("power", 137),
  ];

  it("profil pointu élite-cardio (sofiane) ⇒ ~top 5-10% (et surtout PLUS top 35%)", () => {
    const p = popPercentileIndex("male", "all_round", sofiane);
    expect(1 - p).toBeGreaterThanOrEqual(0.04); // ≥ top 4% (pas surévalué)
    expect(1 - p).toBeLessThanOrEqual(0.1); // ≤ top 10% (le correctif clé)
    expect(p).toBeGreaterThan(0.85); // strictement mieux que l'ancien ~0.69 (« top 35% »)
  });

  it("le profil pointu n'est PAS tiré vers le bas par ses 2 attributs non entraînés", () => {
    // La moyenne pondérée classique (référence v1) le situerait sous top 35% ; v2 doit faire bien mieux.
    const v1LikeWeightedMean =
      sofiane.reduce((s, a) => s + popPercentileAttr("male", a.attribute, a.score), 0) / sofiane.length;
    expect(v1LikeWeightedMean).toBeLessThan(0.72); // ~0.69 : démontre le défaut de l'agrégation v1
    expect(popPercentileIndex("male", "all_round", sofiane)).toBeGreaterThan(v1LikeWeightedMean + 0.15);
  });

  it("débutant générique (tous attributs 150-300, aucun point fort) reste « en construction » / ~médian", () => {
    // GARDE-FOU de cohérence : l'effet top-lourd ne doit PAS propulser un vrai débutant.
    for (const sex of SEXES) {
      const radar = ATTRS.map((a, i) => attr(a, 200 + (i % 4) * 30)); // 200..290, aucun > 350
      const p = popPercentileIndex(sex, "all_round", radar);
      expect(p).toBeLessThanOrEqual(0.6); // top 40% au mieux : jamais propulsé en haut
      expect(p).toBeGreaterThanOrEqual(0.3); // mais jamais dévalorisant non plus
    }
  });

  it("athlète complet (tous attributs 700-900) ⇒ ~top 1-3%", () => {
    for (const sex of SEXES) {
      const radar = ATTRS.map((a, i) => attr(a, 750 + (i % 3) * 60)); // 750..870
      const p = popPercentileIndex(sex, "all_round", radar);
      expect(1 - p).toBeLessThanOrEqual(0.04);
      expect(1 - p).toBeGreaterThanOrEqual(0.005);
    }
  });

  it("profil moyen équilibré (tous attributs ~500) ⇒ ~top 20-30%", () => {
    for (const sex of SEXES) {
      const radar = ATTRS.map((a) => attr(a, 500));
      const p = popPercentileIndex(sex, "all_round", radar);
      expect(1 - p).toBeGreaterThanOrEqual(0.18);
      expect(1 - p).toBeLessThanOrEqual(0.33);
    }
  });

  it("un seul attribut élite débloque la valorisation top-lourde", () => {
    // Un attribut à 0.99+ doit suffire à dépasser largement la moyenne classique du radar.
    const radar = [attr("engine", 950), ...ATTRS.slice(1).map((a) => attr(a, 250))];
    const weightedMean =
      radar.reduce((s, a) => s + popPercentileAttr("male", a.attribute, a.score), 0) / radar.length;
    expect(popPercentileIndex("male", "all_round", radar)).toBeGreaterThan(weightedMean);
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
