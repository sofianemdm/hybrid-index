import { type CanActivate, type ExecutionContext, Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
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

/** Garde JWT : exige un Bearer token valide ET un compte encore actif, expose `request.user`.
 *  Vérifie le statut en base (compte supprimé ou banni → 401) avec un cache Redis court pour ne pas
 *  frapper la DB à chaque requête. Rend le token révocable malgré sa durée de vie longue. */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<GuardRequest>();
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token manquant." });
    }
    let payload: JwtPayload;
    try {
      payload = this.jwt.verify<JwtPayload>(header.slice(7));
    } catch {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token invalide ou expiré." });
    }

    if (!(await this.isActive(payload.sub))) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Session expirée. Reconnecte-toi." });
    }
    req.user = { userId: payload.sub, email: payload.email };
    return true;
  }

  /** Vrai si le compte existe et est `active`. Cache Redis 60 s (clé `usrok:{id}` = '1'/'0').
   *  Si Redis est indisponible (cache=null), on interroge la DB : un compte supprimé/banni doit
   *  être rejeté même sans cache (jamais fail-open sur l'authentification). */
  private async isActive(userId: string): Promise<boolean> {
    const cacheKey = `usrok:${userId}`;
    const cached = await this.redis.get(cacheKey);
    if (cached === "1") return true;
    if (cached === "0") return false;
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { status: true } });
    const ok = user != null && user.status === "active";
    await this.redis.setEx(cacheKey, ok ? "1" : "0", 60);
    return ok;
  }
}
