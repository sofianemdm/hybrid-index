import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";
import { ScoreClient } from "../src/infra/score-client/score-client.service";

/**
 * ScoreClient mocké : on teste l'ORCHESTRATION onboarding (mapping entrées → efforts, reveal),
 * pas le calcul (couvert par scoring-core + score-service). Le mock enregistre la requête reçue
 * et renvoie un profil dont l'estimation reflète la présence d'un effort proxy (pompes).
 */
const lastRequest: { value?: unknown } = {};
const scoreClientStub = {
  computeProfile: async (req: { efforts: Array<{ wodId: string }> }) => {
    lastRequest.value = req;
    const hasPushups = req.efforts.some((e) => e.wodId === "max_pushups");
    return {
      index: {
        value: 884,
        percentile: 0.96,
        isProvisional: true,
        isEstimated: hasPushups,
        radarCoverage: hasPushups ? 2 : 1,
        scoringVersionId: "scoring-v1",
      },
      radar: [{ attribute: "engine", score: 884, unlocked: true, isEstimated: false, isStale: false }],
    };
  },
};

describe("api — onboarding/estimate (e2e)", () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(ScoreClient)
      .useValue(scoreClientStub)
      .compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it("révèle un Index provisoire + rang à partir d'un temps de course", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "male", goal: "all_round", course: { distanceMeters: 5000, timeSeconds: 1440 } })
      .expect(201);
    expect(res.body.index.value).toBe(884);
    expect(res.body.index.rank).toBe("diamond"); // 884 ∈ [750,900)
    expect(res.body.index.isProvisional).toBe(true);
    expect(res.body.index.isEstimated).toBe(false); // course seule = non estimé
    expect(res.body.radar[0].attribute).toBe("engine");
  });

  it("5bis : pompes estimées → effort max_pushups mappé + Index ÉTIQUETÉ estimé", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "female", goal: "hyrox", estimatedPushups: 15 })
      .expect(201);
    // L'effort proxy est bien transmis au score-service…
    expect(lastRequest.value).toMatchObject({
      sex: "female",
      goal: "hyrox",
      efforts: [{ wodId: "max_pushups", rawResult: 15 }],
    });
    // …et l'Index est clairement étiqueté ESTIMÉ (cahier §8/5bis).
    expect(res.body.index.isEstimated).toBe(true);
  });

  it("course + pompes combinées → deux efforts transmis", async () => {
    await request(app.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "male", goal: "all_round", course: { distanceMeters: 1000, timeSeconds: 240 }, estimatedPushups: 30 })
      .expect(201);
    expect(lastRequest.value).toMatchObject({
      efforts: [
        { wodId: "run_free_distance", rawResult: 240, distanceMeters: 1000 },
        { wodId: "max_pushups", rawResult: 30 },
      ],
    });
  });

  it("rejette une demande sans aucune entrée (400)", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "male", goal: "all_round" })
      .expect(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("rejette une entrée mal formée (400)", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "martian", goal: "all_round", course: { distanceMeters: 5000, timeSeconds: 1440 } })
      .expect(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});
