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

    // ids[1] possède un avatar (DiceBear + options) ; ids[2] n'en a PAS → on vérifie que la ligne de
    // classement porte la vignette quand elle existe, et `null` sinon (repli mobile).
    await prisma.avatar.create({
      data: {
        userId: ids[1],
        skinTone: 3,
        hairStyle: 2,
        hairColor: 4,
        beardStyle: 1,
        accessory: 0,
        background: 5,
        diceStyle: "adventurer",
        diceSeed: "lb-seed",
        diceOptions: JSON.stringify({ skinColor: "f2d3b1" }),
        equippedCosmetics: {},
        unlockedCosmetics: {},
      },
    });
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
    // On ne compare que NOS athlètes : la base de test est partagée entre suites PARALLÈLES —
    // d'autres users s'insèrent entre deux lectures. Le contrat testé (ordre total stable des
    // ex æquo, tie-break userId asc) porte sur notre cohorte, pas sur la liste globale.
    const mine = (order: string[]) => order.filter((u) => ids.includes(u));
    const order1 = (await lb.leaderboard("male", 100)).entries.map((e) => e.userId);
    const order2 = (await lb.leaderboard("male", 100)).entries.map((e) => e.userId);
    expect(mine(order1)).toEqual(mine(order2)); // déterministe

    // Parmi mes 3 ex æquo, l'ordre suit userId asc (tie-break).
    const tied = ids.slice(1);
    const tiedSortedByUserId = [...tied].sort();
    const tiedInBoard = order1.filter((u) => tied.includes(u));
    expect(tiedInBoard).toEqual(tiedSortedByUserId);
  });

  it("« ma position » coïncide avec la ligne isMe dans la liste (pas de divergence sur ex æquo)", async () => {
    // Liste et « me » = deux lectures : un INSERT concurrent (suites parallèles, base partagée)
    // peut les faire diverger transitoirement. Une vraie divergence d'ex æquo (le bug visé) est
    // PERSISTANTE → retry borné : la course s'évapore, le bug réel ferait toujours échouer.
    for (const id of ids) {
      let ok = false;
      for (let attempt = 0; attempt < 3 && !ok; attempt++) {
        const board = await lb.leaderboard("male", 100, id);
        const myEntry = board.entries.find((e) => e.isMe);
        expect(myEntry).toBeTruthy();
        expect(board.me).not.toBeNull();
        ok = board.me!.position === myEntry!.position;
        if (!ok && attempt === 2) expect(board.me!.position).toBe(myEntry!.position);
      }
      expect(ok).toBe(true);
    }
  });

  it("chaque entrée porte `avatar` : vignette si l'athlète en a une, null sinon", async () => {
    const board = await lb.leaderboard("male", 100);
    const withAvatar = board.entries.find((e) => e.userId === ids[1]);
    const withoutAvatar = board.entries.find((e) => e.userId === ids[2]);

    // ids[1] a un avatar → même forme JSON que le profil public (diceStyle/diceSeed/diceOptions…).
    expect(withAvatar!.avatar).toEqual({
      skinTone: 3,
      hairStyle: 2,
      hairColor: 4,
      beardStyle: 1,
      accessory: 0,
      background: 5,
      photoData: null,
      diceStyle: "adventurer",
      diceSeed: "lb-seed",
      diceOptions: { skinColor: "f2d3b1" },
    });

    // ids[2] n'a pas d'avatar → null (le mobile gère le repli).
    expect(withoutAvatar!.avatar).toBeNull();
    // Le champ est TOUJOURS présent sur chaque entrée (jamais undefined).
    for (const e of board.entries) expect(e).toHaveProperty("avatar");
  });
});
