import { z } from "zod";

/**
 * Finalisation de l'onboarding (authentifié) : on enregistre les efforts saisis pendant
 * le wizard comme résultats déclarés, puis on calcule et persiste le HYBRID INDEX révélé.
 * Le sexe/objectif viennent du profil (fixés à l'inscription).
 */
export const OnboardingCompleteRequest = z.object({
  course: z
    .object({
      wodId: z.enum(["run_1k", "run_5k"]),
      timeSeconds: z.number().positive(),
    })
    .optional(),
  estimatedPushups: z.number().int().min(0).optional(),
});
export type OnboardingCompleteRequest = z.infer<typeof OnboardingCompleteRequest>;
