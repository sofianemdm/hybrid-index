import "reflect-metadata";
import type { ExecutionContext } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import type { JwtService } from "@nestjs/jwt";
import { RATE_LIMIT_KEY, RateLimitGuard, type RateLimitOptions } from "../src/common/rate-limit.guard";
import type { RedisService } from "../src/infra/redis/redis.service";

/**
 * Repli EN MÉMOIRE du rate-limit quand Redis est indisponible (fin du fail-open) :
 * un incident Redis ne doit JAMAIS laisser login/register sans limite (brute-force).
 * Test unitaire pur (aucune infra) — Redis est simulé « down » (rateLimit → null).
 */
describe("RateLimitGuard — repli mémoire quand Redis est down", () => {
  const OPTS: RateLimitOptions = { limit: 3, windowSec: 60 };
  let guard: RateLimitGuard;
  let savedEnv: string | undefined;

  const fakeContext = (ip: string): ExecutionContext =>
    ({
      switchToHttp: () => ({ getRequest: () => ({ headers: { "x-forwarded-for": ip } }) }),
      getHandler: () => Object,
      getClass: () => ({ name: "AuthController" }),
    }) as unknown as ExecutionContext;

  beforeEach(() => {
    // Le guard est désactivé sous NODE_ENV=test (jest le pose) → on simule un runtime réel.
    savedEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = "development";
    const reflector = { get: (key: string) => (key === RATE_LIMIT_KEY ? OPTS : undefined) } as unknown as Reflector;
    const redisDown = { rateLimit: async () => null } as unknown as RedisService;
    const jwt = { verify: () => ({}) } as unknown as JwtService;
    guard = new RateLimitGuard(reflector, redisDown, jwt);
  });

  afterEach(() => {
    process.env.NODE_ENV = savedEnv;
  });

  it("limite quand même les appels (compteur mémoire) au lieu de fail-open", async () => {
    // 3 appels autorisés…
    for (let i = 0; i < OPTS.limit; i++) {
      await expect(guard.canActivate(fakeContext("1.2.3.4"))).resolves.toBe(true);
    }
    // …le 4e est refusé (429), Redis étant pourtant indisponible.
    await expect(guard.canActivate(fakeContext("1.2.3.4"))).rejects.toMatchObject({ status: 429 });
  });

  it("les identités différentes ont des compteurs indépendants", async () => {
    for (let i = 0; i < OPTS.limit; i++) {
      await expect(guard.canActivate(fakeContext("1.2.3.4"))).resolves.toBe(true);
    }
    await expect(guard.canActivate(fakeContext("5.6.7.8"))).resolves.toBe(true);
  });
});
