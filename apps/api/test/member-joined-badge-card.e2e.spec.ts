import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import Redis from "ioredis";
// Vrai score-service en mémoire → reveal/recalcul réels (pas de mock).
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

/**
 * E2E réel (DB + Redis + score-service en mémoire) couvrant :
 *  - T2 : l'événement de feed « member_joined » (« X nous rejoint avec un index de Y ») n'est émis
 *    QUE lorsque l'Index est COMPLET (non estimé). Index estimé → aucun événement, jusqu'à ce qu'un
 *    effort réel le rende non estimé.
 *  - T5 : GET /v1/me/badges/card renvoie les badges GAGNÉS (compacts) + cosmétiques actifs.
 * Nécessite Docker (Postgres + Redis) up et la base migrée/seedée.
 */
describe("api — member_joined (index complet) + carte badges (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;
  let redis: Redis;

  const stamp = Date.now();
  const ids: string[] = [];

  beforeAll(async () => {
    const scoreRef = await Test.createTestingModule({ imports: [ScoreAppModule] }).compile();
    scoreApp = configureScoreApp(scoreRef.createNestApplication());
    await scoreApp.listen(0);
    const port = (scoreApp.getHttpServer().address() as AddressInfo).port;
    process.env.SCORE_SERVICE_URL = `http://127.0.0.1:${port}`;

    const { AppModule } = await import("../src/app.module");
    const { configureApp } = await import("../src/app.config");
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();

    prisma = new PrismaClient();
    redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379", { maxRetriesPerRequest: 1 });
  });

  afterAll(async () => {
    for (const id of ids) {
      await prisma.hybridIndexHistory.deleteMany({ where: { userId: id } }).catch(() => undefined);
      await prisma.progressWeekly.deleteMany({ where: { userId: id } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id } }).catch(() => undefined);
      await redis.zrem("leaderboard:male", id).catch(() => undefined);
      await redis.zrem("leaderboard:female", id).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    redis.disconnect();
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  async function registerAdult(tag: string, sex: "male" | "female"): Promise<{ token: string; userId: string }> {
    const res = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email: `e2e_mj_${tag}_${stamp}@test.local`,
        password: "motdepasse123",
        displayName: `MJ${tag}${stamp}`,
        dateOfBirth: "1995-05-10",
        sex,
        // goal volontairement OMIS → défaut all_round (T4) ; valide aussi que le register marche sans.
      })
      .expect(201);
    const userId = res.body.user.id as string;
    ids.push(userId);
    return { token: res.body.token as string, userId };
  }

  function joinEvents(userId: string) {
    return prisma.feedEvent.findMany({ where: { actorId: userId, type: "member_joined" } });
  }

  it("T4 : register SANS goal aboutit (défaut all_round)", async () => {
    // registerAdult ci-dessus n'envoie pas de goal : s'il échouait, expect(201) lèverait.
    const { token } = await registerAdult("nogoal", "male");
    const me = await request(api.getHttpServer()).get("/v1/me").set("authorization", `Bearer ${token}`).expect(200);
    expect(me.body.goal).toBe("all_round");
  });

  it("T2 : Index ESTIMÉ (pompes seules) → AUCUN member_joined", async () => {
    const { token, userId } = await registerAdult("est", "female");
    const reveal = await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${token}`)
      .send({ estimatedPushups: 18 }) // auto-évaluation → Index estimé
      .expect(201);
    expect(reveal.body.index.isEstimated).toBe(true);

    const events = await joinEvents(userId);
    expect(events.length).toBe(0); // rien tant que l'Index est estimé
  });

  it("T2 : Index COMPLET (course chronométrée) → member_joined émis une fois, avec l'index", async () => {
    const { token, userId } = await registerAdult("real", "male");
    const reveal = await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${token}`)
      .send({ course: { distanceMeters: 5000, timeSeconds: 1440 } }) // mesuré → non estimé
      .expect(201);
    expect(reveal.body.index.isEstimated).toBe(false);

    const events = await joinEvents(userId);
    expect(events.length).toBe(1);
    const payload = events[0].payload as { index?: number };
    expect(payload.index).toBe(reveal.body.index.value); // « rejoint avec un index de Y »
  });

  it("T5 : GET /v1/me/badges/card → badges gagnés (compacts) + cosmétiques actifs", async () => {
    // Réutilise l'utilisateur « real » : il a un Index complet → au moins « first-index ».
    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email: `e2e_mj_card_${stamp}@test.local`,
        password: "motdepasse123",
        displayName: `MJcard${stamp}`,
        dateOfBirth: "1990-01-01",
        sex: "male",
      })
      .expect(201);
    ids.push(reg.body.user.id);
    const token = reg.body.token as string;

    await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${token}`)
      .send({ course: { distanceMeters: 5000, timeSeconds: 1320 } })
      .expect(201);

    const card = await request(api.getHttpServer())
      .get("/v1/me/badges/card")
      .set("authorization", `Bearer ${token}`)
      .expect(200);

    // Forme de la réponse.
    expect(Array.isArray(card.body.earned)).toBe(true);
    expect(Array.isArray(card.body.activeCosmetics)).toBe(true);
    expect(typeof card.body.total).toBe("number");
    expect(card.body.total).toBe(card.body.earned.length);

    // Tous les badges renvoyés sont RÉELLEMENT gagnés (datés).
    expect(card.body.earned.length).toBeGreaterThanOrEqual(1);
    for (const b of card.body.earned) {
      expect(typeof b.id).toBe("string");
      expect(typeof b.label).toBe("string"); // libellé affichable
      expect(typeof b.unlockedAt).toBe("string"); // ISO 8601
      expect(Number.isNaN(Date.parse(b.unlockedAt))).toBe(false);
    }
    // « first-index » présent dès qu'un Index existe.
    expect(card.body.earned.some((b: { id: string }) => b.id === "first-index")).toBe(true);

    // Tri du plus récent au plus ancien (dates décroissantes).
    const dates = card.body.earned.map((b: { unlockedAt: string }) => b.unlockedAt);
    expect(dates).toEqual([...dates].sort((a, b) => b.localeCompare(a)));

    // activeCosmetics ⊆ cosmeticUnlock des badges gagnés.
    const earnedCosmetics = new Set(
      card.body.earned.map((b: { cosmeticUnlock: string | null }) => b.cosmeticUnlock).filter(Boolean),
    );
    for (const c of card.body.activeCosmetics) {
      expect(earnedCosmetics.has(c)).toBe(true);
    }
  });
});
