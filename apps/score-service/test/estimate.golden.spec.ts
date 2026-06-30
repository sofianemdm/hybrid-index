import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

/**
 * GOLDEN TESTS de l'ESTIMATION « pro » par mouvement (Inc. 2). Figent le comportement attendu du
 * moteur en mode ATHLÈTE sur des benchmarks décomposés (blueprints) pour des profils ancrés sur le
 * réel. Toute régression future du moteur (capacité par mouvement / pénalité de charge) casse ICI,
 * AVANT d'atteindre un utilisateur.
 *
 * GARDE-FOU : ces tests portent UNIQUEMENT sur l'ESTIMATION de temps (POST /v1/score/predict). Ils
 * ne touchent ni l'Index ni la notation d'un résultat réel (`bySex.model`).
 *
 * CAS PIVOT « soso » : male, strength 661 / power 737 / muscular_endurance 971 (poids de réf 80 kg),
 * Fran 40 kg. Le réel observé est 9:50 (590 s). L'ancien modèle (moyenne des SEULES cibles {ME,
 * power}) sortait ~4:40 car la FORCE (le mur réel à 40 kg) était ignorée et l'ME=971 gonflait la
 * moyenne. Le nouveau modèle doit retomber dans [540, 660] s (≈ 9–11 min).
 */
describe("score-service — golden estimation « pro » (e2e)", () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  const score = (attribute: string, s: number, unlocked = true) => ({ attribute, score: s, unlocked });

  /** Construit le jeu d'attributs complet (force, puissance, endurance musculaire, engine…). */
  const profile = (p: { strength: number; power: number; muscular_endurance: number; engine?: number; speed?: number; hybrid?: number }) => [
    score("strength", p.strength),
    score("power", p.power),
    score("muscular_endurance", p.muscular_endurance),
    score("engine", p.engine ?? p.muscular_endurance),
    score("speed", p.speed ?? p.power),
    score("hybrid", p.hybrid ?? Math.round((p.strength + p.power + p.muscular_endurance) / 3)),
  ];

  const predict = (wodId: string, sex: "male" | "female", attributeScores: ReturnType<typeof profile>) =>
    request(app.getHttpServer()).post("/v1/score/predict").send({ wodId, sex, attributeScores }).expect(201);

  // Profils ancrés (≈ /1000). Voir la table de calibration du plan (docs/plan-estimation-pro.md §B.4).
  const SOSO = { strength: 661, power: 737, muscular_endurance: 971 };
  const ELITE = { strength: 950, power: 950, muscular_endurance: 950 };
  const STRONG = { strength: 850, power: 800, muscular_endurance: 800 };
  const BEGINNER = { strength: 400, power: 450, muscular_endurance: 500 };

  describe("Fran (male, 40 kg) — cas pivot", () => {
    it("CAS soso → ~9–11 min (540–660 s), PAS « 4:40 »", async () => {
      const res = await predict("fran", "male", profile(SOSO));
      expect(res.body.scoreType).toBe("time");
      expect(res.body.predictedRaw).toBeGreaterThanOrEqual(540);
      expect(res.body.predictedRaw).toBeLessThanOrEqual(660);
      // Régression du bug d'origine : ne doit JAMAIS retomber au voisinage de l'ancien 4:40 (~280 s).
      expect(res.body.predictedRaw).toBeGreaterThan(360);
    });

    it("un athlète tout-en-haut (élite) reste RAPIDE", async () => {
      const elite = await predict("fran", "male", profile(ELITE));
      const soso = await predict("fran", "male", profile(SOSO));
      // L'élite bat largement soso et reste dans un temps de pointe (≤ 5 min).
      expect(elite.body.predictedRaw).toBeLessThan(soso.body.predictedRaw);
      expect(elite.body.predictedRaw).toBeLessThanOrEqual(300);
    });

    it("un débutant complet est LENT (proche du time cap)", async () => {
      const beginner = await predict("fran", "male", profile(BEGINNER));
      const soso = await predict("fran", "male", profile(SOSO));
      expect(beginner.body.predictedRaw).toBeGreaterThan(soso.body.predictedRaw);
      // Bien plus lent qu'un athlète régulier ; borné par le garde-fou population (hardMax Fran H = 1500).
      expect(beginner.body.predictedRaw).toBeGreaterThanOrEqual(720);
      expect(beginner.body.predictedRaw).toBeLessThanOrEqual(1500);
    });

    it("MONOTONIE par niveau : monter tout le profil améliore (baisse) le temps", async () => {
      const ladder = [BEGINNER, { strength: 600, power: 650, muscular_endurance: 700 }, STRONG, ELITE];
      const times: number[] = [];
      for (const p of ladder) {
        const r = await predict("fran", "male", profile(p));
        times.push(r.body.predictedRaw);
      }
      // strictement décroissant (meilleur profil ⇒ temps plus bas)
      for (let i = 1; i < times.length; i++) expect(times[i]).toBeLessThan(times[i - 1]);
    });

    it("la FORCE est bien un déterminant : à power/ME figés, +force ⇒ temps plus bas", async () => {
      const lowStr = await predict("fran", "male", profile({ strength: 450, power: 750, muscular_endurance: 800 }));
      const highStr = await predict("fran", "male", profile({ strength: 900, power: 750, muscular_endurance: 800 }));
      expect(highStr.body.predictedRaw).toBeLessThan(lowStr.body.predictedRaw);
    });
  });

  describe("Autres benchmarks décomposés — plausibilité + monotonie", () => {
    it("Grace (male, 30 C&J 60 kg) : élite < soso < débutant, tous bornés", async () => {
      const elite = await predict("grace", "male", profile(ELITE));
      const soso = await predict("grace", "male", profile(SOSO));
      const beginner = await predict("grace", "male", profile(BEGINNER));
      expect(elite.body.predictedRaw).toBeLessThan(soso.body.predictedRaw);
      expect(soso.body.predictedRaw).toBeLessThan(beginner.body.predictedRaw);
      // Bornes physiologiques Grace H [55, 1200] s.
      expect(elite.body.predictedRaw).toBeGreaterThanOrEqual(55);
      expect(beginner.body.predictedRaw).toBeLessThanOrEqual(1200);
    });

    it("Helen (male, 3 tours course+KB+tractions) : monotone et borné", async () => {
      const elite = await predict("helen", "male", profile(ELITE));
      const beginner = await predict("helen", "male", profile(BEGINNER));
      expect(elite.body.predictedRaw).toBeLessThan(beginner.body.predictedRaw);
      // Bornes Helen H [390, 1320] s.
      expect(elite.body.predictedRaw).toBeGreaterThanOrEqual(390);
      expect(beginner.body.predictedRaw).toBeLessThanOrEqual(1320);
    });

    it("Cindy (male, AMRAP 20') : score = VOLUME (reps), élite > débutant", async () => {
      const elite = await predict("cindy", "male", profile(ELITE));
      const beginner = await predict("cindy", "male", profile(BEGINNER));
      expect(elite.body.scoreType).toBe("reps");
      expect(elite.body.predictedRaw).toBeGreaterThan(beginner.body.predictedRaw);
      expect(beginner.body.predictedRaw).toBeGreaterThan(0);
    });
  });
});
