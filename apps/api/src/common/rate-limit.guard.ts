import { type CanActivate, type ExecutionContext, HttpException, HttpStatus, Injectable, SetMetadata } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { RedisService } from "../infra/redis/redis.service";

/** Sous-ensemble de la requête HTTP dont le guard a besoin (évite la dépendance aux types express). */
interface HttpReq {
  headers: Record<string, string | string[] | undefined>;
  ip?: string;
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
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Désactivé en tests (mêmes IP/Redis partagés → faux 429 entre specs).
    if (process.env.NODE_ENV === "test") return true;
    const opts = this.reflector.get<RateLimitOptions | undefined>(RATE_LIMIT_KEY, context.getHandler());
    if (!opts) return true; // route non limitée

    const req = context.switchToHttp().getRequest<HttpReq>();
    const handler = `${context.getClass().name}.${context.getHandler().name}`;
    // TEMPORAIRE (auth-rebuild) : l'identité par utilisateur reposait sur le JWT (sub du Bearer).
    // Auth retirée → on limite par IP dans tous les cas. TODO : rebrancher `by:'user'` sur la
    // nouvelle auth (identifiant utilisateur validé) quand elle existera.
    const identity = this.ip(req);
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

  private ip(req: HttpReq): string {
    // Derrière le proxy Railway/Netlify : on prend la 1re IP de x-forwarded-for si présente.
    const fwd = req.headers["x-forwarded-for"];
    const first = Array.isArray(fwd) ? fwd[0] : (fwd ?? "").split(",")[0].trim();
    return first || req.ip || "unknown";
  }
}
