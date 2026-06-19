import { z } from "zod";

/** Codes d'erreur stables de l'API (cf. architecture.md §4 — format d'erreur standard). */
export const ErrorCode = z.enum([
  "VALIDATION_ERROR",
  "UNAUTHORIZED",
  "FORBIDDEN",
  "NOT_FOUND",
  "CONFLICT",
  "AGE_RESTRICTED", // < 13 ans (décision D4)
  "PHYSIOLOGICAL_BOUNDS", // résultat hors [hardMin, hardMax] (anti-triche §5.5)
  "IDEMPOTENCY_CONFLICT", // resoumission offline avec payload divergent
  "SCORING_UNAVAILABLE", // score-service injoignable → résultat enregistré, score en attente
  "RATE_LIMITED",
  "INTERNAL",
]);
export type ErrorCode = z.infer<typeof ErrorCode>;

/** Enveloppe d'erreur standard renvoyée par l'API. */
export const ApiError = z.object({
  code: ErrorCode,
  message: z.string(),
  /** Détails de validation par champ (optionnel). */
  details: z.record(z.string(), z.array(z.string())).optional(),
  /** Identifiant de corrélation pour le support / Sentry. */
  traceId: z.string().optional(),
});
export type ApiError = z.infer<typeof ApiError>;
