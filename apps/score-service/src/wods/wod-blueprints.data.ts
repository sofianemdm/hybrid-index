import { MOVEMENTS_BY_ID } from "./movements.data";

/**
 * BLUEPRINTS canoniques des WODs de référence (sport-science) — décomposition STRUCTURÉE que le
 * moteur de temps (`wod-time-engine.ts`) peut consommer : `movementId` + reps numériques + charge
 * Rx par sexe + tours.
 *
 * POURQUOI : `WodDefinition` ne porte que des distributions statistiques (`bySex.model`) et des
 * `targetAttributes` (grossiers). La prescription LISIBLE existe côté API (`wod-prescriptions.data.ts`)
 * mais en TEXTE (`reps:"21-15-9"`, `movement:"Thrusters"`) destiné à l'affichage. On transcrit ce
 * texte UNE FOIS, à la main, en blocs typés testés — on NE parse JAMAIS de texte au runtime.
 *
 * SÉPARATION ESTIMATION ≠ NOTATION : ces blueprints servent UNIQUEMENT l'ESTIMATION de temps. Ils
 * ne déplacent aucun sous-score, aucun Index, aucun classement. La notation d'un résultat réel
 * continue de passer par `bySex.model` (distribution.ts), inchangée.
 *
 * Convention `repsPerRound` : un nombre par tour. Couplet/triplet « 21-15-9 » ⇒ [21,15,9] (3 tours).
 * Format « N tours de X » ⇒ [X, X, …] (N fois la même valeur). Mono-effort (course, max reps) ⇒ un
 * seul élément. `loadKg` absent ⇒ poids de corps (le moteur applique `loadFactor`).
 *
 * Mapping nom (prescription) → movementId (movements.data.ts) :
 *   Thrusters→thruster, Tractions/Pull-up→pull_up, Épaulés-jetés→clean_and_jerk, Rameur(m)→row,
 *   Rameur(cal)→row_cal, Course→run, Swings kettlebell→kettlebell_swing, Wall balls→wall_ball,
 *   Pompes→push_up, Air squats→air_squat, Burpees→burpee, Wall walks→wall_walk,
 *   Toes-to-bar→toes_to_bar, Snatch→snatch.
 */
export interface WodBlueprintBlock {
  movementId: string;
  /** Reps (ou mètres/calories selon l'unité du mouvement) par tour. */
  repsPerRound: number[];
  /** Charge Rx ABSOLUE par sexe (kg). Absente ⇒ poids de corps (loadFactor du mouvement). */
  loadKg?: { male: number; female: number };
  /**
   * Bloc compté au TEMPS du tour mais PAS dans le VOLUME scoré (AMRAP « course imposée + reps »
   * où seules les reps comptent — ex. Le Moteur : 400 m course non scorée). Sans effet sur un WOD
   * « for time » (le score y EST le temps). Défaut : compté.
   */
  unscored?: boolean;
}
export interface WodBlueprint {
  /** Blocs dans l'ordre d'exécution. `rounds` implicite = longueur de `repsPerRound`. */
  blocks: WodBlueprintBlock[];
  /**
   * Pour AMRAP / max-reps : le score est un VOLUME tenable dans le cap, pas un temps. `scoreUnit`
   * fixe l'unité du score saisi par l'utilisateur (et donc l'unité de l'estimation) :
   *  - `"rounds"` : nombre de tours complets (ex. Cindy : médiane 12, max 36 tours) ;
   *  - `"reps"` : nombre total de répétitions (défaut historique).
   */
  amrap?: { timeCapSec: number; scoreUnit?: "rounds" | "reps" };
}

/**
 * Blueprints des benchmarks décomposables. Les WODs « course pure » / « max reps en 1 série » sans
 * structure exploitable (run_5k, run_3k, run_1k, max_pushups, max_air_squats…, run_free_distance,
 * squat_1rm) n'ont PAS de blueprint → repli sur la prédiction population (cf. predictResult).
 */
