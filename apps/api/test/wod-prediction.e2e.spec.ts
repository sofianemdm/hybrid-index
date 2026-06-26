import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

/**
 * GET /v1/wods/:id/prediction — « d'après ton niveau, tu ferais ~X ».
 * e2e RÉEL (api → score-service réel, vraie BD). On vérifie : prédiction présente (number) pour un
 * user dont l'attribut cible est débloqué ; null si rien d'unlocked ; 404 sur WOD inconnu.
 */
const SCORING_VERSION_UUID = "11111111-1111-1111-1111-111111111111";

describe("api — prédiction de résultat sur un WOD (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();
  const email = `e2e_predict_${stamp}@test.local`;
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
      .send({ email, password: "motdepasse123", displayName: `Predict${stamp}`, dateOfBirth: "1995-05-10", sex: "male", goal: "all_round" })
      .expect(201);
    token = reg.body.token;
    userId = reg.body.user.id;
  });

  afterAll(async () => {
    if (userId) await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  /** Pose/maj un score d'attribut pour l'utilisateur courant. */
  const setAttr = (attribute: string, score: number, unlocked: boolean) =>
    prisma.attributeScore.upsert({
      where: { userId_attribute: { userId, attribute: attribute as never } },
      create: {
        userId,
        attribute: attribute as never,
        score,
        percentile: 0.5,
        unlocked,
        isEstimated: false,
        isStale: false,
        scoringVersionId: SCORING_VERSION_UUID,
      },
      update: { score, unlocked },
    });

  it("attribut cible DÉBLOQUÉ → predictedRaw number (temps) sur run_5k", async () => {
    // run_5k cible `engine`. On débloque engine à un bon niveau (/1000).
    await setAttr("engine", 650, true);

    const res = await request(api.getHttpServer())
      .get("/v1/wods/run_5k/prediction")
      .set("authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.scoreType).toBe("time");
    expect(typeof res.body.predictedRaw).toBe("number");
    expect(Number.isInteger(res.body.predictedRaw)).toBe(true);
    // Dans les bornes physiologiques du 5 km H [810, 3600] s.
    expect(res.body.predictedRaw).toBeGreaterThanOrEqual(810);
    expect(res.body.predictedRaw).toBeLessThanOrEqual(3600);
  });

  it("aucun attribut cible débloqué → predictedRaw null", async () => {
    // engine VERROUILLÉ → run_5k n'a aucun attribut cible débloqué.
    await setAttr("engine", 650, false);

    const res = await request(api.getHttpServer())
      .get("/v1/wods/run_5k/prediction")
      .set("authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.predictedRaw).toBeNull();
    expect(res.body.scoreType).toBe("time");
  });

  it("WOD introuvable → 404", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/wods/wod_inexistant_xyz/prediction")
      .set("authorization", `Bearer ${token}`)
      .expect(404);
    expect(res.body.error.code).toBe("NOT_FOUND");
  });

  it("non authentifié → 401", async () => {
    await request(api.getHttpServer()).get("/v1/wods/run_5k/prediction").expect(401);
  });
});
