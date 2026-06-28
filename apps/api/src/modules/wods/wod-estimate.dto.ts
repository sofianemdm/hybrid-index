import { z } from "zod";
import { ScoreType, Sex } from "@hybrid-index/contracts";

/** Estimation ad-hoc d'un WOD décomposé (aperçu du builder). */
export const EstimateWodRequest = z.object({
  sex: Sex,
  scoreType: ScoreType,
  // Voir CreateWodRequest : `"distance"` retiré (aucun chemin UI builder, séquelle BUG-005).
  wodType: z.enum(["for_time", "amrap", "emom", "chipper", "strength", "interval", "tabata"]),
  timeCapSec: z.number().int().positive().optional(),
  rounds: z.number().int().positive().optional(),
  blocks: z
    .array(
      z.object({
        movementId: z.string(),
        reps: z.number().int().positive().optional(),
        loadKg: z.number().positive().optional(),
        distanceMeters: z.number().positive().optional(),
        calories: z.number().positive().optional(),
        durationSec: z.number().positive().optional(),
      }),
    )
    .min(1),
  userResult: z.number().positive().optional(),
});
export type EstimateWodRequest = z.infer<typeof EstimateWodRequest>;