export const WOD_BLUEPRINTS: Record<string, WodBlueprint> = {
  // Fran — 21-15-9 Thrusters (40/30) + Tractions.
  fran: {
    blocks: [
      { movementId: "thruster", repsPerRound: [21, 15, 9], loadKg: { male: 40, female: 30 } },
      { movementId: "pull_up", repsPerRound: [21, 15, 9] },
    ],
  },

  // Grace — 30 Épaulés-jetés (60/40), un seul « tour » de 30.
  grace: {
    blocks: [{ movementId: "clean_and_jerk", repsPerRound: [30], loadKg: { male: 60, female: 40 } }],
  },

  // Jackie — 1000 m Rameur, 50 Thrusters barre à vide (20/15), 30 Tractions.
  jackie: {
    blocks: [
      { movementId: "row", repsPerRound: [1000] },
      { movementId: "thruster", repsPerRound: [50], loadKg: { male: 20, female: 15 } },
      { movementId: "pull_up", repsPerRound: [30] },
    ],
  },

  // Helen — 3 tours : 400 m Course, 21 Swings KB (24/16), 12 Tractions.
  helen: {
    blocks: [
      { movementId: "run", repsPerRound: [400, 400, 400] },
      { movementId: "kettlebell_swing", repsPerRound: [21, 21, 21], loadKg: { male: 24, female: 16 } },
      { movementId: "pull_up", repsPerRound: [12, 12, 12] },
    ],
  },

  // Karen — 150 Wall balls (9/6), un seul « tour » de 150.
  karen: {
    blocks: [{ movementId: "wall_ball", repsPerRound: [150], loadKg: { male: 9, female: 6 } }],
  },

  // Cindy — AMRAP 20 min : 5 Tractions, 10 Pompes, 15 Air squats. Score = VOLUME (reps).
  cindy: {
    blocks: [
      { movementId: "pull_up", repsPerRound: [5] },
      { movementId: "push_up", repsPerRound: [10] },
      { movementId: "air_squat", repsPerRound: [15] },
    ],
    amrap: { timeCapSec: 1200, scoreUnit: "rounds" },
  },

  // Sprint HYROX — 3 tours : 500 m Course + 500 m Rameur + 20 Wall balls (9/6).
  hyrox_sprint: {
    blocks: [
      { movementId: "run", repsPerRound: [500, 500, 500] },
      { movementId: "row", repsPerRound: [500, 500, 500] },
      { movementId: "wall_ball", repsPerRound: [20, 20, 20], loadKg: { male: 9, female: 6 } },
    ],
  },

  // 2000 m Rameur — pur ergo.
  row_2k: {
    blocks: [{ movementId: "row", repsPerRound: [2000] }],
  },

  // Machine & Mur — 3 tours : 20 cal Rameur + 5 Wall walks + 10 Toes-to-bar.
  ergo_skill: {
    blocks: [
      { movementId: "row_cal", repsPerRound: [20, 20, 20] },
      { movementId: "wall_walk", repsPerRound: [5, 5, 5] },
      { movementId: "toes_to_bar", repsPerRound: [10, 10, 10] },
    ],
  },

  // Profil Express — 200 m Course, 15 Burpees, 20 Pompes, 30 Air squats, 5 Wall walks, 200 m Course.
  profil_express: {
    blocks: [
      { movementId: "run", repsPerRound: [200] },
      { movementId: "burpee", repsPerRound: [15] },
      { movementId: "push_up", repsPerRound: [20] },
      { movementId: "air_squat", repsPerRound: [30] },
      { movementId: "wall_walk", repsPerRound: [5] },
      { movementId: "run", repsPerRound: [200] },
    ],
  },

  // Benchmark Zéro — 21-15-9 Burpees + Pompes + (42-30-18 Air squats, le double).
  benchmark_zero: {
    blocks: [
      { movementId: "burpee", repsPerRound: [21, 15, 9] },
      { movementId: "push_up", repsPerRound: [21, 15, 9] },
      { movementId: "air_squat", repsPerRound: [42, 30, 18] },
    ],
  },

  // ───────── Épreuves « Autre » loguables (jusqu'ici en repli population silencieux) ─────────

  // Le Chaos — chipper POUR LE TEMPS (cap 15 min) : 400 m + 40 air squats + 30 sit-ups + 20 burpees
  // + 10 wall walks + 400 m. Un seul « tour » (chaque bloc = 1 passage). Le profil hybride moyen le
  // boucle plus lentement que le champion 7m10 (cohérent terrain), le débutant tape le cap (clamp).
  league_hybrid_chipper: {
    blocks: [
      { movementId: "run", repsPerRound: [400] },
      { movementId: "air_squat", repsPerRound: [40] },
      { movementId: "sit_up", repsPerRound: [30] },
      { movementId: "burpee", repsPerRound: [20] },
      { movementId: "wall_walk", repsPerRound: [10] },
      { movementId: "run", repsPerRound: [400] },
    ],
  },

  // Murph — 1600 m + 100 tractions + 200 pompes + 300 air squats + 1600 m. Le gilet lesté (9/6 kg)
  // n'est PAS modélisé en `loadKg` (table 1RM = barre uniquement ; pull/push/air squat absents) : la
  // lenteur réaliste vient de la FORCE faible (cadence pull-up basse, maxSet) sur les 100 tractions
  // strictes. La FORCE entre via `m.attributes` du pull-up (50 % strength), même hors targetAttributes.
  murph: {
    blocks: [
      { movementId: "run", repsPerRound: [1600] },
      { movementId: "pull_up", repsPerRound: [100] },
      { movementId: "push_up", repsPerRound: [200] },
      { movementId: "air_squat", repsPerRound: [300] },
      { movementId: "run", repsPerRound: [1600] },
    ],
  },

  // Isabel — 30 arrachés (snatch) 60/40 kg, un seul « tour » de 30. La pénalité de charge RELATIVE
  // (1RM snatch estimé via la force) DOIT jouer : un snatch 60 kg près du 1RM effondre la cadence.
  isabel: {
    blocks: [{ movementId: "snatch", repsPerRound: [30], loadKg: { male: 60, female: 40 } }],
  },

  // La Flèche — échelle de sprint 100-200-300-400-300-200-100 m (1600 m). La récup imposée
  // (30/45/60 s) NE COMPTE PAS dans le score (cf. scoringNote) → on ne modélise QUE le temps couru
  // cumulé. Un seul « tour » : segments ≤200 m en `sprint` (vitesse), ≥300 m en `run` (moteur).
  league_sprint_ladder: {
    blocks: [
      { movementId: "sprint", repsPerRound: [100] },
      { movementId: "sprint", repsPerRound: [200] },
      { movementId: "run", repsPerRound: [300] },
      { movementId: "run", repsPerRound: [400] },
      { movementId: "run", repsPerRound: [300] },
      { movementId: "sprint", repsPerRound: [200] },
      { movementId: "sprint", repsPerRound: [100] },
    ],
  },

  // Le Moteur — AMRAP 12 min : 400 m course (NON comptée) + 20 air squats + 15 burpees. Score = reps
  // (air squats + burpees). La course prend du TEMPS (donc limite le nb de tours) mais le bloc est
  // `unscored` → elle ne gonfle pas le volume de reps prédit.
  league_engine_12: {
    blocks: [
      { movementId: "run", repsPerRound: [400], unscored: true },
      { movementId: "air_squat", repsPerRound: [20] },
      { movementId: "burpee", repsPerRound: [15] },
    ],
    amrap: { timeCapSec: 720, scoreUnit: "reps" },
  },

  // Le Pilier — AMRAP 12 min : 40 fentes + 30 air squats + 20 sit-ups + 16 pistols. Score = reps
  // totales. Les pistols (lents) bornent le débit.
  league_grind_squats: {
    blocks: [
      { movementId: "lunge", repsPerRound: [40] },
      { movementId: "air_squat", repsPerRound: [30] },
      { movementId: "sit_up", repsPerRound: [20] },
      { movementId: "pistol_squat", repsPerRound: [16] },
    ],
    amrap: { timeCapSec: 720, scoreUnit: "reps" },
  },

  // La Détente — AMRAP 12 min : 30 squat jumps + 25 burpee broad jumps. Score = reps totales,
  // 100 % explosif (forte dégradation).
  league_power_amrap: {
    blocks: [
      { movementId: "squat_jump", repsPerRound: [30] },
      { movementId: "burpee_broad_jump", repsPerRound: [25] },
    ],
    amrap: { timeCapSec: 720, scoreUnit: "reps" },
  },

  // HYROX solo — 8×(1000 m course + 1 station), agrégé en un « tour » multi-blocs (pour le temps).
  // Mapping : SkiErg 1000 m ≈ 70 cal (ski_erg_cal) ; Sled Push 50 m + Sled Pull 50 m ≈ 100 m de
  // push-équiv (sled_push) ; Burpee Broad Jump 80 m ; Row 1000 m ; Farmers Carry 200 m ; Sandbag
  // Lunges 100 m (lunge_m) ; 100 Wall balls (9/6). Tous les movementId existent.
  hyrox_solo: {
    blocks: [
      { movementId: "run", repsPerRound: [8000] },
      { movementId: "ski_erg_cal", repsPerRound: [70] },
      { movementId: "sled_push", repsPerRound: [100] },
      { movementId: "burpee_broad_jump_m", repsPerRound: [80] },
      { movementId: "row", repsPerRound: [1000] },
      { movementId: "farmers_carry", repsPerRound: [200] },
      { movementId: "lunge_m", repsPerRound: [100] },
      { movementId: "wall_ball", repsPerRound: [100], loadKg: { male: 9, female: 6 } },
    ],
  },
};

