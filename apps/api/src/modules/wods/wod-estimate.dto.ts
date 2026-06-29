import { z } from "zod";
import { ScoreType, Sex } from "@hybrid-index/contracts";
import {
  MAX_BLOCKS,
  MAX_CALORIES,
  MAX_DISTANCE_M,
  MAX_DURATION_SEC,
  MAX_LOAD_KG,
  MAX_REPS,
  MAX_ROUNDS,
  MAX_TIME_CAP_SEC,
} from "./create-wod.dto";

// Cet endpoint (/estimate) est PUBLIC et appelé à chaque frappe dans le builder, puis relayé
// au microservice Score. On applique EXACTEMENT les mêmes bornes anti-abus/DoS que
// CreateWodRequest (mêmes constantes MAX_* importées) pour rejeter en 422 tout payload géant.

/** Estimation ad-hoc d'un WOD décomposé (aperçu du builder). */
export const EstimateWodRequest = z.object({
  sex: Sex,
  scoreType: ScoreType,
  // Voir CreateWodRequest : `"distance"` retiré (aucun chemin UI builder, séquelle BUG-005).
  wodType: z.enum(["for_time", "amrap", "emom", "chipper", "strength", "interval", "tabata"]),
  timeCapSec: z.number().int().positive().max(MAX_TIME_CAP_SEC).optional(),
  rounds: z.number().int().positive().max(MAX_ROUNDS).optional(),
  blocks: z
    .array(
      z.object({
        movementId: z.string().min(1).max(80),
        reps: z.number().int().positive().max(MAX_REPS).optional(),
        loadKg: z.number().positive().max(MAX_LOAD_KG).optional(),
        distanceMeters: z.number().positive().max(MAX_DISTANCE_M).optional(),
        calories: z.number().positive().max(MAX_CALORIES).optional(),
        durationSec: z.number().positive().max(MAX_DURATION_SEC).optional(),
      }),
    )
    .min(1)
    .max(MAX_BLOCKS),
  userResult: z.number().positive().optional(),
});
export type EstimateWodRequest = z.infer<typeof EstimateWodRequest>;
