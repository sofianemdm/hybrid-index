import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import { PrismaClient } from "@prisma/client";
import Redis from "ioredis";
import { LeaderboardService } from "../src/modules/leaderboard/leaderboard.service";
import { PrismaService } from "../src/infra/prisma/prisma.service";
import { RedisService } from "../src/infra/redis/redis.service";

/**
 * Tie-break déterministe (audit BUG-007/008/009) : à Index égal, l'ordre du classement et « ma
 * position » doivent être STABLES et IDENTIQUES (départage par userId asc), entre Redis et Postgres.
 * Nécessite Postgres + Redis up.
 */
describe("api — classement tie-break déterministe (e2e réel)", () => {
  let app: INestApplication;
  let prisma: PrismaClient;
  let redis: Redis;
  let lb: LeaderboardService;

  const stamp = Date.now();
  const SCORING_VERSION_UUID = "11111111-1111-1111-1111-111111111111";
  const ids: string[] = [];
  const TIE_VALUE = 654; // valeur interne commune aux ex æquo

  beforeAll(async () => {
    const ref = await Test.createTestingModule({
      providers: [LeaderboardService, PrismaService, RedisService],
    }).compile();
    app = ref.createNestApplication();
    await app.init();
    lb = app.get(LeaderboardService);
    prisma = new PrismaClient();
    redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379", { maxRetriesPerRequest: 1 });

    // 3 athlètes hommes à Index EXACTEMENT égal + 1 strictement au-dessus.
    for (let i = 0; i < 4; i++) {
      const value = i === 0 ? TIE_VALUE + 50 : TIE_VALUE; // le 1er est devant, les 3 autres ex æquo
      const user = await prisma.user.create({
        data: {
          email: `tie_${stamp}_${i}@test.local`,
          dateOfBirth: new Date("1995-01-01"),
          ageVerified: true,
          consents: { seed: true },
          profile: { create: { displayName: `Tie${stamp}_${i}`, sex: "male", goal: "hyrox", equipmentPref: "both", rank: "silver" } },
          hybridIndex: {
            create: {
              value,
              percentile: value / 1000,
              isProvisional: false,
              isEstimated: false,
              radarCoverage: 6,
              confidenceLevel: "medium",
              scoringVersionId: SCORING_VERSION_UUID,
            },
          },
        },
      });
      ids.push(user.id);
      await redis.zadd("leaderboard:male", value, user.id).catch(() => undefined);
    }
  });

  afterAll(async () => {
    for (const id of ids) {
      await prisma.hybridIndex.deleteMany({ where: { userId: id } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id } }).catch(() => undefined);
      await redis.zrem("leaderboard:male", id).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    redis.disconnect();
    await app?.close();
  });

  it("l'ordre des ex æquo est stable et identique sur plusieurs lectures", async () => {
    const order1 = (await lb.leaderboard("male", 100)).entries.map((e) => e.userId);
    const order2 = (await lb.leaderboard("male", 100)).entries.map((e) => e.userId);
    expect(order1).toEqual(order2); // déterministe

    // Parmi mes 3 ex æquo, l'ordre suit userId asc (tie-break).
    const tied = ids.slice(1);
    const tiedSortedByUserId = [...tied].sort();
    const tiedInBoard = order1.filter((u) => tied.includes(u));
    expect(tiedInBoard).toEqual(tiedSortedByUserId);
  });

  it("« ma position » coïncide avec la ligne isMe dans la liste (pas de divergence sur ex æquo)", async () => {
    for (const id of ids) {
      const board = await lb.leaderboard("male", 100, id);
      const myEntry = board.entries.find((e) => e.isMe);
      expect(myEntry).toBeTruthy();
      expect(board.me).not.toBeNull();
      expect(board.me!.position).toBe(myEntry!.position);
    }
  });
});
