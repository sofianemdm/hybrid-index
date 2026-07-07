import { type CanActivate, type ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from "@nestjs/common";
import { AuthTokenService, type AuthenticatedUser } from "../auth/auth-token.service";

/** Forme minimale de requête HTTP (évite la dépendance aux types express). */
interface GuardRequest {
  headers: { authorization?: string };
  user?: AuthenticatedUser;
}

/** Emails admin depuis l'env (liste séparée par virgules, insensible à la casse). Lue à CHAQUE
 *  appel : pas de cache process → un changement d'env sur Railway prend effet au redéploiement,
 *  et les tests peuvent la faire varier. */
export function adminEmails(): Set<string> {
  return new Set(
    (process.env.ADMIN_EMAILS ?? "")
      .split(",")
      .map((e) => e.trim().toLowerCase())
      .filter(Boolean),
  );
}

/** Garde admin : Bearer valide (même vérité d'auth que JwtAuthGuard, via AuthTokenService)
 *  PUIS email présent dans la whitelist `ADMIN_EMAILS`. 403 générique sinon (pas d'oracle). */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly authToken: AuthTokenService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<GuardRequest>();
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token manquant." });
    }
    const user = await this.authToken.verifyToken(header.slice(7));
    if (!adminEmails().has(user.email.toLowerCase())) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Accès refusé." });
    }
    req.user = user;
    return true;
  }
}
