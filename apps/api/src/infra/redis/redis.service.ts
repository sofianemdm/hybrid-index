import { Injectable, Logger, type OnModuleDestroy } from "@nestjs/common";
import Redis from "ioredis";

/**
 * Accès Redis. Les classements sont tenus via des sorted sets (décision verrouillée).
 * Résilient : si Redis est indisponible, les méthodes renvoient null/[] et l'appelant
 * retombe sur Postgres (source de vérité durable).
 */
@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private readonly client: Redis;
  private available = true;

  constructor() {
    this.client = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379", {
      lazyConnect: false,
      maxRetriesPerRequest: 1,
      retryStrategy: (times) => (times > 3 ? null : Math.min(times * 200, 1000)),
    });
    this.client.on("error", (err) => {
      if (this.available) {
        this.logger.warn(`Redis indisponible (fallback Postgres) : ${err.message}`);
      }
      this.available = false;
    });
    this.client.on("ready", () => {
      this.available = true;
    });
  }

  /** Clé du classement (ligue) pour un sexe donné. */
  private key(sex: string): string {
    return `leaderboard:${sex}`;
  }

  /** Met à jour la position d'un utilisateur dans la ligue de son sexe. */
  async setIndex(sex: string, userId: string, value: number): Promise<void> {
    try {
      await this.client.zadd(this.key(sex), value, userId);
    } catch {
      // ignore — Postgres reste la source de vérité.
    }
  }

  /** Retire un utilisateur du classement de son sexe (suppression de compte). */
  async remove(sex: string, userId: string): Promise<void> {
    try {
      await this.client.zrem(this.key(sex), userId);
    } catch {
      // ignore — Postgres reste la source de vérité.
    }
  }

  /** Reconstruit ENTIÈREMENT le classement d'un sexe depuis Postgres (source de vérité) : supprime
   *  le sorted set puis ré-injecte toutes les entrées. Auto-réparation quand Redis a été vidé ou
   *  jamais peuplé (ex. seed lancé sans REDIS_URL). No-op silencieux si Redis indisponible. */
  async rebuild(sex: string, entries: Array<{ userId: string; value: number }>): Promise<void> {
    try {
      const pipe = this.client.pipeline();
      pipe.del(this.key(sex));
      if (entries.length > 0) {
        const args: Array<string | number> = [];
        for (const e of entries) args.push(e.value, e.userId);
        pipe.zadd(this.key(sex), ...args);
      }
      await pipe.exec();
    } catch {
      // ignore — Postgres reste la source de vérité (le repli pgTop couvre la lecture).
    }
  }

  /** Rang (0-indexé, meilleur = 0) ou null si absent / Redis indisponible. */
  async rank(sex: string, userId: string): Promise<number | null> {
    try {
      const r = await this.client.zrevrank(this.key(sex), userId);
      return r ?? null;
    } catch {
      return null;
    }
  }

  async total(sex: string): Promise<number | null> {
    try {
      return await this.client.zcard(this.key(sex));
    } catch {
      return null;
    }
  }

  /** Top N (userId + valeur) du meilleur au moins bon. [] si indisponible. */
  async top(sex: string, limit: number): Promise<Array<{ userId: string; value: number }>> {
    try {
      const flat = await this.client.zrevrange(this.key(sex), 0, limit - 1, "WITHSCORES");
      return pairs(flat);
    } catch {
      return [];
    }
  }

  /** Plage de rangs [start, stop] (inclus, 0-indexé). [] si indisponible. */
  async range(sex: string, start: number, stop: number): Promise<Array<{ userId: string; value: number }>> {
    try {
      const flat = await this.client.zrevrange(this.key(sex), start, stop, "WITHSCORES");
      return pairs(flat);
    } catch {
      return [];
    }
  }

  /** Compteur de fenêtre glissante (rate-limit). Incrémente `rl:{key}` et pose un TTL au 1er hit.
   *  Renvoie le nombre d'appels dans la fenêtre, ou `null` si Redis indisponible (→ fail-open :
   *  on ne bloque jamais un utilisateur légitime sur une panne d'infra). */
  async rateLimit(key: string, windowSec: number): Promise<number | null> {
    try {
      const k = `rl:${key}`;
      const count = await this.client.incr(k);
      if (count === 1) await this.client.expire(k, windowSec);
      return count;
    } catch {
      return null;
    }
  }

  isAvailable(): boolean {
    return this.available;
  }

  async onModuleDestroy(): Promise<void> {
    this.client.disconnect();
  }
}

function pairs(flat: string[]): Array<{ userId: string; value: number }> {
  const out: Array<{ userId: string; value: number }> = [];
  for (let i = 0; i < flat.length; i += 2) {
    out.push({ userId: flat[i], value: Number(flat[i + 1]) });
  }
  return out;
}
