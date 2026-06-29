import { UnauthorizedException } from "@nestjs/common";
import type { JwtService } from "@nestjs/jwt";
import { AuthTokenService } from "../src/modules/auth/auth-token.service";
import type { PrismaService } from "../src/infra/prisma/prisma.service";
import type { RedisService } from "../src/infra/redis/redis.service";

/**
 * Brique d'auth PARTAGÉE par le garde REST et le gateway WebSocket. On vérifie la même logique
 * que l'ancien `JwtAuthGuard` : token requis, vérif du secret, contrôle « compte actif » (cache
 * Redis `usrok:{id}`, repli DB), et jamais de fail-open.
 */
function build(opts: {
  verify?: (t: string) => { sub: string; email: string };
  redisGet?: (k: string) => Promise<string | null>;
  dbStatus?: string | null; // null = utilisateur introuvable
}) {
  const setExCalls: Array<{ key: string; value: string }> = [];
  const jwt = {
    verify: opts.verify ?? ((): never => { throw new Error("invalid"); }),
  } as unknown as JwtService;
  const prisma = {
    user: {
      findUnique: jest.fn(async () => (opts.dbStatus === undefined || opts.dbStatus === null ? null : { status: opts.dbStatus })),
    },
  } as unknown as PrismaService;
  const redis = {
    get: jest.fn(opts.redisGet ?? (async () => null)),
    setEx: jest.fn(async (key: string, value: string) => { setExCalls.push({ key, value }); }),
  } as unknown as RedisService;
  return { svc: new AuthTokenService(jwt, prisma, redis), prisma, redis, setExCalls };
}

describe("AuthTokenService — verifyToken (auth partagée REST/WS)", () => {
  it("token absent → UnauthorizedException", async () => {
    const { svc } = build({});
    await expect(svc.verifyToken(undefined)).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(svc.verifyToken(null)).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(svc.verifyToken("")).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it("token invalide/expiré (jwt.verify lève) → UnauthorizedException", async () => {
    const { svc } = build({ verify: () => { throw new Error("jwt expired"); } });
    await expect(svc.verifyToken("bad")).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it("token valide + compte actif (cache Redis '1') → renvoie l'utilisateur, sans toucher la DB", async () => {
    const { svc, prisma } = build({
      verify: () => ({ sub: "u1", email: "a@b.c" }),
      redisGet: async () => "1",
    });
    await expect(svc.verifyToken("ok")).resolves.toEqual({ userId: "u1", email: "a@b.c" });
    expect((prisma.user.findUnique as jest.Mock)).not.toHaveBeenCalled();
  });

  it("token valide mais compte inactif (cache Redis '0') → UnauthorizedException", async () => {
    const { svc } = build({
      verify: () => ({ sub: "u1", email: "a@b.c" }),
      redisGet: async () => "0",
    });
    await expect(svc.verifyToken("ok")).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it("cache absent → repli DB : status 'active' accepté et mis en cache '1'", async () => {
    const { svc, setExCalls } = build({
      verify: () => ({ sub: "u1", email: "a@b.c" }),
      redisGet: async () => null,
      dbStatus: "active",
    });
    await expect(svc.verifyToken("ok")).resolves.toEqual({ userId: "u1", email: "a@b.c" });
    expect(setExCalls).toContainEqual({ key: "usrok:u1", value: "1" });
  });

  it("cache absent + utilisateur introuvable → rejet (jamais fail-open) et cache '0'", async () => {
    const { svc, setExCalls } = build({
      verify: () => ({ sub: "ghost", email: "x@y.z" }),
      redisGet: async () => null,
      dbStatus: null,
    });
    await expect(svc.verifyToken("ok")).rejects.toBeInstanceOf(UnauthorizedException);
    expect(setExCalls).toContainEqual({ key: "usrok:ghost", value: "0" });
  });

  it("cache absent + status non-'active' (ex. banned) → rejet", async () => {
    const { svc } = build({
      verify: () => ({ sub: "u1", email: "a@b.c" }),
      redisGet: async () => null,
      dbStatus: "banned",
    });
    await expect(svc.verifyToken("ok")).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
