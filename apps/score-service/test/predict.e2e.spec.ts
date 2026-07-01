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

    it("cohérence ALLER-RETOUR : le raw prédit (DÉ-bufferisé), re-noté, redonne ~le niveau de départ", async () => {
      // userInternal = 600 (un seul attribut cible). Le raw AFFICHÉ est gonflé de +40 %
      // (BEATABILITY_BUFFER, marge de battabilité gamification) → on le RETIRE avant de re-noter
      // pour vérifier que la chaîne inverse raw↔sub-score reste exacte. run_5k = time (dir -1) ⇒
      // raw « réel » = predictedRaw / 1.4. sub-score(raw réel) ≈ 600.
      const BEATABILITY_BUFFER = 1.4;
      const pred = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "run_5k", sex: "male", attributeScores: attrs(["engine"], 600) })
        .expect(201);
      const unbuffered = Math.round(pred.body.predictedRaw / BEATABILITY_BUFFER);
      const scored = await request(app.getHttpServer())
        .post("/v1/score/sub-score")
        .send({ wodId: "run_5k", sex: "male", scoreType: "time", rawResult: unbuffered })
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

    // ─────────────────────────────────────────────────────────────────────────────────────────
    // MODÈLE « PRO » PAR MOUVEMENT (Inc. 2) — ces deux tests REMPLACENT les anciens « moyenne des
    // cibles / ignore les non-cibles », qui encodaient le BUG d'origine (la FORCE était ignorée sur
    // Fran). Désormais Fran passe par son blueprint (thruster power/ME/STRENGTH, pull-up
    // ME/STRENGTH) : la FORCE entre dans la cadence ET dans la pénalité de charge (1RM estimé).
    // ─────────────────────────────────────────────────────────────────────────────────────────
    it("la FORCE (hors targetAttributes de Fran) AMÉLIORE le temps de Fran à charge fixe", async () => {
      // Même power/ME, on fait MONTER la force : 40 kg devient relativement plus léger (1RM ↑) et
      // la cadence des mouvements qui pondèrent la force monte → temps PLUS BAS. Avec l'ancien
      // modèle (moyenne des seules cibles {ME, power}), la force n'avait AUCUN effet : régression
      // intentionnelle.
      const base = ["muscular_endurance", "power"];
      const weakStrength = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "fran", sex: "male", attributeScores: [...attrs(base, 700), { attribute: "strength", score: 350, unlocked: true }] })
        .expect(201);
      const strongStrength = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "fran", sex: "male", attributeScores: [...attrs(base, 700), { attribute: "strength", score: 900, unlocked: true }] })
        .expect(201);
      expect(typeof weakStrength.body.predictedRaw).toBe("number");
      expect(strongStrength.body.predictedRaw).toBeLessThan(weakStrength.body.predictedRaw);
    });

    // ── INC. 3 — FOURCHETTE { low, mid, high } + confiance ─────────────────────────────────────
    it("renvoie une FOURCHETTE cohérente (low ≤ mid ≤ high) + confiance sur un blueprint (Fran)", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({
          wodId: "fran",
          sex: "male",
          attributeScores: [...attrs(["muscular_endurance", "power"], 700), { attribute: "strength", score: 700, unlocked: true }],
        })
        .expect(201);
      expect(typeof res.body.predictedRaw).toBe("number");
      expect(typeof res.body.predictedLow).toBe("number");
      expect(typeof res.body.predictedHigh).toBe("number");
      expect(["low", "medium", "high"]).toContain(res.body.confidence);
      // low ≤ mid ≤ high, bornes entières.
      expect(res.body.predictedLow).toBeLessThanOrEqual(res.body.predictedRaw);
      expect(res.body.predictedRaw).toBeLessThanOrEqual(res.body.predictedHigh);
      expect(Number.isInteger(res.body.predictedLow)).toBe(true);
      expect(Number.isInteger(res.body.predictedHigh)).toBe(true);
      // Fourchette NON dégénérée (le mid n'est pas collé aux deux bornes en confiance moyenne/basse).
      expect(res.body.predictedHigh).toBeGreaterThan(res.body.predictedLow);
    });

    it("repli population (course pure : pas de fourchette) ⇒ predictedRaw seul, fields optionnels absents", async () => {
      const res = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({ wodId: "run_5k", sex: "male", attributeScores: attrs(["engine"], 600) })
        .expect(201);
      expect(typeof res.body.predictedRaw).toBe("number");
      // Le repli population ne fournit qu'un point : pas de fourchette (mobile retombe sur le point).
      expect(res.body.predictedLow ?? null).toBeNull();
      expect(res.body.predictedHigh ?? null).toBeNull();
      expect(res.body.confidence ?? null).toBeNull();
    });

    it("un attribut VERROUILLÉ ne contribue pas (Fran ralentit si la force est verrouillée)", async () => {
      // Force présente mais VERROUILLÉE ⇒ traitée comme indisponible (capacité renormalisée sur les
      // attributs débloqués + 1RM dérivé d'une force à 0). Résultat : temps STRICTEMENT plus lent
      // que si la même force était débloquée. Confirme que seul l'`unlocked` compte (par mouvement).
      const strengthLocked = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({
          wodId: "fran",
          sex: "male",
          attributeScores: [...attrs(["muscular_endurance", "power"], 700), { attribute: "strength", score: 800, unlocked: false }],
        })
        .expect(201);
      const strengthUnlocked = await request(app.getHttpServer())
        .post("/v1/score/predict")
        .send({
          wodId: "fran",
          sex: "male",
          attributeScores: [...attrs(["muscular_endurance", "power"], 700), { attribute: "strength", score: 800, unlocked: true }],
        })
        .expect(201);
      expect(strengthLocked.body.predictedRaw).toBeGreaterThan(strengthUnlocked.body.predictedRaw);
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
