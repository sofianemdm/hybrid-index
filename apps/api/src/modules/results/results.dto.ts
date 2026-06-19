import { z } from "zod";
import { ScoreType } from "@hybrid-index/contracts";

/** Log d'un résultat de WOD par l'utilisateur connecté (le sexe vient du profil). */
export const LogResultRequest = z.object({
  wodId: z.string().min(1),
  scoreType: ScoreType,
  /** Résultat brut normalisé : secondes (time), reps, kg (load) ou mètres (distance). */
  rawResult: z.number().positive(),
  /** Date de réalisation (défaut : maintenant). */
  performedAt: z.coerce.date().optional(),
  /** Clé d'idempotence (anti double-comptage sur retry réseau). */
  idempotencyKey: z.string().min(1).max(128).optional(),
});
export type LogResultRequest = z.infer<typeof LogResultRequest>;
