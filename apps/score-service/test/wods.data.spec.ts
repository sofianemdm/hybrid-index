import { WODS, WODS_BY_ID } from "../src/wods/wods.data";
import { percentile } from "@hybrid-index/scoring-core";

describe("Registre des WODs (intégrité)", () => {
  it("contient 27 WODs : 21 de référence + 6 épreuves « Autre » (14 avec matériel + 13 sans)", () => {
    expect(WODS).toHaveLength(27);
    // 21 séances de référence (11 avec / 10 sans) + 6 « Autre ». Ajout 24 juin : max_strict_pullups
    // + squat_1rm (onboarding tractions strictes / squat 1RM), toutes deux avec matériel.
    expect(WODS.filter((w) => w.requiresEquipment)).toHaveLength(14);
    expect(WODS.filter((w) => !w.requiresEquipment)).toHaveLength(13);
  });

  it("a des identifiants uniques et un index cohérent", () => {
    const ids = new Set(WODS.map((w) => w.id));
    expect(ids.size).toBe(27);
    expect(WODS_BY_ID.size).toBe(27);
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
    // squat_1rm : power en ESTIMÉ (un 1RM conditionne la puissance mais ne mesure pas la vitesse).
    const estimatedWods = new Set(["max_pushups", "max_air_squats", "profil_express", "squat_1rm"]);
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
