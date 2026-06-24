import { z } from "zod";
import { ScoreType } from "@hybrid-index/contracts";

/** Log d'un résultat de WOD par l'utilisateur connecté (le sexe vient du profil). */
export const LogResultRequest = z.object({
  wodId: z.string().min(1),
  scoreType: ScoreType,
  /** Résultat brut normalisé : secondes (time), reps, kg (load) ou mètres (distance). */
  rawResult: z.number().positive(),
  /** Distance parcourue en mètres — REQUIS pour la course à distance libre (`run_free_distance`). */
  distanceMeters: z.number().int().positive().optional(),
  // `performedAt` n'est PLUS accepté du client : l'heure serveur fait foi (anti-triche défi/streak).
  /** Clé d'idempotence (anti double-comptage sur retry réseau). */
  idempotencyKey: z.string().min(1).max(128).optional(),
});
export type LogResultRequest = z.infer<typeof LogResultRequest>;
