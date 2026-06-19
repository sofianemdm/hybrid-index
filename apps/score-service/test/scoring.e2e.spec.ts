import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

describe("score-service — calcul (e2e)", () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe("POST /v1/score/sub-score", () => {
    it("calcule le sous-score d'un WOD de référence (5 km H, 24:00 → ~884)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "run_5k", sex: "male", scoreType: "time", rawResult: 1440 })
        .expect(201);
      expect(res.body.subScore).toBeGreaterThanOrEqual(880);
      expect(res.body.subScore).toBeLessThanOrEqual(888);
      expect(res.body.attributesAffected).toContain("engine");
      expect(res.body.scoringVersionId).toBe("scoring-v1");
    });

    it("rejette un résultat hors bornes physiologiques (422)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "run_5k", sex: "male", scoreType: "time", rawResult: 60 })
        .expect(422);
      expect(res.body.error.code).toBe("WOD_RESULT_OUT_OF_BOUNDS");
      expect(res.body.error.details).toEqual({ field: "rawResult", min: 810, max: 4200 });
    });

    it("rejette un résultat au-dessus de la borne haute (422)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "max_pushups", sex: "male", scoreType: "reps", rawResult: 999 })
        .expect(422);
      expect(res.body.error.code).toBe("WOD_RESULT_OUT_OF_BOUNDS");
    });

    it("rejette un scoreType incompatible avec le WOD (400)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "run_5k", sex: "male", scoreType: "reps", rawResult: 1440 })
        .expect(400);
      expect(res.body.error.code).toBe("VALIDATION_ERROR");
    });

    it("rejette un WOD inconnu (404)", async () => {
      await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "inconnu", sex: "male", scoreType: "time", rawResult: 1440 })
        .expect(404);
    });

    it("rejette une entrée invalide (400)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "run_5k", sex: "martian", scoreType: "time", rawResult: 1440 })
        .expect(400);
      expect(res.body.error.code).toBe("VALIDATION_ERROR");
    });
  });

  describe("POST /v1/score/index", () => {
    it("agrège l'Index (worked example B, HYROX → ~775)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/index")
        .send({
          sex: "female",
          goal: "hyrox",
          attributeScores: [
            { attribute: "engine", score: 825, isEstimated: false },
            { attribute: "strength", score: 871, isEstimated: true },
            { attribute: "muscular_endurance", score: 871, isEstimated: false },
            { attribute: "hybrid", score: 597, isEstimated: false },
          ],
        })
        .expect(201);
      expect(res.body.value).toBe(775);
      expect(res.body.isEstimated).toBe(true);
      expect(res.body.radarCoverage).toBe(4);
      expect(res.body.isProvisional).toBe(false);
      expect(res.body.scoringVersionId).toBe("scoring-v1");
    });

    it("Index provisoire quand aucun attribut n'est débloqué (value 0)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/index")
        .send({ sex: "male", goal: "all_round", attributeScores: [] })
        .expect(201);
      expect(res.body.value).toBe(0);
      expect(res.body.isProvisional).toBe(true);
      expect(res.body.radarCoverage).toBe(0);
    });
  });

  describe("POST /v1/score/profile (efforts bruts → radar + Index)", () => {
    it("worked example A : Homme 'Partout', 3 efforts → ~498 (OR), Force réelle non estimée", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/profile")
        .send({
          sex: "male",
          goal: "all_round",
          efforts: [
            { wodId: "grace", rawResult: 270 },
            { wodId: "run_5k", rawResult: 1440 },
            { wodId: "max_pushups", rawResult: 40 },
          ],
        })
        .expect(201);
      expect(res.body.index.value).toBeGreaterThanOrEqual(496);
      expect(res.body.index.value).toBeLessThanOrEqual(500);
      expect(res.body.index.radarCoverage).toBe(4);
      expect(res.body.index.isProvisional).toBe(false);
      const strength = res.body.radar.find((a: { attribute: string }) => a.attribute === "strength");
      expect(strength.isEstimated).toBe(false); // Grace (test chargé) fait autorité sur le proxy
    });
  });
});
