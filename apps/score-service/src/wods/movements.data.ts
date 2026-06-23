import type { AttributeKey } from "@hybrid-index/contracts";

/**
 * Bibliothèque de mouvements (sport-science, 20 juin) — socle du moteur d'estimation.
 * `rate` = débit SOUTENABLE en (unité/seconde) par niveau et sexe. `loadFactor` = charge Rx de
 * référence en fraction du poids de corps (réf H 80 kg / F 65 kg). `fatigueExponent` = dégradation
 * de la cadence avec le volume. Valeurs à recalibrer sur la communauté (confiance moyenne).
 */
export type MoveUnit = "rep" | "meter" | "calorie" | "second";
export interface LevelSex {
  male: number;
  female: number;
}
export interface MovementDef {
  id: string;
  name: string;
  category: "gymnastics" | "weightlifting" | "monostructural";
  unit: MoveUnit;
  requiresEquipment: boolean;
  loadFactor?: number;
  rate: { champion: LevelSex; intermediate: LevelSex; occasional: LevelSex };
  attributes: Array<{ attribute: AttributeKey; weight: number }>;
  fatigueExponent: number;
  /** Reps tenables d'affilée avant une coupure (modèle de temps). Défaut 12. */
  maxSet?: number;
}

const r = (cm: number, cf: number, im: number, if_: number, om: number, of: number) => ({
  champion: { male: cm, female: cf },
  intermediate: { male: im, female: if_ },
  occasional: { male: om, female: of },
});

