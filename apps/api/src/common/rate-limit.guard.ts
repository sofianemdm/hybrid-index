import { type CanActivate, type ExecutionContext, HttpException, HttpStatus, Injectable, SetMetadata } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { JwtService } from "@nestjs/jwt";
import { RedisService } from "../infra/redis/redis.service";
import { clientIp } from "./client-ip";

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

/** Limite le débit d'une route. Compteur en Redis ; si Redis est indisponible, REPLI sur un
 *  compteur en mémoire (par instance) — jamais de fail-open : les routes sensibles (login,
 *  register) restent limitées même en incident Redis.
 *  Ex. `@RateLimit({ limit: 5, windowSec: 900 })` = 5 req / 15 min / IP. */
export const RateLimit = (opts: RateLimitOptions): MethodDecorator => SetMetadata(RATE_LIMIT_KEY, opts);

@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly redis: RedisService,
    private readonly jwt: JwtService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Désactivé en tests (mêmes IP/Redis partagés → faux 429 entre specs).
    if (process.env.NODE_ENV === "test") return true;
    const opts = this.reflector.get<RateLimitOptions | undefined>(RATE_LIMIT_KEY, context.getHandler());
    if (!opts) return true; // route non limitée

    const req = context.switchToHttp().getRequest<HttpReq>();
    const handler = `${context.getClass().name}.${context.getHandler().name}`;
    // `by:'user'` : ce guard global s'exécute AVANT le JwtAuthGuard, donc req.user n'est pas encore
    // posé. On décode le sub du Bearer ICI (juste pour la clé — le JwtAuthGuard valide ensuite),
    // sinon le quota par utilisateur retomberait sur l'IP (faux positifs derrière un NAT).
    const identity = opts.by === "user" ? (this.userIdFromBearer(req) ?? this.ip(req)) : this.ip(req);
    const key = `${handler}:${identity}`;

    // Redis indisponible (null) → repli compteur EN MÉMOIRE (par instance). L'ancien comportement
    // fail-open laissait login/register SANS AUCUNE limite pendant un incident Redis (brute-force).
    const count = (await this.redis.rateLimit(key, opts.windowSec)) ?? this.memoryRateLimit(key, opts.windowSec);
    if (count > opts.limit) {
      throw new HttpException(
        { code: "RATE_LIMITED", message: "Trop de tentatives. Réessaie dans quelques instants." },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }

  /** Compteurs de secours en mémoire (fenêtre fixe). Suffisant en mono-instance ; en multi-instance
   *  la limite devient « par instance » — toujours infiniment mieux que pas de limite du tout. */
  private readonly memoryCounters = new Map<string, { count: number; resetAt: number }>();

  private memoryRateLimit(key: string, windowSec: number): number {
    const now = Date.now();
    // Nettoyage paresseux : borne la mémoire si Redis reste longtemps indisponible.
    if (this.memoryCounters.size > 10_000) {
      for (const [k, v] of this.memoryCounters) {
        if (v.resetAt <= now) this.memoryCounters.delete(k);
      }
      // Plafond DUR (revue 02/07) : si tout est encore actif (attaque distribuée pendant une panne
      // Redis prolongée), éviction FIFO — la Map ne dépasse jamais 10k entrées, quoi qu'il arrive.
      while (this.memoryCounters.size > 10_000) {
        const oldest = this.memoryCounters.keys().next().value;
        if (oldest === undefined) break;
        this.memoryCounters.delete(oldest);
      }
    }
    const entry = this.memoryCounters.get(key);
    if (!entry || entry.resetAt <= now) {
      this.memoryCounters.set(key, { count: 1, resetAt: now + windowSec * 1000 });
      return 1;
    }
    entry.count += 1;
    return entry.count;
  }

  /** sub du Bearer (clé de rate-limit par utilisateur). null si absent/invalide → repli IP. */
  private userIdFromBearer(req: HttpReq): string | null {
    const h = req.headers.authorization;
    const header = Array.isArray(h) ? h[0] : h;
    if (!header?.startsWith("Bearer ")) return null;
    try {
      const payload = this.jwt.verify<{ sub?: string }>(header.slice(7));
      return payload.sub ?? null;
    } catch {
      return null;
    }
  }

  private ip(req: HttpReq): string {
    // Derrière le proxy Railway/Netlify : logique partagée avec le visit-log (common/client-ip.ts).
    return clientIp(req);
  }
}
