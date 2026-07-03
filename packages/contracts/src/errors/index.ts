import { z } from "zod";

/**
 * Codes d'erreur stables de l'API (cf. architecture.md §4.1 — format d'erreur standard).
 * Le code HTTP associé est indiqué en commentaire.
 */
export const ErrorCode = z.enum([
  "VALIDATION_ERROR", // 400
  "UNAUTHENTICATED", // 401
  "FORBIDDEN", // 403
  "NOT_FOUND", // 404
  "IDEMPOTENT_REPLAY", // 200 (renvoie la 1re réponse)
  "CONFLICT", // 409
  "WOD_RESULT_OUT_OF_BOUNDS", // 422 (hors bornes physiologiques, refusé)
  "WOD_RESULT_ANOMALY", // 422 (accepté mais flaggé, exclu des classements)
  "SCORE_SERVICE_UNAVAILABLE", // 503 (résultat stocké, score en attente)
  "AGE_RESTRICTED", // 403 (< 15 ans, décision D4 relevée 03/07)
  "RATE_LIMITED", // 429
  "INTERNAL", // 500
]);
export type ErrorCode = z.infer<typeof ErrorCode>;

/** Détails optionnels d'erreur (ex. validation : { field, min, max } ou map champ→messages). */
export const ApiErrorDetails = z.record(z.string(), z.unknown());
export type ApiErrorDetails = z.infer<typeof ApiErrorDetails>;

/** Enveloppe d'erreur standard renvoyée par l'API : `{ error: {...} }`. */
export const ApiError = z.object({
  error: z.object({
    code: ErrorCode,
    message: z.string(),
    details: ApiErrorDetails.optional(),
    /** Identifiant de corrélation pour le support / Sentry. */
    traceId: z.string().optional(),
  }),
});
export type ApiError = z.infer<typeof ApiError>;