export const MOVEMENTS: MovementDef[] = [
  // ---- Gymnastique poids de corps ----
  { id: "push_up", name: "Push-up", category: "gymnastics", unit: "rep", requiresEquipment: false, loadFactor: 0.64, rate: r(0.83, 0.7, 0.42, 0.34, 0.24, 0.18), attributes: [{ attribute: "muscular_endurance", weight: 0.6 }, { attribute: "strength", weight: 0.4 }], fatigueExponent: 1.18, maxSet: 15 },
  { id: "pull_up", name: "Pull-up", category: "gymnastics", unit: "rep", requiresEquipment: true, loadFactor: 1.0, rate: r(0.8, 0.65, 0.38, 0.28, 0.18, 0.1), attributes: [{ attribute: "muscular_endurance", weight: 0.5 }, { attribute: "strength", weight: 0.5 }], fatigueExponent: 1.3 },
  { id: "chest_to_bar", name: "Chest-to-bar pull-up", category: "gymnastics", unit: "rep", requiresEquipment: true, loadFactor: 1.0, rate: r(0.7, 0.55, 0.3, 0.22, 0.12, 0.07), attributes: [{ attribute: "strength", weight: 0.5 }, { attribute: "muscular_endurance", weight: 0.4 }, { attribute: "power", weight: 0.1 }], fatigueExponent: 1.35 },
  { id: "ring_muscle_up", name: "Ring muscle-up", category: "gymnastics", unit: "rep", requiresEquipment: true, loadFactor: 1.0, rate: r(0.45, 0.33, 0.15, 0.08, 0.05, 0.02), attributes: [{ attribute: "strength", weight: 0.55 }, { attribute: "power", weight: 0.25 }, { attribute: "muscular_endurance", weight: 0.2 }], fatigueExponent: 1.55 },
  { id: "handstand_push_up", name: "Handstand push-up", category: "gymnastics", unit: "rep", requiresEquipment: false, loadFactor: 0.88, rate: r(0.55, 0.42, 0.22, 0.14, 0.08, 0.04), attributes: [{ attribute: "strength", weight: 0.55 }, { attribute: "muscular_endurance", weight: 0.35 }, { attribute: "power", weight: 0.1 }], fatigueExponent: 1.45 },
  { id: "toes_to_bar", name: "Toes-to-bar", category: "gymnastics", unit: "rep", requiresEquipment: true, loadFactor: 0.5, rate: r(0.72, 0.58, 0.33, 0.25, 0.14, 0.08), attributes: [{ attribute: "muscular_endurance", weight: 0.6 }, { attribute: "strength", weight: 0.25 }, { attribute: "power", weight: 0.15 }], fatigueExponent: 1.32 },
  { id: "sit_up", name: "Sit-up", category: "gymnastics", unit: "rep", requiresEquipment: false, rate: r(0.85, 0.8, 0.55, 0.5, 0.35, 0.3), attributes: [{ attribute: "muscular_endurance", weight: 1.0 }], fatigueExponent: 1.1 },
  { id: "air_squat", name: "Air squat", category: "gymnastics", unit: "rep", requiresEquipment: false, loadFactor: 0.85, rate: r(1.05, 1.0, 0.7, 0.66, 0.48, 0.44), attributes: [{ attribute: "muscular_endurance", weight: 0.7 }, { attribute: "power", weight: 0.3 }], fatigueExponent: 1.12 },
  { id: "lunge", name: "Fente marchée (reps)", category: "gymnastics", unit: "rep", requiresEquipment: false, loadFactor: 0.85, rate: r(0.7, 0.65, 0.45, 0.4, 0.3, 0.26), attributes: [{ attribute: "muscular_endurance", weight: 0.7 }, { attribute: "strength", weight: 0.2 }, { attribute: "power", weight: 0.1 }], fatigueExponent: 1.15 },
  { id: "lunge_m", name: "Fente marchée (distance)", category: "gymnastics", unit: "meter", requiresEquipment: false, loadFactor: 0.85, rate: r(0.7, 0.65, 0.45, 0.4, 0.3, 0.26), attributes: [{ attribute: "muscular_endurance", weight: 0.7 }, { attribute: "strength", weight: 0.2 }, { attribute: "power", weight: 0.1 }], fatigueExponent: 1.15, maxSet: 1000 },
  { id: "burpee", name: "Burpee", category: "gymnastics", unit: "rep", requiresEquipment: false, loadFactor: 0.7, rate: r(0.58, 0.5, 0.33, 0.28, 0.2, 0.16), attributes: [{ attribute: "engine", weight: 0.4 }, { attribute: "muscular_endurance", weight: 0.3 }, { attribute: "power", weight: 0.2 }, { attribute: "hybrid", weight: 0.1 }], fatigueExponent: 1.25 },
  { id: "burpee_broad_jump", name: "Burpee broad jump (reps)", category: "gymnastics", unit: "rep", requiresEquipment: false, loadFactor: 0.72, rate: r(0.40, 0.34, 0.22, 0.18, 0.13, 0.10), attributes: [{ attribute: "engine", weight: 0.35 }, { attribute: "power", weight: 0.3 }, { attribute: "muscular_endurance", weight: 0.25 }, { attribute: "hybrid", weight: 0.1 }], fatigueExponent: 1.3, maxSet: 10 },
  { id: "burpee_broad_jump_m", name: "Burpee broad jump (distance)", category: "gymnastics", unit: "meter", requiresEquipment: false, loadFactor: 0.72, rate: r(0.72, 0.61, 0.40, 0.32, 0.23, 0.18), attributes: [{ attribute: "engine", weight: 0.35 }, { attribute: "power", weight: 0.3 }, { attribute: "muscular_endurance", weight: 0.25 }, { attribute: "hybrid", weight: 0.1 }], fatigueExponent: 1.22, maxSet: 1000 },
  { id: "box_jump", name: "Box jump", category: "gymnastics", unit: "rep", requiresEquipment: true, loadFactor: 1.0, rate: r(0.7, 0.62, 0.45, 0.38, 0.28, 0.22), attributes: [{ attribute: "power", weight: 0.55 }, { attribute: "muscular_endurance", weight: 0.3 }, { attribute: "engine", weight: 0.15 }], fatigueExponent: 1.2 },
  { id: "double_under", name: "Double-under", category: "gymnastics", unit: "rep", requiresEquipment: true, rate: r(3.0, 2.8, 1.6, 1.4, 0.7, 0.5), attributes: [{ attribute: "engine", weight: 0.5 }, { attribute: "speed", weight: 0.3 }, { attribute: "muscular_endurance", weight: 0.2 }], fatigueExponent: 1.08 },
  { id: "wall_walk", name: "Wall walk", category: "gymnastics", unit: "rep", requiresEquipment: false, loadFactor: 0.9, rate: r(0.16, 0.13, 0.075, 0.055, 0.038, 0.026), attributes: [{ attribute: "strength", weight: 0.5 }, { attribute: "muscular_endurance", weight: 0.4 }, { attribute: "engine", weight: 0.1 }], fatigueExponent: 1.4, maxSet: 4 },
  { id: "pistol_squat", name: "Pistol squat", category: "gymnastics", unit: "rep", requiresEquipment: false, loadFactor: 0.95, rate: r(0.6, 0.55, 0.3, 0.26, 0.12, 0.09), attributes: [{ attribute: "strength", weight: 0.45 }, { attribute: "muscular_endurance", weight: 0.4 }, { attribute: "power", weight: 0.15 }], fatigueExponent: 1.22 },
  // ---- Haltérophilie / charge (loadFactor = fraction du poids de corps de réf) ----
  { id: "thruster", name: "Thruster", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.54, rate: r(0.8, 0.66, 0.42, 0.34, 0.22, 0.16), attributes: [{ attribute: "power", weight: 0.5 }, { attribute: "muscular_endurance", weight: 0.3 }, { attribute: "strength", weight: 0.2 }], fatigueExponent: 1.4 },
  { id: "wall_ball", name: "Wall ball", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.11, rate: r(0.85, 0.75, 0.5, 0.42, 0.3, 0.24), attributes: [{ attribute: "power", weight: 0.45 }, { attribute: "muscular_endurance", weight: 0.4 }, { attribute: "engine", weight: 0.15 }], fatigueExponent: 1.3 },
  { id: "deadlift", name: "Deadlift", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 1.25, rate: r(0.65, 0.55, 0.38, 0.3, 0.22, 0.16), attributes: [{ attribute: "strength", weight: 0.55 }, { attribute: "power", weight: 0.25 }, { attribute: "muscular_endurance", weight: 0.2 }], fatigueExponent: 1.42 },
  { id: "clean", name: "Power clean", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.76, rate: r(0.32, 0.26, 0.15, 0.12, 0.075, 0.055), attributes: [{ attribute: "power", weight: 0.55 }, { attribute: "strength", weight: 0.35 }, { attribute: "muscular_endurance", weight: 0.1 }], fatigueExponent: 1.55, maxSet: 4 },
  { id: "clean_and_jerk", name: "Clean & jerk", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.76, rate: r(0.5, 0.42, 0.25, 0.19, 0.12, 0.08), attributes: [{ attribute: "power", weight: 0.55 }, { attribute: "strength", weight: 0.35 }, { attribute: "muscular_endurance", weight: 0.1 }], fatigueExponent: 1.48, maxSet: 5 },
  { id: "snatch", name: "Power snatch", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.54, rate: r(0.52, 0.44, 0.24, 0.18, 0.11, 0.07), attributes: [{ attribute: "power", weight: 0.6 }, { attribute: "strength", weight: 0.3 }, { attribute: "speed", weight: 0.1 }], fatigueExponent: 1.5, maxSet: 5 },
  { id: "overhead_squat", name: "Overhead squat", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.54, rate: r(0.55, 0.46, 0.28, 0.22, 0.13, 0.09), attributes: [{ attribute: "strength", weight: 0.45 }, { attribute: "power", weight: 0.35 }, { attribute: "muscular_endurance", weight: 0.2 }], fatigueExponent: 1.42 },
  { id: "front_squat", name: "Front squat", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.75, rate: r(0.5, 0.42, 0.26, 0.2, 0.13, 0.09), attributes: [{ attribute: "strength", weight: 0.55 }, { attribute: "power", weight: 0.25 }, { attribute: "muscular_endurance", weight: 0.2 }], fatigueExponent: 1.4 },
  { id: "shoulder_to_overhead", name: "Shoulder-to-overhead", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.54, rate: r(0.62, 0.52, 0.32, 0.25, 0.16, 0.11), attributes: [{ attribute: "power", weight: 0.5 }, { attribute: "strength", weight: 0.35 }, { attribute: "muscular_endurance", weight: 0.15 }], fatigueExponent: 1.43 },
  { id: "kettlebell_swing", name: "Kettlebell swing", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.3, rate: r(0.9, 0.8, 0.55, 0.46, 0.34, 0.27), attributes: [{ attribute: "power", weight: 0.45 }, { attribute: "muscular_endurance", weight: 0.35 }, { attribute: "engine", weight: 0.2 }], fatigueExponent: 1.28 },
  { id: "dumbbell_snatch", name: "DB snatch", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.28, rate: r(0.62, 0.52, 0.34, 0.27, 0.18, 0.12), attributes: [{ attribute: "power", weight: 0.5 }, { attribute: "muscular_endurance", weight: 0.3 }, { attribute: "strength", weight: 0.2 }], fatigueExponent: 1.35 },
  { id: "thruster_db", name: "DB thruster", category: "weightlifting", unit: "rep", requiresEquipment: true, loadFactor: 0.56, rate: r(0.58, 0.48, 0.3, 0.24, 0.16, 0.11), attributes: [{ attribute: "power", weight: 0.5 }, { attribute: "muscular_endurance", weight: 0.3 }, { attribute: "strength", weight: 0.2 }], fatigueExponent: 1.42 },
  // ---- Monostructural (cardio) ----
  { id: "run", name: "Run", category: "monostructural", unit: "meter", requiresEquipment: false, rate: r(6.4, 5.6, 3.8, 3.4, 2.8, 2.5), attributes: [{ attribute: "engine", weight: 0.85 }, { attribute: "speed", weight: 0.15 }], fatigueExponent: 1.06 },
  { id: "sprint", name: "Sprint (≤200m)", category: "monostructural", unit: "meter", requiresEquipment: false, rate: r(9.5, 8.4, 6.5, 5.8, 5.0, 4.4), attributes: [{ attribute: "speed", weight: 0.7 }, { attribute: "power", weight: 0.2 }, { attribute: "engine", weight: 0.1 }], fatigueExponent: 1.1 },
  { id: "row", name: "Row (mètres)", category: "monostructural", unit: "meter", requiresEquipment: true, rate: r(5.95, 5.25, 4.0, 3.6, 3.1, 2.8), attributes: [{ attribute: "engine", weight: 0.85 }, { attribute: "power", weight: 0.15 }], fatigueExponent: 1.05 },
  { id: "row_cal", name: "Row (calories)", category: "monostructural", unit: "calorie", requiresEquipment: true, rate: r(0.42, 0.32, 0.27, 0.21, 0.18, 0.14), attributes: [{ attribute: "engine", weight: 0.8 }, { attribute: "power", weight: 0.2 }], fatigueExponent: 1.07 },
  { id: "bike_erg_cal", name: "BikeErg (calories)", category: "monostructural", unit: "calorie", requiresEquipment: true, rate: r(0.5, 0.38, 0.32, 0.25, 0.21, 0.16), attributes: [{ attribute: "engine", weight: 0.85 }, { attribute: "power", weight: 0.15 }], fatigueExponent: 1.06 },
  { id: "assault_bike_cal", name: "Assault bike (calories)", category: "monostructural", unit: "calorie", requiresEquipment: true, rate: r(0.38, 0.28, 0.24, 0.18, 0.15, 0.11), attributes: [{ attribute: "engine", weight: 0.8 }, { attribute: "power", weight: 0.2 }], fatigueExponent: 1.12 },
  { id: "ski_erg_cal", name: "SkiErg (calories)", category: "monostructural", unit: "calorie", requiresEquipment: true, rate: r(0.4, 0.3, 0.26, 0.2, 0.17, 0.13), attributes: [{ attribute: "engine", weight: 0.8 }, { attribute: "power", weight: 0.2 }], fatigueExponent: 1.07 },
  { id: "sled_push", name: "Sled push", category: "monostructural", unit: "meter", requiresEquipment: true, loadFactor: 1.9, rate: r(1.6, 1.3, 0.9, 0.7, 0.55, 0.42), attributes: [{ attribute: "strength", weight: 0.4 }, { attribute: "power", weight: 0.35 }, { attribute: "engine", weight: 0.25 }], fatigueExponent: 1.3 },
  { id: "farmers_carry", name: "Farmers carry", category: "monostructural", unit: "meter", requiresEquipment: true, loadFactor: 0.6, rate: r(2.2, 1.9, 1.5, 1.3, 1.0, 0.85), attributes: [{ attribute: "strength", weight: 0.5 }, { attribute: "muscular_endurance", weight: 0.3 }, { attribute: "engine", weight: 0.2 }], fatigueExponent: 1.18 },
];

export const MOVEMENTS_BY_ID: ReadonlyMap<string, MovementDef> = new Map(MOVEMENTS.map((m) => [m.id, m]));
