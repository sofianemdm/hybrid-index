import { z } from "zod";
import { Goal, Sex } from "@hybrid-index/contracts";

const EquipmentPref = z.enum(["none", "equipped", "both"]);

/** Inscription : compte + profil minimal (age-gating D4 vérifié côté service). */
export const RegisterRequest = z.object({
  email: z.string().email(),
  password: z.string().min(8, "8 caractères minimum"),
  displayName: z.string().min(2).max(24),
  dateOfBirth: z.coerce.date(),
  sex: Sex,
  goal: Goal,
  equipmentPref: EquipmentPref.default("both"),
});
export type RegisterRequest = z.infer<typeof RegisterRequest>;

export const LoginRequest = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});
export type LoginRequest = z.infer<typeof LoginRequest>;

export interface AuthResponse {
  token: string;
  user: { id: string; email: string; displayName: string };
}
