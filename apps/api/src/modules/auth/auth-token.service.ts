import { Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
import type { JwtPayload } from "./auth.service";

export interface AuthenticatedUser {
  userId: string;
  email: string;
}

/**
 * Brique d'authentification PARTAGÉE entre le garde REST (`JwtAuthGuard`) et le gateway WebSocket
 * (`RealtimeGateway`). Une seule vérité : même secret JWT (via `JwtModule` `@Global`) et même
 * contrôle « compte actif » (cache Redis `usrok:{id}`, 60 s). Aucune divergence possible REST/WS.
 */
@Injectable()
export class AuthTokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  /**
   * Vérifie un JWT brut (sans le préfixe « Bearer ») ET que le compte est encore actif.
   * Lève `UnauthorizedException` si le token est absent / invalide / expiré, ou si le compte
   * n'est plus actif (supprimé / banni). Renvoie l'utilisateur authentifié sinon.
   */
  async verifyToken(rawToken: string | undefined | null): Promise<AuthenticatedUser> {
    if (!rawToken) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token manquant." });
    }
    let payload: JwtPayload;
    try {
      payload = this.jwt.verify<JwtPayload>(rawToken);
    } catch {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token invalide ou expiré." });
    }
    if (!(await this.isActive(payload.sub))) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Session expirée. Reconnecte-toi." });
    }
    return { userId: payload.sub, email: payload.email };
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
