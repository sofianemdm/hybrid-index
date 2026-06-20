import { z } from "zod";
import { Goal } from "@hybrid-index/contracts";

const EquipmentPref = z.enum(["none", "equipped", "both"]);

/** Mise à jour du profil (écran Paramètres). Tous les champs optionnels. */
export const UpdateMeRequest = z
  .object({
    displayName: z.string().min(2).max(24).optional(),
    goal: Goal.optional(),
    equipmentPref: EquipmentPref.optional(),
  })
  .refine((v) => v.displayName !== undefined || v.goal !== undefined || v.equipmentPref !== undefined, {
    message: "Aucun champ à mettre à jour.",
  });
export type UpdateMeRequest = z.infer<typeof UpdateMeRequest>;
