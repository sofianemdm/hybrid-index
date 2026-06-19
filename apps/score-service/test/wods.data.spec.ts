import { WODS, WODS_BY_ID } from "../src/wods/wods.data";
import { percentile } from "@hybrid-index/scoring-core";

describe("Registre des WODs (intégrité)", () => {
  it("contient exactement 15 WODs (8 avec matériel + 7 sans)", () => {
    expect(WODS).toHaveLength(15);
    expect(WODS.filter((w) => w.requiresEquipment)).toHaveLength(8);
    expect(WODS.filter((w) => !w.requiresEquipment)).toHaveLength(7);
  });

  it("a des identifiants uniques et un index cohérent", () => {
    const ids = new Set(WODS.map((w) => w.id));
    expect(ids.size).toBe(15);
    expect(WODS_BY_ID.size).toBe(15);
  });

  it("chaque WOD a une référence pour les deux sexes avec bornes valides", () => {
    for (const wod of WODS) {
      for (const sex of ["male", "female"] as const) {
        const ref = wod.byaSex[sex];
        expect(ref.hardMin).toBeLessThan(ref.hardMax);
        expect(ref.proReference).toBeGreaterThanOrEqual(ref.hardMin);
        expect(ref.proReference).toBeLessThanOrEqual(ref.hardMax);
        expect(wod.targetAttributes.length).toBeGreaterThan(0);
      }
    }
  });

  it("seul max_pushups porte un attribut estimé (proxy Force)", () => {
    for (const wod of WODS) {
      const hasEstimated = wod.targetAttributes.some((t) => t.estimated);
      expect(hasEstimated).toBe(wod.id === "max_pushups");
    }
  });

  it("le pro reference donne un percentile très élevé (cible élite)", () => {
    for (const wod of WODS) {
      for (const sex of ["male", "female"] as const) {
        const ref = wod.byaSex[sex];
        const p = percentile(ref.proReference, ref.model);
        expect(p).toBeGreaterThan(0.8); // l'élite bat >80 % de la population
      }
    }
  });
});
