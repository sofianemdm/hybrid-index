import { WODS, WODS_BY_ID } from "../src/wods/wods.data";
import { WOD_LEVELS } from "../src/wods/wod-levels.data";
import { percentile } from "@hybrid-index/scoring-core";

const LEAGUE_WOD_IDS = [
  "league_sprint_ladder",
  "league_engine_12",
  "league_grind_squats",
  "league_power_amrap",
  "league_hybrid_chipper",
];

describe("Registre des WODs (intégrité)", () => {
  it("contient 32 WODs : 21 de référence + 6 « Autre » + 5 Ligue (14 avec matériel + 18 sans)", () => {
    expect(WODS).toHaveLength(32);
    // 21 séances de référence (11 avec / 10 sans) + 6 « Autre » + 5 WODs « Ligue du mois » (sans matériel).
    expect(WODS.filter((w) => w.requiresEquipment)).toHaveLength(14);
    expect(WODS.filter((w) => !w.requiresEquipment)).toHaveLength(18);
  });

  it("a des identifiants uniques et un index cohérent", () => {
    const ids = new Set(WODS.map((w) => w.id));
    expect(ids.size).toBe(32);
    expect(WODS_BY_ID.size).toBe(32);
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
    // league_grind_squats : strength en ESTIMÉ (proxy force-endurance bodyweight, comme max_air_squats).
    const estimatedWods = new Set(["max_pushups", "max_air_squats", "profil_express", "squat_1rm", "league_grind_squats"]);
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

describe("WODs « Ligue du mois » (5 séances dédiées)", () => {
  it("les 5 WODs Ligue existent, sont sans matériel et hors Index (isBenchmark:false)", () => {
    for (const id of LEAGUE_WOD_IDS) {
      const wod = WODS_BY_ID.get(id);
      expect(wod).toBeDefined();
      expect(wod!.requiresEquipment).toBe(false);
      expect(wod!.isBenchmark).toBe(false);
    }
  });

  it("scoring monotone par sexe : champion > intermédiaire > occasionnel (percentile dans [0,1])", () => {
    for (const id of LEAGUE_WOD_IDS) {
      const wod = WODS_BY_ID.get(id)!;
      const levels = WOD_LEVELS[id];
      expect(levels).toBeDefined(); // paliers d'affichage présents
      for (const sex of ["male", "female"] as const) {
        const model = wod.bySex[sex].model;
        const pc = percentile(levels[sex].champion, model);
        const pi = percentile(levels[sex].intermediate, model);
        const po = percentile(levels[sex].occasional, model);
        for (const p of [pc, pi, po]) {
          expect(p).toBeGreaterThanOrEqual(0);
          expect(p).toBeLessThanOrEqual(1);
        }
        // Quel que soit le sens (time dir-1 / reps dir+1), le niveau « champion » score le plus haut.
        expect(pc).toBeGreaterThan(pi);
        expect(pi).toBeGreaterThan(po);
      }
    }
  });

  it("couvre 5 qualités primaires distinctes (donner sa chance à tous les profils)", () => {
    const primaries = LEAGUE_WOD_IDS.map((id) => WODS_BY_ID.get(id)!.targetAttributes[0].attribute);
    expect(new Set(primaries)).toEqual(new Set(["speed", "engine", "muscular_endurance", "power", "hybrid"]));
  });
});
