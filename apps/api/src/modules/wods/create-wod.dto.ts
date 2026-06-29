import { z } from "zod";
import { ScoreType } from "@hybrid-index/contracts";

// Bornes anti-abus : un humain ne dépasse jamais ces valeurs sur un bloc. Au-delà = saisie
// erronée ou tentative de pollution (overflow d'affichage, scores aberrants). On rejette en 422.
// Exportées pour être réutilisées à l'identique par EstimateWodRequest (wod-estimate.dto.ts),
// afin que l'endpoint PUBLIC /estimate applique EXACTEMENT les mêmes bornes anti-abus.
export const MAX_REPS = 100_000;
export const MAX_LOAD_KG = 1_000; // record du monde épaule-jeté ≈ 264 kg → 1000 laisse une marge énorme
export const MAX_DISTANCE_M = 1_000_000; // 1000 km
export const MAX_CALORIES = 100_000;
export const MAX_DURATION_SEC = 86_400; // 24 h
export const MAX_TIME_CAP_SEC = 86_400; // 24 h
export const MAX_ROUNDS = 100;
export const MAX_BLOCKS = 20;

const WodBlock = z.object({
  movementId: z.string().min(1).max(80),
  reps: z.number().int().positive().max(MAX_REPS).optional(),
  loadKg: z.number().positive().max(MAX_LOAD_KG).optional(),
  distanceMeters: z.number().positive().max(MAX_DISTANCE_M).optional(),
  calories: z.number().positive().max(MAX_CALORIES).optional(),
  durationSec: z.number().positive().max(MAX_DURATION_SEC).optional(),
});

/** Création d'un WOD personnalisé (constructeur). Les charges Rx sont dans `loadKg` des blocs. */
export const CreateWodRequest = z.object({
  name: z.string().min(2).max(60),
  // Pas de `"distance"` : ce format n'a jamais de chemin UI dans le builder (séquelle BUG-005).
  // La course se mesure via les WODs de course dédiés (`run_*`), pas via un WOD custom.
  type: z.enum(["for_time", "amrap", "emom", "chipper", "strength", "interval", "tabata"]),
  scoreType: ScoreType,
  requiresEquipment: z.boolean(),
  timeCapSec: z.number().int().positive().max(MAX_TIME_CAP_SEC).optional(),
  rounds: z.number().int().positive().max(MAX_ROUNDS).optional(),
  blocks: z.array(WodBlock).min(1).max(MAX_BLOCKS),
});
export type CreateWodRequest = z.infer<typeof CreateWodRequest>;

/** Log d'un résultat sur un WOD (officiel ou custom). `rxCompliant` = charges Rx respectées. */
export const LogWodResultRequest = z.object({
  rawResult: z.number().positive(),
  rxCompliant: z.boolean().optional(),
  /** Distance parcourue en mètres — REQUIS pour la course à distance libre (`run_free_distance`). */
  distanceMeters: z.number().int().positive().optional(),
  /** Clé d'idempotence (anti double-comptage sur retry réseau / double-tap). */
  idempotencyKey: z.string().min(1).max(128).optional(),
});
export type LogWodResultRequest = z.infer<typeof LogWodResultRequest>;
