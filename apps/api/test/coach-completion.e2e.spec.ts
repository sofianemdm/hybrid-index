import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

/**
 * P0 PERSISTANCE — « Marquer comme faite » d'une séance GUIDÉE (POST /v1/coach/sessions/:id/complete).
 * Vérifie que la complétion :
 *  (a) est PERSISTÉE (CoachSessionCompletion) ;
 *  (b) crédite la SÉRIE (compte comme activité de la semaine) ;
 *  (c) NE crée AUCUN wodResult et NE modifie PAS l'Athlete Index (CoachSession = pas de barème) ;
 *  (d) est idempotente par jour (2e appel le même jour → recorded:false, série recomptée) ;
 *  (e) 404 si la séance n'existe pas.
 * Nécessite Postgres + le vrai score-service (en mémoire, pour /v1/onboarding/complete).
 */
describe("api — complétion de séance guidée + crédit de série (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;

  const stamp = Date.now();
  const email = `e2e_coachdone_${stamp}@test.local`;
  let token = "";
  let userId = "";

  beforeAll(async () => {
    const scoreRef = await Test.createTestingModule({ imports: [ScoreAppModule] }).compile();
    scoreApp = configureScoreApp(scoreRef.createNestApplication());
    await scoreApp.listen(0);
    process.env.SCORE_SERVICE_URL = `http://127.0.0.1:${(scoreApp.getHttpServer().address() as AddressInfo).port}`;

    const { AppModule } = await import("../src/app.module");
    const { configureApp } = await import("../src/app.config");
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();
    prisma = new PrismaClient();

    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({ email, password: "motdepasse123", displayName: `CoachDone${stamp}`, dateOfBirth: "1994-04-04", sex: "male", goal: "all_round", equipmentPref: "both" })
      .expect(201);
    token = reg.body.token;
    userId = reg.body.user.id;
    // Onboarding → un Athlete Index existe (référence pour vérifier la non-altération).
    await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${token}`)
      .send({ course: { distanceMeters: 5000, timeSeconds: 1440 }, estimatedPushups: 30 })
      .expect(201);
    // Objectif hebdo bas (2) → on valide la semaine avec 2 séances guidées.
    await request(api.getHttpServer())
      .patch("/v1/me/streak")
      .set("authorization", `Bearer ${token}`)
      .send({ weeklyGoal: 2 })
      .expect(200);
  });

  afterAll(async () => {
    if (userId) {
      await prisma.coachSessionCompletion.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.hybridIndexHistory.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.progressWeekly.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  // Baseline d'activité de la semaine (les WODs d'onboarding peuvent déjà compter selon le jour).
  let weekBaseline = 0;

  it("complete : persiste la complétion, crédite la série, sans toucher l'Index", async () => {
    // État de référence : Index + nombre de wodResults + activité de la semaine AVANT.
    const indexBefore = await prisma.hybridIndex.findUnique({ where: { userId } });
    expect(indexBefore).not.toBeNull();
    const wodResultsBefore = await prisma.wodResult.count({ where: { userId } });
    const streakBefore = await request(api.getHttpServer())
      .get("/v1/me/streak")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    weekBaseline = streakBefore.body.thisWeekCount as number;

    // 1re séance guidée faite → +1 activité de la semaine.
    const res1 = await request(api.getHttpServer())
      .post("/v1/coach/sessions/engine-zone2-run-40/complete")
      .set("authorization", `Bearer ${token}`)
      .expect(201);
    expect(res1.body.recorded).toBe(true);
    expect(res1.body.sessionId).toBe("engine-zone2-run-40");
    expect(typeof res1.body.completedAt).toBe("string");
    expect(res1.body.streakCredited).toBe(true);
    expect(res1.body.streak.thisWeekCount).toBe(weekBaseline + 1);

    // Persistance vérifiée en base.
    const stored = await prisma.coachSessionCompletion.findMany({ where: { userId } });
    expect(stored.length).toBe(1);
    expect(stored[0].sessionId).toBe("engine-zone2-run-40");

    // 2e séance guidée (autre id) le même jour → +1 activité.
    const res2 = await request(api.getHttpServer())
      .post("/v1/coach/sessions/strength-pushup-progression/complete")
      .set("authorization", `Bearer ${token}`)
      .expect(201);
    expect(res2.body.recorded).toBe(true);
    expect(res2.body.streak.thisWeekCount).toBe(weekBaseline + 2);
    // Avec 2 séances guidées, l'objectif hebdo (2) est atteint → semaine validée.
    expect(res2.body.streak.weekValidated).toBe(true);

    // Recoupement via l'endpoint série public.
    const streakRes = await request(api.getHttpServer())
      .get("/v1/me/streak")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(streakRes.body.thisWeekCount).toBe(weekBaseline + 2);
    expect(streakRes.body.weekValidated).toBe(true);

    // L'INDEX N'A PAS BOUGÉ et AUCUN wodResult n'a été créé (CoachSession = pas de barème).
    const indexAfter = await prisma.hybridIndex.findUnique({ where: { userId } });
    expect(indexAfter!.value).toBe(indexBefore!.value);
    expect(indexAfter!.percentile.toString()).toBe(indexBefore!.percentile.toString());
    expect(await prisma.wodResult.count({ where: { userId } })).toBe(wodResultsBefore);
  });

  it("complete : idempotent par jour (2e appel même séance/jour → recorded:false, série inchangée)", async () => {
    const again = await request(api.getHttpServer())
      .post("/v1/coach/sessions/engine-zone2-run-40/complete")
      .set("authorization", `Bearer ${token}`)
      .expect(201);
    expect(again.body.recorded).toBe(false);
    expect(again.body.streakCredited).toBe(true);
    // Pas de double comptage : on reste à baseline + 2 (les 2 séances DISTINCTES du test précédent).
    expect(again.body.streak.thisWeekCount).toBe(weekBaseline + 2);
    // Une seule ligne pour cette séance ce jour-là.
    const stored = await prisma.coachSessionCompletion.findMany({
      where: { userId, sessionId: "engine-zone2-run-40" },
    });
    expect(stored.length).toBe(1);
  });

  it("complete : séance inconnue → 404 NOT_FOUND", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/coach/sessions/seance-bidon-inexistante/complete")
      .set("authorization", `Bearer ${token}`)
      .expect(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
  });
});
