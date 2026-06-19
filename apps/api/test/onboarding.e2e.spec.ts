import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";
import { ScoreClient } from "../src/infra/score-client/score-client.service";

/** ScoreClient mocké : on teste l'orchestration onboarding, pas le calcul (déjà couvert ailleurs). */
const scoreClientStub = {
  computeProfile: async () => ({
    index: { value: 884, percentile: 0.96, isProvisional: true, isEstimated: false, radarCoverage: 1, scoringVersionId: "scoring-v1" },
    radar: [{ attribute: "engine", score: 884, unlocked: true, isEstimated: false, isStale: false }],
  }),
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
      .send({ sex: "male", goal: "all_round", course: { wodId: "run_5k", timeSeconds: 1440 } })
      .expect(201);
    expect(res.body.index.value).toBe(884);
    expect(res.body.index.rank).toBe("diamond"); // 884 ∈ [750,900)
    expect(res.body.index.isProvisional).toBe(true);
    expect(res.body.radar[0].attribute).toBe("engine");
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
      .send({ sex: "martian", goal: "all_round", course: { wodId: "run_5k", timeSeconds: 1440 } })
      .expect(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});
