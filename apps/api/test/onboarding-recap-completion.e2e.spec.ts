import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import Redis from "ioredis";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

/**
 * Régressions (retours test 24 juin) :
 *  - le récap « Ta semaine » ne compte PAS les efforts d'onboarding (clé `onboarding:*`) ;
 *  - « Profil Express » est conseillé EN PREMIER au nouvel arrivant (radar largement incomplet).
 * Nécessite Postgres + Redis up et la base migrée/seedée (catalogue WOD).
 */
describe("api — récap sans onboarding + Profil Express en 1er (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;
  let redis: Redis;

  const stamp = Date.now();
  const email = `e2e_orc_${stamp}@test.local`;
  let token = "";
  let userId = "";

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

    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({ email, password: "motdepasse123", displayName: `Orc${stamp}`, dateOfBirth: "1995-05-10", sex: "male", goal: "hyrox" })
      .expect(201);
    token = reg.body.token;
    userId = reg.body.user.id;

    // Onboarding : course (engine) + pompes (endurance) → quelques attributs RÉELS, mais radar
    // encore largement incomplet (≥ 3 qualités non mesurées).
    await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${token}`)
      .send({ course: { distanceMeters: 5000, timeSeconds: 1500 }, estimatedPushups: 25 })
      .expect(201);
  });

  afterAll(async () => {
    if (userId) {
      await prisma.hybridIndexHistory.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.progressWeekly.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
      await redis.zrem("leaderboard:male", userId).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    redis.disconnect();
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  it("récap hebdo : 0 séance (les efforts d'onboarding ne comptent pas)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/weekly-recap")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    // Les résultats d'onboarding (clé `onboarding:*`, performedAt = now) sont exclus du comptage.
    expect(res.body.sessions).toBe(0);
  });

  it("plan de complétion : Profil Express conseillé EN PREMIER au nouvel arrivant", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/wods/completion-plan")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.sessions.length).toBeGreaterThan(0);
    expect(res.body.sessions[0].wodId).toBe("profil_express");
  });

  it("après une VRAIE séance, le récap compte bien 1 séance", async () => {
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "fran", scoreType: "time", rawResult: 300 })
      .expect(201);
    const res = await request(api.getHttpServer())
      .get("/v1/me/weekly-recap")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.sessions).toBe(1);
  });
});
