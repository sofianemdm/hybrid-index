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
  /** Effort réalisé en « Scaled » (mouvements adaptés) plutôt qu'en Rx → légère décote du sous-score. */
  scaled: z.boolean().optional(),
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
  // Note d'affichage /100 « type FIFA » dérivée de la valeur interne (null si non mesuré).
  rating: z.number().min(0).max(100).nullable().optional(),
  ratingInt: z.number().int().min(0).max(100).nullable().optional(),
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

/** Grand Chelem (endgame) : combien des 15 WODs de référence battent le temps/score « pro ». */
export const ComputeGrandSlamRequest = z.object({
  sex: Sex,
  bests: z.array(z.object({ wodId: z.string(), rawResult: z.number() })),
});
export type ComputeGrandSlamRequest = z.infer<typeof ComputeGrandSlamRequest>;

export const ComputeGrandSlamResponse = z.object({
  beaten: z.number().int().min(0),
  total: z.number().int().min(0),
  remaining: z.array(z.string()),
});
export type ComputeGrandSlamResponse = z.infer<typeof ComputeGrandSlamResponse>;

/** Mouvement exposé au public (sans les paramètres internes de notation). */
export const MovementSummary = z.object({
  id: z.string(),
  name: z.string(),
  category: z.string(),
  unit: z.enum(["rep", "meter", "calorie", "second"]),
  requiresEquipment: z.boolean(),
});
export type MovementSummary = z.infer<typeof MovementSummary>;
export const MovementCatalog = z.array(MovementSummary);

/** Un bloc d'un WOD décomposé, envoyé au moteur d'estimation. */
export const WodBlockInput = z.object({
  movementId: z.string(),
  reps: z.number().int().positive().optional(),
  loadKg: z.number().positive().optional(),
  distanceMeters: z.number().positive().optional(),
  calories: z.number().positive().optional(),
  durationSec: z.number().positive().optional(),
});
export type WodBlockInput = z.infer<typeof WodBlockInput>;

export const LevelReference = z.object({
  level: z.enum(["champion", "intermediate", "occasional"]),
  rawResult: z.number(),
});
export type LevelReference = z.infer<typeof LevelReference>;

/** POST /v1/score/estimate — estime un WOD décomposé (custom) et note un résultat éventuel. */
export const ComputeEstimateRequest = z.object({
  sex: Sex,
  scoreType: ScoreType,
  wodType: z.enum(["for_time", "amrap", "emom", "chipper", "strength", "interval", "tabata", "distance"]),
  timeCapSec: z.number().int().positive().optional(),
  rounds: z.number().int().positive().optional(),
  blocks: z.array(WodBlockInput).min(1),
  /** Résultat de l'utilisateur à noter (optionnel : barème seul si absent). */
  userResult: z.number().positive().optional(),
});
export type ComputeEstimateRequest = z.infer<typeof ComputeEstimateRequest>;

export const ComputeEstimateResponse = z.object({
  subScore: z.number().min(0).max(1000).nullable(),
  percentile: z.number().min(0).max(1).nullable(),
  attributesAffected: z.array(AttributeKey),
  references: z.array(LevelReference).length(3),
  confidence: z.enum(["estimated", "low", "medium", "high"]),
  outOfBounds: z.boolean(),
  scoringVersionId: z.string(),
});
export type ComputeEstimateResponse = z.infer<typeof ComputeEstimateResponse>;

/** Paliers de référence (champion/intermédiaire/occasionnel) d'un WOD, par sexe. */
const WodLevelTriple = z.object({
  champion: z.number(),
  intermediate: z.number(),
  occasional: z.number(),
});
export const WodLevelsResponse = z.object({
  wodId: z.string(),
  scoreType: ScoreType,
  male: WodLevelTriple,
  female: WodLevelTriple,
});
export type WodLevelsResponse = z.infer<typeof WodLevelsResponse>;

/**
 * POST /v1/score/predict — PRÉDIT le résultat brut (temps/reps/charge) qu'un athlète FERAIT sur un
 * WOD de référence, à partir de son niveau courant (scores d'attribut). On INVERSE la chaîne de
 * scoring : userInternal (moyenne des sous-scores des attributs CIBLES débloqués) → percentile →
 * quantile(modèle). Aucun attribut cible débloqué ⇒ `predictedRaw: null`.
 */
export const PredictResultRequest = z.object({
  wodId: z.string(),
  sex: Sex,
  attributeScores: z.array(
    z.object({
      attribute: AttributeKey,
      /** Score interne /1000 de l'attribut. */
      score: z.number().min(0).max(1000),
      unlocked: z.boolean(),
    }),
  ),
});
export type PredictResultRequest = z.infer<typeof PredictResultRequest>;

export const PredictResultResponse = z.object({
  /** Résultat brut prédit (entier : secondes si time, reps si reps, kg si load, m si distance).
   *  `null` si le WOD est inconnu/non-prédictible, ou si aucun attribut cible n'est débloqué. */
  predictedRaw: z.number().int().nullable(),
  /** Type de métrique du WOD prédit (pour formater l'affichage côté mobile). */
  scoreType: ScoreType,
});
export type PredictResultResponse = z.infer<typeof PredictResultResponse>;
