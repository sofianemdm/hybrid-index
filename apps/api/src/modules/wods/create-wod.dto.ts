import { z } from "zod";
import { ScoreType } from "@hybrid-index/contracts";

const WodBlock = z.object({
  movementId: z.string(),
  reps: z.number().int().positive().optional(),
  loadKg: z.number().positive().optional(),
  distanceMeters: z.number().positive().optional(),
  calories: z.number().positive().optional(),
  durationSec: z.number().positive().optional(),
});

/** Création d'un WOD personnalisé (constructeur). Les charges Rx sont dans `loadKg` des blocs. */
export const CreateWodRequest = z.object({
  name: z.string().min(2).max(60),
  type: z.enum(["for_time", "amrap", "emom", "chipper", "strength", "interval", "tabata", "distance"]),
  scoreType: ScoreType,
  requiresEquipment: z.boolean(),
  timeCapSec: z.number().int().positive().optional(),
  rounds: z.number().int().positive().optional(),
  blocks: z.array(WodBlock).min(1).max(20),
});
export type CreateWodRequest = z.infer<typeof CreateWodRequest>;

/** Log d'un résultat sur un WOD (officiel ou custom). `rxCompliant` = charges Rx respectées. */
export const LogWodResultRequest = z.object({
  rawResult: z.number().positive(),
  rxCompliant: z.boolean().optional(),
  /** Distance parcourue en mètres — REQUIS pour la course à distance libre (`run_free_distance`). */
  distanceMeters: z.number().int().positive().optional(),
});
export type LogWodResultRequest = z.infer<typeof LogWodResultRequest>;
