import { z } from "zod";
import { Goal, Sex } from "@hybrid-index/contracts";

const EquipmentPref = z.enum(["none", "equipped", "both"]);

/** Inscription : compte + profil minimal (age-gating D4 vérifié côté service).
 *  `goal` est OPTIONNEL (le front ne propose plus hyrox/crossfit/condition) : défaut neutre
 *  « all_round » (poids d'attributs égaux → scoring non biaisé, cf. scoring-core/weights.ts). */
export const RegisterRequest = z.object({
  email: z.string().email(),
  password: z.string().min(8, "8 caractères minimum"),
  displayName: z.string().min(2).max(24),
  dateOfBirth: z.coerce.date(),
  sex: Sex,
  goal: Goal.default("all_round"),
  equipmentPref: EquipmentPref.default("both"),
});
export type RegisterRequest = z.infer<typeof RegisterRequest>;

export const LoginRequest = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});
export type LoginRequest = z.infer<typeof LoginRequest>;

/** Connexion Google : le profil n'est requis qu'à la PREMIÈRE connexion (Google ne fournit pas
 *  la date de naissance / le sexe / l'objectif, nécessaires à l'age-gating et au scoring). */
export const GoogleAuthRequest = z.object({
  idToken: z.string().min(1),
  profile: z
    .object({
      displayName: z.string().min(2).max(24),
      dateOfBirth: z.coerce.date(),
      sex: Sex,
      goal: Goal.default("all_round"), // objectif retiré du front → défaut neutre
      equipmentPref: EquipmentPref.default("equipped"),
    })
    .optional(),
});
export type GoogleAuthRequest = z.infer<typeof GoogleAuthRequest>;

/** Connexion Apple : mêmes règles que Google (profil requis à la PREMIÈRE connexion — Apple ne
 *  fournit ni la date de naissance ni le sexe). L'email vit DANS l'identityToken. */
export const AppleAuthRequest = z.object({
  identityToken: z.string().min(1),
  profile: z
    .object({
      displayName: z.string().min(2).max(24),
      dateOfBirth: z.coerce.date(),
      sex: Sex,
      goal: Goal.default("all_round"),
      equipmentPref: EquipmentPref.default("equipped"),
    })
    .optional(),
});
export type AppleAuthRequest = z.infer<typeof AppleAuthRequest>;

/** Demande de réinitialisation : réponse TOUJOURS identique (pas d'énumération d'emails). */
export const ForgotPasswordRequest = z.object({
  email: z.string().email(),
});
export type ForgotPasswordRequest = z.infer<typeof ForgotPasswordRequest>;

/** Réinitialisation : code à 6 chiffres reçu par email + nouveau mot de passe (mêmes règles
 *  que l'inscription). */
export const ResetPasswordRequest = z.object({
  email: z.string().email(),
  code: z.string().regex(/^\d{6}$/, "Code à 6 chiffres"),
  newPassword: z.string().min(8, "8 caractères minimum"),
});
export type ResetPasswordRequest = z.infer<typeof ResetPasswordRequest>;

export interface AuthResponse {
  token: string;
  user: { id: string; email: string; displayName: string };
}
