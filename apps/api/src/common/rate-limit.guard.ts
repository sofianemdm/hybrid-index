import { type CanActivate, type ExecutionContext, HttpException, HttpStatus, Injectable, SetMetadata } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { RedisService } from "../infra/redis/redis.service";

/** Sous-ensemble de la requête HTTP dont le guard a besoin (évite la dépendance aux types express). */
interface HttpReq {
  headers: Record<string, string | string[] | undefined>;
  ip?: string;
  user?: { userId?: string };
}

export interface RateLimitOptions {
  /** Nombre d'appels autorisés dans la fenêtre. */
  limit: number;
  /** Durée de la fenêtre en secondes. */
  windowSec: number;
  /** Clé d'identité : par IP (défaut) ou par utilisateur authentifié. */
  by?: "ip" | "user";
}

export const RATE_LIMIT_KEY = "rate_limit";

/** Limite le débit d'une route. Compteur en Redis (fail-open si Redis indisponible).
 *  Ex. `@RateLimit({ limit: 5, windowSec: 900 })` = 5 req / 15 min / IP. */
export const RateLimit = (opts: RateLimitOptions): MethodDecorator => SetMetadata(RATE_LIMIT_KEY, opts);

@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly redis: RedisService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Désactivé en tests (mêmes IP/Redis partagés → faux 429 entre specs).
    if (process.env.NODE_ENV === "test") return true;
    const opts = this.reflector.get<RateLimitOptions | undefined>(RATE_LIMIT_KEY, context.getHandler());
    if (!opts) return true; // route non limitée

    const req = context.switchToHttp().getRequest<HttpReq>();
    const handler = `${context.getClass().name}.${context.getHandler().name}`;
    const identity = opts.by === "user" ? (req.user?.userId ?? this.ip(req)) : this.ip(req);
    const key = `${handler}:${identity}`;

    const count = await this.redis.rateLimit(key, opts.windowSec);
    if (count !== null && count > opts.limit) {
      throw new HttpException(
        { code: "RATE_LIMITED", message: "Trop de tentatives. Réessaie dans quelques instants." },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }

  private ip(req: HttpReq): string {
    // Derrière le proxy Railway/Netlify : on prend la 1re IP de x-forwarded-for si présente.
    const fwd = req.headers["x-forwarded-for"];
    const first = Array.isArray(fwd) ? fwd[0] : (fwd ?? "").split(",")[0].trim();
    return first || req.ip || "unknown";
  }
}