/** Recense les movementId référencés par les blueprints (test d'intégrité). */
export const BLUEPRINT_MOVEMENT_IDS: ReadonlySet<string> = new Set(
  Object.values(WOD_BLUEPRINTS).flatMap((bp) => bp.blocks.map((b) => b.movementId)),
);

/** Vérifie qu'un blueprint ne référence que des mouvements connus (utilisé en test + au repli). */
export function blueprintMovementsExist(bp: WodBlueprint): boolean {
  return bp.blocks.every((b) => MOVEMENTS_BY_ID.has(b.movementId));
}

/**
 * IDENTIFIANTS CANONIQUES des mouvements d'un WOD de référence, dans l'ORDRE d'exécution et SANS
 * doublon (un mouvement répété sur plusieurs blocs n'apparaît qu'une fois, à sa 1re occurrence).
 *
 * Source de vérité = le blueprint (`blocks[].movementId`), pas la prescription TEXTE : le guide des
 * mouvements côté mobile s'appuie dessus pour NE PLUS deviner par le nom FR. WOD sans blueprint
 * (course pure, max-reps, 1RM…) ⇒ `[]` (pas de décomposition exploitable).
 */
export function blueprintMovementIds(wodId: string): string[] {
  const bp = WOD_BLUEPRINTS[wodId];
  if (!bp) return [];
  const seen = new Set<string>();
  const ids: string[] = [];
  for (const block of bp.blocks) {
    if (!seen.has(block.movementId)) {
      seen.add(block.movementId);
      ids.push(block.movementId);
    }
  }
  return ids;
}
