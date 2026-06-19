import { type CanActivate, type ExecutionContext, Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import type { JwtPayload } from "./auth.service";

export interface AuthenticatedUser {
  userId: string;
  email: string;
}

/** Forme minimale de requête HTTP utilisée par les gardes (évite la dépendance aux types express). */
interface GuardRequest {
  headers: { authorization?: string };
  user?: AuthenticatedUser;
}

/** Garde JWT : exige un Bearer token valide, expose `request.user`. */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<GuardRequest>();
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token manquant." });
    }
    try {
      const payload = this.jwt.verify<JwtPayload>(header.slice(7));
      req.user = { userId: payload.sub, email: payload.email };
      return true;
    } catch {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token invalide ou expiré." });
    }
  }
}
