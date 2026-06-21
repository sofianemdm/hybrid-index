import { WOD_PRESCRIPTIONS } from "../src/modules/wods/wod-prescriptions.data";

/** Les séances de référence seedées doivent TOUTES avoir un énoncé concret (mouvements + score). */
const REFERENCE_WOD_IDS = [
  "hyrox_sprint",
  "fran",
  "grace",
  "jackie",
  "row_2k",
  "helen",
  "karen",
  "cindy",
  "benchmark_zero",
  "run_5k",
  "run_1k",
  "max_pushups",
  "max_air_squats_2min",
  "burpees_7min",
  "ergo_skill",
  "run_free_distance",
  "max_air_squats",
];

/** Séances dont au moins un mouvement est chargé → doivent porter des poids RX + allégés par sexe. */
const LOADED_WOD_IDS = ["fran", "grace", "jackie", "helen", "karen"];

describe("WOD_PRESCRIPTIONS — énoncés concrets des séances", () => {
  it("couvre les 17 séances de référence", () => {
    for (const id of REFERENCE_WOD_IDS) {
      expect(WOD_PRESCRIPTIONS[id]).toBeDefined();
    }
  });

  it("chaque prescription a un format, des mouvements et une note de scoring", () => {
    for (const id of REFERENCE_WOD_IDS) {
      const p = WOD_PRESCRIPTIONS[id];
      expect(p.format.length).toBeGreaterThan(0);
      expect(p.blocks.length).toBeGreaterThan(0);
      p.blocks.forEach((b) => {
        expect(b.reps.length).toBeGreaterThan(0);
        expect(b.movement.length).toBeGreaterThan(0);
      });
      expect(p.scoringNote.length).toBeGreaterThan(0);
    }
  });

  it("les séances chargées ont des poids RX + allégés cohérents par sexe", () => {
    for (const id of LOADED_WOD_IDS) {
      const p = WOD_PRESCRIPTIONS[id];
      expect(p.weights.length).toBeGreaterThan(0);
      p.weights.forEach((w) => {
        expect(w.unit).toBe("kg");
        expect(w.rxMale).toBeGreaterThan(0);
        expect(w.rxFemale).toBeGreaterThan(0);
        // Version allégée ≤ RX (jamais plus lourde), et hommes ≥ femmes (convention de référence).
        expect(w.scaledMale).toBeLessThanOrEqual(w.rxMale);
        expect(w.scaledFemale).toBeLessThanOrEqual(w.rxFemale);
        expect(w.rxMale).toBeGreaterThanOrEqual(w.rxFemale);
      });
    }
  });
});
