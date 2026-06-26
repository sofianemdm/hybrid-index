import { z } from "zod";

/** Signalement de bug envoyé par l'app (bouton « Signaler un bug », bêta).
 *  `message` obligatoire (texte du bug) ; `context` optionnel (écran / plateforme / version). */
export const CreateFeedbackRequest = z
  .object({
    message: z.string().trim().min(3).max(2000),
    context: z.string().trim().max(200).optional(),
  })
  .strict();
export type CreateFeedbackRequest = z.infer<typeof CreateFeedbackRequest>;
