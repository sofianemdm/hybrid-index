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
    it("calcule le sous-score d'un WOD de référence (5 km H, 24:00 → ~692 après recalibrage)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "run_5k", sex: "male", scoreType: "time", rawResult: 1440 })
        .expect(201);
      expect(res.body.subScore).toBeGreaterThanOrEqual(686);
      expect(res.body.subScore).toBeLessThanOrEqual(698);
      expect(res.body.attributesAffected).toContain("engine");
      expect(res.body.scoringVersionId).toBe("scoring-v1");
    });

    it("rejette un résultat hors bornes physiologiques (422)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "run_5k", sex: "male", scoreType: "time", rawResult: 60 })
        .expect(422);
      expect(res.body.error.code).toBe("WOD_RESULT_OUT_OF_BOUNDS");
      expect(res.body.error.details).toEqual({ field: "rawResult", min: 810, max: 3600 });
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

    it("note les tractions strictes (reps, plus = mieux) de façon monotone et cible force + endurance", async () => {
      const low = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "max_strict_pullups", sex: "male", scoreType: "reps", rawResult: 3 })
        .expect(201);
      const high = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "max_strict_pullups", sex: "male", scoreType: "reps", rawResult: 25 })
        .expect(201);
      expect(high.body.subScore).toBeGreaterThan(low.body.subScore);
      expect(high.body.attributesAffected).toEqual(expect.arrayContaining(["strength", "muscular_endurance"]));
    });

    it("note le squat 1RM (charge kg, scoreType load) de façon monotone et cible la force", async () => {
      const low = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "squat_1rm", sex: "female", scoreType: "load", rawResult: 40 })
        .expect(201);
      const high = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "squat_1rm", sex: "female", scoreType: "load", rawResult: 140 })
        .expect(201);
      expect(high.body.subScore).toBeGreaterThan(low.body.subScore);
      expect(high.body.attributesAffected).toContain("strength");
    });

    it("rejette un squat 1RM hors bornes (422)", async () => {
      await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "squat_1rm", sex: "male", scoreType: "load", rawResult: 500 })
        .expect(422);
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
    it("worked example A : Homme 'Partout', 3 efforts → ~450 (OR) après recalibrage des WODs", async () => {
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
      expect(res.body.index.value).toBeGreaterThanOrEqual(445);
      expect(res.body.index.value).toBeLessThanOrEqual(455);
      expect(res.body.index.radarCoverage).toBe(4);
      expect(res.body.index.isProvisional).toBe(false);
      const strength = res.body.radar.find((a: { attribute: string }) => a.attribute === "strength");
      expect(strength.isEstimated).toBe(false); // Grace (test chargé) fait autorité sur le proxy
    });
  });

  describe("POST /v1/score/project (Index projeté)", () => {
    it("projeté >= actuel et plafonné à 1000", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/project")
        .send({
          goal: "all_round",
          targetAttribute: "power",
          attributeScores: [
            { attribute: "engine", score: 800, unlocked: true, isEstimated: false },
            { attribute: "speed", score: 0, unlocked: false, isEstimated: false },
            { attribute: "strength", score: 600, unlocked: true, isEstimated: false },
            { attribute: "power", score: 400, unlocked: true, isEstimated: false },
            { attribute: "muscular_endurance", score: 500, unlocked: true, isEstimated: false },
            { attribute: "hybrid", score: 0, unlocked: false, isEstimated: false },
          ],
        })
        .expect(201);
      expect(res.body.projected).toBeGreaterThanOrEqual(res.body.current);
      expect(res.body.projected).toBeLessThanOrEqual(1000);
      expect(res.body.delta).toBeGreaterThanOrEqual(0);
      expect(res.body.targetScore).toBeGreaterThanOrEqual(600); // au moins au niveau du meilleur attribut
    });
  });

  describe("POST /v1/score/estimate (moteur d'estimation WOD custom)", () => {
    it("Fran décomposé → palier intermédiaire ≈ médiane connue (345 s) à ±8 %", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/estimate")
        .send({
          sex: "male",
          scoreType: "time",
          wodType: "for_time",
          blocks: [
            { movementId: "thruster", reps: 45, loadKg: 43 },
            { movementId: "pull_up", reps: 45 },
          ],
          userResult: 300,
        })
        .expect(201);
      const inter = res.body.references.find((r: { level: string }) => r.level === "intermediate").rawResult;
      expect(inter).toBeGreaterThanOrEqual(317); // 345 - 8%
      expect(inter).toBeLessThanOrEqual(373); // 345 + 8%
      // paliers strictement ordonnés (temps : champion < inter < occasionnel)
      const champ = res.body.references.find((r: { level: string }) => r.level === "champion").rawResult;
      const occ = res.body.references.find((r: { level: string }) => r.level === "occasional").rawResult;
      expect(champ).toBeLessThan(inter);
      expect(inter).toBeLessThan(occ);
      expect(res.body.subScore).toBeGreaterThan(0);
      expect(res.body.confidence).toBe("estimated");
      expect(res.body.attributesAffected).toContain("power");
    });

    it("AMRAP (reps) → barème croissant + pas de note sans userResult", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/estimate")
        .send({
          sex: "male",
          scoreType: "reps",
          wodType: "amrap",
          timeCapSec: 720,
          blocks: [
            { movementId: "pull_up", reps: 5 },
            { movementId: "push_up", reps: 10 },
            { movementId: "air_squat", reps: 15 },
          ],
        })
        .expect(201);
      const champ = res.body.references.find((r: { level: string }) => r.level === "champion").rawResult;
      const occ = res.body.references.find((r: { level: string }) => r.level === "occasional").rawResult;
      expect(champ).toBeGreaterThan(occ); // reps : champion > occasionnel
      expect(res.body.subScore).toBeNull();
    });

    it("mouvement inconnu → 400", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/estimate")
        .send({ sex: "male", scoreType: "time", wodType: "for_time", blocks: [{ movementId: "licorne", reps: 10 }] })
        .expect(400);
      expect(res.body.error.code).toBe("VALIDATION_ERROR");
    });
  });

  describe("GET /v1/score/movements", () => {
    it("renvoie le catalogue de mouvements", async () => {
      const res = await request(app.getHttpServer()).get("/v1/score/movements").expect(200);
      expect(res.body.length).toBeGreaterThanOrEqual(30);
      expect(res.body[0]).toHaveProperty("id");
      expect(res.body[0]).not.toHaveProperty("rate"); // pas de paramètres internes exposés
    });
  });
});
