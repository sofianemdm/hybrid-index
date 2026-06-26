import { WOD_PRESCRIPTIONS } from "../src/modules/wods/wod-prescriptions.data";
import { isScalable } from "../src/modules/wods/wod-prescription.types";

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

  it("Rx/Allégé (scalable) : seuls les WODs à charge adaptable, jamais les courses/poids de corps", () => {
    // Règle data-driven : scalable ssi le WOD porte au moins une charge adaptable.
    // Les WODs au POIDS DE CORPS NON adaptable (max pompes, max air squats, burpees, Cindy,
    // Benchmark Zéro, Profil Express) et les COURSES n'ont rien à scaler → pas de toggle Rx/Allégé.
    const SCALABLE = new Set(["hyrox_sprint", "fran", "grace", "jackie", "helen", "karen", "isabel", "murph"]);
    const NON_SCALABLE = [
      "max_pushups", "max_air_squats_2min", "max_air_squats", "burpees_7min", "cindy",
      "benchmark_zero", "profil_express", "run_5k", "run_3k", "run_1k", "run_free_distance",
    ];
    for (const id of SCALABLE) {
      expect(isScalable(WOD_PRESCRIPTIONS[id])).toBe(true);
      expect(WOD_PRESCRIPTIONS[id].weights.length).toBeGreaterThan(0);
    }
    for (const id of NON_SCALABLE) {
      expect(isScalable(WOD_PRESCRIPTIONS[id])).toBe(false);
      expect(WOD_PRESCRIPTIONS[id].weights).toHaveLength(0);
    }
    // Invariant global : scalable ⇔ présence d'au moins une charge (aucune exception).
    for (const p of Object.values(WOD_PRESCRIPTIONS)) {
      expect(isScalable(p)).toBe(p.weights.length > 0);
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
