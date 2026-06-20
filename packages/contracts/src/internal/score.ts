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
  // Aligné sur le modèle de données (architecture.md §3.1 — scoring.scoring_version).
  status: z.enum(["draft", "active", "superseded"]),
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
  /** Distance parcourue en mètres — requis pour la course à distance libre (`run_free_distance`). */
  distanceMeters: z.number().positive().optional(),
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

/** Un effort à noter (utilisé pour calculer le profil complet à partir de résultats bruts). */
export const EffortInput = z.object({
  wodId: z.string(),
  rawResult: z.number(),
  /** Distance en mètres — requis pour la course à distance libre (`run_free_distance`). */
  distanceMeters: z.number().positive().optional(),
  /** Âge de l'effort en semaines (0 = aujourd'hui). */
  ageWeeks: z.number().min(0).default(0),
});
export type EffortInput = z.infer<typeof EffortInput>;

/** Calcule le radar + l'Index à partir d'une liste d'efforts bruts (onboarding, re-calcul). */
export const ComputeProfileRequest = z.object({
  sex: Sex,
  goal: Goal,
  efforts: z.array(EffortInput),
});
export type ComputeProfileRequest = z.infer<typeof ComputeProfileRequest>;

export const RadarAttribute = z.object({
  attribute: AttributeKey,
  score: z.number().min(0).max(1000),
  unlocked: z.boolean(),
  isEstimated: z.boolean(),
  isStale: z.boolean(),
});
export type RadarAttribute = z.infer<typeof RadarAttribute>;

export const ComputeProfileResponse = z.object({
  index: ComputeIndexResponse,
  radar: z.array(RadarAttribute),
});
export type ComputeProfileResponse = z.infer<typeof ComputeProfileResponse>;

/** Projection d'Index : « si tu progresses sur cet attribut, ton Index passerait à X ». */
export const ComputeProjectionRequest = z.object({
  goal: Goal,
  targetAttribute: AttributeKey,
  attributeScores: z.array(
    z.object({
      attribute: AttributeKey,
      score: z.number().min(0).max(1000),
      unlocked: z.boolean(),
      isEstimated: z.boolean(),
    }),
  ),
});
export type ComputeProjectionRequest = z.infer<typeof ComputeProjectionRequest>;

export const ComputeProjectionResponse = z.object({
  current: z.number().min(0).max(1000),
  projected: z.number().min(0).max(1000),
  delta: z.number().min(0),
  targetAttribute: AttributeKey,
  targetScore: z.number().min(0).max(1000),
});
export type ComputeProjectionResponse = z.infer<typeof ComputeProjectionResponse>;
