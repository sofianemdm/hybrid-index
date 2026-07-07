import { z } from "zod";
import { Goal } from "@hybrid-index/contracts";

const EquipmentPref = z.enum(["none", "equipped", "both"]);

/** Mise à jour du profil (écran Paramètres). Tous les champs optionnels.
 *  NB : `displayName` est VOLONTAIREMENT absent — le pseudo est figé après la création du compte
 *  (décision produit). Toute clé inconnue (dont un `displayName` envoyé par un ancien client) est
 *  rejetée par `.strict()` → 400, jamais appliquée. */
export const UpdateMeRequest = z
  .object({
    goal: Goal.optional(),
    equipmentPref: EquipmentPref.optional(),
    // Langue du device (push localisés FR/EN). Repli serveur = "fr".
    locale: z.enum(["fr", "en"]).optional(),
  })
  .strict()
  .refine((v) => v.goal !== undefined || v.equipmentPref !== undefined || v.locale !== undefined, {
    message: "Aucun champ à mettre à jour.",
  });
export type UpdateMeRequest = z.infer<typeof UpdateMeRequest>;

/** Personnalisation de l'avatar — système DiceBear avataaars uniquement (ancien avatar dessiné supprimé). */
export const UpdateAvatarRequest = z.object({
  /** Photo de profil en data URL base64 (optionnelle, ≈ ≤ 400 Ko d'image). null = retirer. */
  photoData: z.string().max(600_000).nullable().optional(),
  /** Avatar DiceBear : style + seed (rendu via image). null = pas d'avatar DiceBear. */
  diceStyle: z.string().max(40).nullable().optional(),
  diceSeed: z.string().max(80).nullable().optional(),
  diceOptions: z.record(z.string()).nullable().optional(),
});
export type UpdateAvatarRequest = z.infer<typeof UpdateAvatarRequest>;
