import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
// Score-service réel (module compilé) démarré en mémoire pour un VRAI bout-en-bout api → score.
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

describe("api ↔ score-service — reveal RÉEL (intégration, sans mock, sans BD)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;

  beforeAll(async () => {
    // 1) Démarre le vrai score-service sur un port libre.
    const scoreRef = await Test.createTestingModule({ imports: [ScoreAppModule] }).compile();
    scoreApp = configureScoreApp(scoreRef.createNestApplication());
    await scoreApp.listen(0);
    const port = (scoreApp.getHttpServer().address() as AddressInfo).port;

    // 2) Pointe l'api dessus AVANT de compiler son module (le provider lit l'env à l'instanciation).
    process.env.SCORE_SERVICE_URL = `http://127.0.0.1:${port}`;
    const { AppModule } = await import("../src/app.module");
    const { configureApp } = await import("../src/app.config");
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();
  });

  afterAll(async () => {
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  it("course libre 5 km (24:00) → normalisée Riegel, Engine débloqué, Index provisoire", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "male", goal: "all_round", course: { distanceMeters: 5000, timeSeconds: 1440 } })
      .expect(201);
    expect(res.body.index.value).toBeGreaterThanOrEqual(80); // OVR /100
    expect(res.body.index.value).toBeLessThanOrEqual(100);
    expect(res.body.index.radarCoverage).toBe(1);
    expect(res.body.index.isProvisional).toBe(true);
    expect(["diamond", "elite"]).toContain(res.body.index.rank);
    const engine = res.body.radar.find((a: { attribute: string }) => a.attribute === "engine");
    expect(engine.unlocked).toBe(true);
  });

  it("course libre 3 km (15:00) saisie par l'utilisateur → Engine débloqué", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "male", goal: "all_round", course: { distanceMeters: 3000, timeSeconds: 900 } })
      .expect(201);
    expect(res.body.index.value).toBeGreaterThan(0);
    const engine = res.body.radar.find((a: { attribute: string }) => a.attribute === "engine");
    expect(engine.unlocked).toBe(true);
  });

  it("5bis pompes estimées (Femme) → Force estimée → Index étiqueté estimé", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "female", goal: "hyrox", estimatedPushups: 18 })
      .expect(201);
    expect(res.body.index.isEstimated).toBe(true);
    const strength = res.body.radar.find((a: { attribute: string }) => a.attribute === "strength");
    expect(strength.isEstimated).toBe(true);
  });

  it("propage un résultat hors bornes du score-service (422)", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/onboarding/estimate")
      .send({ sex: "male", goal: "all_round", course: { distanceMeters: 5000, timeSeconds: 60 } })
      .expect(422);
    expect(res.body.error.code).toBe("WOD_RESULT_OUT_OF_BOUNDS");
  });
});
