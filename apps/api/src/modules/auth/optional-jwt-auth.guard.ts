import { type CanActivate, type ExecutionContext, Injectable } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import type { JwtPayload } from "./auth.service";
import type { AuthenticatedUser } from "./jwt-auth.guard";

interface GuardRequest {
  headers: { authorization?: string };
  user?: AuthenticatedUser;
}

/**
 * Garde JWT « optionnelle » : si un Bearer valide est présent, expose `request.user` ;
 * sinon laisse passer sans utilisateur (endpoints publics qui surlignent l'utilisateur connecté).
 */
@Injectable()
export class OptionalJwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<GuardRequest>();
    const header = req.headers.authorization;
    if (header?.startsWith("Bearer ")) {
      try {
        const payload = this.jwt.verify<JwtPayload>(header.slice(7));
        req.user = { userId: payload.sub, email: payload.email };
      } catch {
        // token invalide → on ignore, accès public.
      }
    }
    return true;
  }
}
