import { z } from "zod";
import { AttributeKey, Goal, ScoreType, Sex } from "../enums";

/**
 * Contrat INTERNE versionné api <-> score-service (cf. architecture.md §4/§5).
 * Préfixe d'URL : /v1/score/*. Chaque valeur dérivée porte la `scoringVersionId`.
 * NB : les schémas de calcul complets (sous-score, index) seront étoffés à l'incrément 1.
 */

/** Métadonnées d'une version de scoring (courbe f + poids). */
export const ScoringVersionInfo = z.object({
  id: z.string(), // ex. "scoring-v1"
  status: z.enum(["draft", "active", "deprecated"]),
  curve: z.string(), // ex. "sigmoid-v1"
  createdAt: z.string(), // ISO 8601
});
export type ScoringVersionInfo = z.infer<typeof ScoringVersionInfo>;

/** Réponse de santé/version du score-service. */
export const ScoreServiceHealth = z.object({
  service: z.literal("score-service"),
  status: z.literal("ok"),
  activeScoringVersion: z.string(),
});
export type ScoreServiceHealth = z.infer<typeof ScoreServiceHealth>;

/** Demande de sous-score d'un effort (squelette — détaillé à l'incrément 1). */
export const ComputeSubScoreRequest = z.object({
  wodId: z.string(),
  sex: Sex,
  scoreType: ScoreType,
  /** Résultat brut, normalisé en nombre (secondes / reps / kg / mètres). */
  rawResult: z.number(),
});
export type ComputeSubScoreRequest = z.infer<typeof ComputeSubScoreRequest>;

export const ComputeSubScoreResponse = z.object({
  subScore: z.number().min(0).max(1000),
  percentile: z.number().min(0).max(1),
  attributesAffected: z.array(AttributeKey),
  scoringVersionId: z.string(),
});
export type ComputeSubScoreResponse = z.infer<typeof ComputeSubScoreResponse>;

/** Demande d'agrégation de l'Index à partir des scores d'attributs débloqués. */
export const ComputeIndexRequest = z.object({
  sex: Sex,
  goal: Goal,
  attributeScores: z.array(
    z.object({
      attribute: AttributeKey,
      score: z.number().min(0).max(1000),
      isEstimated: z.boolean(),
    }),
  ),
});
export type ComputeIndexRequest = z.infer<typeof ComputeIndexRequest>;

export const ComputeIndexResponse = z.object({
  value: z.number().min(0).max(1000),
  percentile: z.number().min(0).max(1),
  isProvisional: z.boolean(),
  isEstimated: z.boolean(),
  radarCoverage: z.number().int().min(0).max(6),
  scoringVersionId: z.string(),
});
export type ComputeIndexResponse = z.infer<typeof ComputeIndexResponse>;
