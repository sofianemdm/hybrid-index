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
 * Boucle complète persistée (RÉELLE) : register → age-gate → onboarding/complete → log WOD →
 * classement → rival, contre la vraie base + Redis + le vrai score-service en mémoire.
 * Nécessite Docker (Postgres + Redis) up et la base migrée/seedée.
 */
describe("api — boucle complète persistée (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;
  let redis: Redis;

  const stamp = Date.now();
  const email = `e2e_loop_${stamp}@test.local`;
  const displayName = `E2ELoop${stamp}`;
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
  });

  afterAll(async () => {
    // Nettoyage : Postgres (cascade) + entrée Redis orpheline.
    if (userId) {
      await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
      await redis.zrem("leaderboard:male", userId).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    redis.disconnect();
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  it("refuse l'inscription d'un mineur (< 13 ans) → 403 AGE_RESTRICTED", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email: `kid_${stamp}@test.local`,
        password: "motdepasse123",
        displayName: `Kid${stamp}`,
        dateOfBirth: "2015-01-01",
        sex: "male",
        goal: "hyrox",
      })
      .expect(403);
    expect(res.body.error.code).toBe("AGE_RESTRICTED");
  });

  it("inscrit un adulte → token + user", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email,
        password: "motdepasse123",
        displayName,
        dateOfBirth: "1995-05-10",
        sex: "male",
        goal: "hyrox",
        equipmentPref: "both",
      })
      .expect(201);
    expect(res.body.token).toBeTruthy();
    expect(res.body.user.displayName).toBe(displayName);
    token = res.body.token;
    userId = res.body.user.id;
  });

  it("onboarding/complete persiste l'Index révélé", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${token}`)
      .send({ course: { distanceMeters: 5000, timeSeconds: 1440 }, estimatedPushups: 30 })
      .expect(201);
    expect(res.body.index.value).toBeGreaterThan(0);
    const engine = res.body.radar.find((a: { attribute: string }) => a.attribute === "engine");
    expect(engine.unlocked).toBe(true);

    // Persistance vérifiée via GET /v1/me/profile.
    const me = await request(api.getHttpServer())
      .get("/v1/me/profile")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(me.body.index.value).toBe(res.body.index.value);
  });

  it("log d'un WOD → recalcul, nouvel attribut débloqué (no-drop)", async () => {
    const before = await request(api.getHttpServer())
      .get("/v1/me/profile")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    const coverageBefore = before.body.index.radarCoverage as number;

    const res = await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "fran", scoreType: "time", rawResult: 300 })
      .expect(201);
    expect(res.body.result.subScore).toBeGreaterThan(0);
    expect(res.body.profile.index.radarCoverage).toBeGreaterThanOrEqual(coverageBefore);
    const power = res.body.profile.radar.find((a: { attribute: string }) => a.attribute === "power");
    expect(power.unlocked).toBe(true);
  });

  it("rejette un résultat hors bornes (422)", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "fran", scoreType: "time", rawResult: 5 })
      .expect(422);
    expect(res.body.error.code).toBe("WOD_RESULT_OUT_OF_BOUNDS");
  });

  it("log idempotent : même idempotencyKey → pas de double comptage", async () => {
    const payload = { wodId: "row_2k", scoreType: "time", rawResult: 440, idempotencyKey: `e2e_${stamp}_row` };
    await request(api.getHttpServer()).post("/v1/results").set("authorization", `Bearer ${token}`).send(payload).expect(201);
    await request(api.getHttpServer()).post("/v1/results").set("authorization", `Bearer ${token}`).send(payload).expect(201);
    const rows = (await prisma.wodResult.findMany({ where: { userId, idempotencyKey: payload.idempotencyKey } }));
    expect(rows.length).toBe(1);
  });

  it("classement Hommes inclut l'utilisateur et le surligne", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/leaderboard?sex=male&limit=100")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.total).toBeGreaterThan(0);
    expect(res.body.me).not.toBeNull();
    const mine = res.body.entries.find((e: { isMe: boolean }) => e.isMe);
    expect(mine).toBeTruthy();
  });

  it("rival : structure cohérente (leader ou athlète au-dessus)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/rival")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(["leader", "active", "none"]).toContain(res.body.state);
    if (res.body.state === "active") {
      expect(res.body.rival.userId).not.toBe(userId);
      expect(res.body.gap).toBeGreaterThanOrEqual(0);
    }
  });

  it("coach : Index projeté >= actuel + séances ciblées", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/coach?attribute=power")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.targetAttribute).toBe("power");
    expect(res.body.projection.projected).toBeGreaterThanOrEqual(res.body.projection.current);
    expect(res.body.sessions.length).toBeGreaterThan(0);
    expect(res.body.sessions[0].primaryAttribute).toBe("power");
  });

  it("profil public : radar + Index visibles (tout est public)", async () => {
    const res = await request(api.getHttpServer())
      .get(`/v1/profiles/${userId}`)
      .expect(200);
    expect(res.body.displayName).toBe(displayName);
    expect(res.body.index.value).toBeGreaterThan(0);
    expect(res.body.radar.length).toBe(6);
  });

  it("streak : structure + progression de la semaine", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/streak")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.weeklyGoal).toBe(3);
    expect(res.body.thisWeekCount).toBeGreaterThanOrEqual(1);
    expect(typeof res.body.current).toBe("number");
  });

  it("badges : au moins un débloqué (rang/index élevé)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/badges")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(17);
    expect(res.body.some((b: { unlocked: boolean }) => b.unlocked)).toBe(true);
  });

  it("notifications : lecture + mise à jour du dailyCap", async () => {
    await request(api.getHttpServer())
      .get("/v1/me/notifications")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    const res = await request(api.getHttpServer())
      .patch("/v1/me/notifications")
      .set("authorization", `Bearer ${token}`)
      .send({ dailyCap: 1 })
      .expect(200);
    expect(res.body.dailyCap).toBe(1);
  });

  it("RGPD : export contient profil + résultats, sans hash de mot de passe", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/export")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.profile.displayName).toBe(displayName);
    expect(Array.isArray(res.body.wodResults)).toBe(true);
    expect(res.body.passwordHash).toBeUndefined();
  });

  it("RGPD : suppression de compte (effacement) — DOIT être le dernier test", async () => {
    const res = await request(api.getHttpServer())
      .delete("/v1/me")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.deleted).toBe(true);
    userId = ""; // déjà supprimé : évite le double-nettoyage afterAll
  });
});
