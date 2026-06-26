import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

/**
 * POST /v1/score/predict — prédiction inverse « d'après ton niveau, tu ferais ~X ».
 * On vérifie : (1) cohérence aller-retour predict → sub-score (le raw prédit, re-noté, redonne le
 * niveau de départ), (2) monotonie (meilleur niveau ⇒ meilleur temps), (3) les cas null
 * (aucun attribut cible débloqué, WOD inconnu, course distance libre), (4) le clamp aux bornes.
 */
describe("score-service — prédiction inverse (e2e)", () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  /** Construit un jeu d'attributs où tous les attributs cibles d'un WOD valent `score` (débloqués). */
  const attrs = (list: string[], score: number, unlocked = true) =>
    list.map((attribute) => ({ attribute, score, unlocked }));

  describe("POST /v1/score/predict", () => {
    it("prédit un temps sur run_5k (engine) à partir du niveau de l'utilisateur", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "run_5k", sex: "male", attributeScores: attrs(["engine"], 600) })
        .expect(201);
      expect(res.body.scoreType).toBe("time");
      expect(typeof res.body.predictedRaw).toBe("number");
      expect(Number.isInteger(res.body.predictedRaw)).toBe(true);
      // Dans les bornes physiologiques du 5 km H [810, 3600] s.
      expect(res.body.predictedRaw).toBeGreaterThanOrEqual(810);
      expect(res.body.predictedRaw).toBeLessThanOrEqual(3600);
    });

    it("cohérence ALLER-RETOUR : le raw prédit, re-noté, redonne ~le niveau de départ", async () => {
      // userInternal = 600 (un seul attribut cible). predict → raw ; sub-score(raw) ≈ 600.
      const pred = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "run_5k", sex: "male", attributeScores: attrs(["engine"], 600) })
        .expect(201);
      const scored = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "run_5k", sex: "male", scoreType: "time", rawResult: pred.body.predictedRaw })
        .expect(201);
      // ±6 : l'arrondi entier du temps prédit + la précision de l'inverse normale.
      expect(scored.body.subScore).toBeGreaterThanOrEqual(594);
      expect(scored.body.subScore).toBeLessThanOrEqual(606);
    });

    it("monotonie : un meilleur niveau prédit un MEILLEUR temps (plus bas)", async () => {
      const strong = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "row_2k", sex: "female", attributeScores: attrs(["engine"], 800) })
        .expect(201);
      const weak = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "row_2k", sex: "female", attributeScores: attrs(["engine"], 300) })
        .expect(201);
      expect(strong.body.predictedRaw).toBeLessThan(weak.body.predictedRaw);
    });

    it("monotonie reps : un meilleur niveau prédit PLUS de reps (max_pushups)", async () => {
      const strong = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "max_pushups", sex: "male", attributeScores: attrs(["strength", "muscular_endurance"], 750) })
        .expect(201);
      const weak = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "max_pushups", sex: "male", attributeScores: attrs(["strength", "muscular_endurance"], 250) })
        .expect(201);
      expect(strong.body.scoreType).toBe("reps");
      expect(strong.body.predictedRaw).toBeGreaterThan(weak.body.predictedRaw);
    });

    it("moyenne des attributs cibles : ignore les attributs NON cibles du WOD", async () => {
      // Fran cible {muscular_endurance, power}. Un 'engine' très bas ne doit pas peser.
      const withNoise = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({
          wodId: "fran",
          sex: "male",
          attributeScores: [...attrs(["muscular_endurance", "power"], 600), { attribute: "engine", score: 50, unlocked: true }],
        })
        .expect(201);
      const clean = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "fran", sex: "male", attributeScores: attrs(["muscular_endurance", "power"], 600) })
        .expect(201);
      expect(withNoise.body.predictedRaw).toBe(clean.body.predictedRaw);
    });

    it("ne compte QUE les attributs cibles DÉBLOQUÉS", async () => {
      // power verrouillé → seul muscular_endurance (600) compte, pas la moyenne avec power(200).
      const oneLocked = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({
          wodId: "fran",
          sex: "male",
          attributeScores: [
            { attribute: "muscular_endurance", score: 600, unlocked: true },
            { attribute: "power", score: 200, unlocked: false },
          ],
        })
        .expect(201);
      const onlyUnlocked = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "fran", sex: "male", attributeScores: attrs(["muscular_endurance"], 600) })
        .expect(201);
      expect(oneLocked.body.predictedRaw).toBe(onlyUnlocked.body.predictedRaw);
    });

    it("AUCUN attribut cible débloqué ⇒ predictedRaw null", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "run_5k", sex: "male", attributeScores: attrs(["engine"], 600, false) })
        .expect(201);
      expect(res.body.predictedRaw).toBeNull();
      expect(res.body.scoreType).toBe("time");
    });

    it("attributs vides ⇒ predictedRaw null", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "grace", sex: "female", attributeScores: [] })
        .expect(201);
      expect(res.body.predictedRaw).toBeNull();
    });

    it("WOD inconnu ⇒ predictedRaw null (jamais d'erreur)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "nope_unknown", sex: "male", attributeScores: attrs(["engine"], 600) })
        .expect(201);
      expect(res.body.predictedRaw).toBeNull();
      expect(res.body.scoreType).toBe("time");
    });

    it("course à distance libre ⇒ predictedRaw null (pas de raw unique à afficher)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "run_free_distance", sex: "male", attributeScores: attrs(["engine"], 600) })
        .expect(201);
      expect(res.body.predictedRaw).toBeNull();
    });

    it("clampe dans les bornes : un niveau quasi record-du-monde reste ≥ hardMin", async () => {
      // engine au plafond → temps prédit très bas, mais jamais sous hardMin (810 s au 5 km H).
      const res = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "run_5k", sex: "male", attributeScores: attrs(["engine"], 1000) })
        .expect(201);
      expect(res.body.predictedRaw).toBeGreaterThanOrEqual(810);
    });

    it("rejette un corps invalide (sex manquant) — 400", async () => {
      await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "run_5k", attributeScores: attrs(["engine"], 600) })
        .expect(400);
    });
  });
});
