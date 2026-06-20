import { WODS, WODS_BY_ID } from "../src/wods/wods.data";
import { percentile } from "@hybrid-index/scoring-core";

describe("Registre des WODs (intégrité)", () => {
  it("contient 17 WODs (8 avec matériel + 9 sans, dont course libre & air squats)", () => {
    expect(WODS).toHaveLength(17);
    expect(WODS.filter((w) => w.requiresEquipment)).toHaveLength(8);
    expect(WODS.filter((w) => !w.requiresEquipment)).toHaveLength(9);
  });

  it("a des identifiants uniques et un index cohérent", () => {
    const ids = new Set(WODS.map((w) => w.id));
    expect(ids.size).toBe(17);
    expect(WODS_BY_ID.size).toBe(17);
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
