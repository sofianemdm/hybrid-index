// TEMPORAIRE (auth-rebuild) : shim d'utilisateur courant sans JWT. À REMPLACER par la nouvelle auth.
//
// L'ancienne auth (JWT) a été retirée. Ce shim conserve la MÊME forme de sortie que l'ancien
// `@CurrentUser()` — un objet `AuthenticatedUser` `{ userId, email }` — pour que les ~20
// contrôleurs continuent de compiler et de fonctionner sans modification de leur logique.
//
// Résolution de l'utilisateur : en-tête HTTP `x-dev-user` s'il est présent (pratique pour
// tester plusieurs comptes), sinon la constante `DEV_USER_ID`.
import { createParamDecorator, type ExecutionContext } from "@nestjs/common";

/** Utilisateur « authentifié » — forme historique conservée pour ne rien casser côté contrôleurs. */
export interface AuthenticatedUser {
  userId: string;
  email: string;
}

/** UUID d'utilisateur de développement utilisé quand aucun `x-dev-user` n'est fourni. */
export const DEV_USER_ID = "00000000-0000-0000-0000-000000000001";

/** Email de développement associé au `DEV_USER_ID`. */
const DEV_USER_EMAIL = "dev@athlete-league.local";

/** Forme minimale de requête HTTP lue par le shim (évite la dépendance aux types express). */
interface ShimRequest {
  headers?: Record<string, string | string[] | undefined>;
}

/**
 * Injecte l'utilisateur courant. TEMPORAIRE : sans JWT, on lit `x-dev-user` (id) s'il existe,
 * sinon on renvoie `DEV_USER_ID`. Renvoie toujours un `AuthenticatedUser` non nul — les
 * signatures `AuthenticatedUser | undefined` restent valides (sur-ensemble du type).
 */
export const CurrentUser = createParamDecorator((_data: unknown, ctx: ExecutionContext): AuthenticatedUser => {
  const req = ctx.switchToHttp().getRequest<ShimRequest>();
  const raw = req.headers?.["x-dev-user"];
  const headerId = Array.isArray(raw) ? raw[0] : raw;
  const userId = headerId && headerId.trim() ? headerId.trim() : DEV_USER_ID;
  return { userId, email: userId === DEV_USER_ID ? DEV_USER_EMAIL : `${userId}@athlete-league.local` };
});
