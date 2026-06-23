import { WODS, WODS_BY_ID } from "../src/wods/wods.data";
import { percentile } from "@hybrid-index/scoring-core";

describe("Registre des WODs (intégrité)", () => {
  it("contient 25 WODs : 19 de référence + 6 épreuves « Autre » (12 avec matériel + 13 sans)", () => {
    expect(WODS).toHaveLength(25);
    // 19 séances de référence (9 avec / 10 sans, dont le 3 km et Profil Express) + 6 « Autre ».
    expect(WODS.filter((w) => w.requiresEquipment)).toHaveLength(12);
    expect(WODS.filter((w) => !w.requiresEquipment)).toHaveLength(13);
  });

  it("a des identifiants uniques et un index cohérent", () => {
    const ids = new Set(WODS.map((w) => w.id));
    expect(ids.size).toBe(25);
    expect(WODS_BY_ID.size).toBe(25);
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

  it("attributs estimés : seulement les proxies bodyweight (D2) + la séance d'estimation globale", () => {
    // max_pushups/max_air_squats : Force estimée par proxy. profil_express : séance d'entrée qui
    // DONNE un Index estimé sur les 6 qualités (sera affiné par les vraies séances).
    const estimatedWods = new Set(["max_pushups", "max_air_squats", "profil_express"]);
    for (const wod of WODS) {
      const hasEstimated = wod.targetAttributes.some((t) => t.estimated);
      expect(hasEstimated).toBe(estimatedWods.has(wod.id));
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
