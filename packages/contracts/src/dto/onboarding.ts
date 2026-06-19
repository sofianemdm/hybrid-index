import { z } from "zod";
import { AttributeKey, EquipmentPref, Goal, Rank, Sex } from "../enums";

/**
 * Onboarding — estimation du HYBRID INDEX provisoire (le « reveal », cahier §8).
 * Ne crée PAS de compte : calcul pur (api → score-service), pour le « waouh » < 60 s.
 * La persistance (inscription) est un endpoint séparé (nécessite la base de données).
 */

/** Un effort de course saisi à l'onboarding (écran 5 « temps de course conseillé »). */
export const OnboardingCourse = z.object({
  /** WOD de course : `run_5k`, `run_1k`. */
  wodId: z.string(),
  /** Temps en secondes. */
  timeSeconds: z.number().positive(),
});
export type OnboardingCourse = z.infer<typeof OnboardingCourse>;

export const OnboardingEstimateRequest = z.object({
  sex: Sex,
  goal: Goal,
  equipmentPref: EquipmentPref.optional(),
  /** Temps de course (conseillé, skippable). */
  course: OnboardingCourse.optional(),
  /** Auto-évaluation 5bis : max de pompes approximatif (estimé). */
  estimatedPushups: z.number().int().min(0).optional(),
});
export type OnboardingEstimateRequest = z.infer<typeof OnboardingEstimateRequest>;

/** Un attribut du radar tel qu'affiché au reveal. */
export const RevealRadarAttribute = z.object({
  attribute: AttributeKey,
  score: z.number().min(0).max(1000),
  unlocked: z.boolean(),
  isEstimated: z.boolean(),
});
export type RevealRadarAttribute = z.infer<typeof RevealRadarAttribute>;

/** La réponse du reveal : l'Index provisoire + son rang + le radar de départ. */
export const RevealResponse = z.object({
  index: z.object({
    value: z.number().min(0).max(1000),
    percentile: z.number().min(0).max(1),
    rank: Rank,
    isProvisional: z.boolean(),
    isEstimated: z.boolean(),
    radarCoverage: z.number().int().min(0).max(6),
  }),
  radar: z.array(RevealRadarAttribute),
});
export type RevealResponse = z.infer<typeof RevealResponse>;
