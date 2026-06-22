import { WODS, WODS_BY_ID } from "../src/wods/wods.data";
import { percentile } from "@hybrid-index/scoring-core";

describe("Registre des WODs (intégrité)", () => {
  it("contient 23 WODs : 17 de référence + 6 épreuves « Autre » (12 avec matériel + 11 sans)", () => {
    expect(WODS).toHaveLength(23);
    // 17 séances de référence (9 avec / 8 sans) + 6 épreuves « Autre » jouables :
    // hyrox_solo, isabel, murph (avec matériel) ; track_10000m, half_marathon, marathon (sans).
    expect(WODS.filter((w) => w.requiresEquipment)).toHaveLength(12);
    expect(WODS.filter((w) => !w.requiresEquipment)).toHaveLength(11);
  });

  it("a des identifiants uniques et un index cohérent", () => {
    const ids = new Set(WODS.map((w) => w.id));
    expect(ids.size).toBe(23);
    expect(WODS_BY_ID.size).toBe(23);
  });

  it("chaque WOD a une référence pour les deux sexes avec bornes valides", () => {
    for (const wod of WODS) {
      for (const sex of ["male", "female"] as const) {
        const ref = wod.bySex[sex];
        expect(ref.hardMin).toBeLessThan(ref.hardMax);
        expect(ref.proReference).toBeGreaterThanOrEqual(ref.hardMin);
        expect(ref.proReference).toBeLessThanOrEqual(ref.hardMax);
        expect(wod.targetAttributes.length).toBeGreaterThan(0);
      }
    }
  });

  it("seuls les proxies bodyweight portent un attribut Force estimé (D2)", () => {
    const proxiesForceEstimee = new Set(["max_pushups", "max_air_squats"]);
    for (const wod of WODS) {
      const hasEstimated = wod.targetAttributes.some((t) => t.estimated);
      expect(hasEstimated).toBe(proxiesForceEstimee.has(wod.id));
    }
  });

  it("le pro reference donne un percentile très élevé (cible élite)", () => {
    for (const wod of WODS) {
      for (const sex of ["male", "female"] as const) {
        const ref = wod.bySex[sex];
        const p = percentile(ref.proReference, ref.model);
        expect(p).toBeGreaterThan(0.8); // l'élite bat >80 % de la population
      }
    }
  });
});
