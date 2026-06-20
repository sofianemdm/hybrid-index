import { z } from "zod";

/**
 * Finalisation de l'onboarding (authentifié) : on enregistre les efforts saisis pendant
 * le wizard comme résultats déclarés, puis on calcule et persiste le HYBRID INDEX révélé.
 * Le sexe/objectif viennent du profil (fixés à l'inscription).
 */
export const OnboardingCompleteRequest = z.object({
  course: z
    .object({
      /** Distance parcourue en mètres (l'utilisateur saisit sa propre distance). */
      distanceMeters: z.number().min(400).max(42200),
      timeSeconds: z.number().positive(),
    })
    .optional(),
  /** Max de pompes strictes en UNE série. */
  estimatedPushups: z.number().int().min(0).optional(),
  /** Max de squats à vide en UNE série. */
  estimatedAirSquats: z.number().int().min(0).optional(),
});
export type OnboardingCompleteRequest = z.infer<typeof OnboardingCompleteRequest>;
