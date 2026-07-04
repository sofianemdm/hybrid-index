import { type CanActivate, type ExecutionContext, Injectable, UnauthorizedException } from "@nestjs/common";
import { AuthTokenService, type AuthenticatedUser } from "./auth-token.service";

export type { AuthenticatedUser } from "./auth-token.service";

/** Forme minimale de requête HTTP utilisée par les gardes (évite la dépendance aux types express). */
interface GuardRequest {
  headers: { authorization?: string };
  user?: AuthenticatedUser;
}

/** Garde JWT : exige un Bearer token valide ET un compte encore actif, expose `request.user`.
 *  Délègue la vérification (secret + statut `active` avec cache Redis `usrok:{id}`) à
 *  `AuthTokenService`, brique partagée avec le gateway WebSocket — une seule vérité d'auth. */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly authToken: AuthTokenService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<GuardRequest>();
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token manquant." });
    }
    req.user = await this.authToken.verifyToken(header.slice(7));
    return true;
  }
}
