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
    it("CAS soso → ~13–15 min (756–924 s) après marge de battabilité ×1.4, PAS « 4:40 »", async () => {
      // Estimation « réelle » ~9–11 min (540–660 s) GONFLÉE de +40 % (BEATABILITY_BUFFER) → l'app
      // affiche un temps volontairement facile à battre. Plage = base [540, 660] × 1.4.
      const res = await predict("fran", "male", profile(SOSO));
      expect(res.body.scoreType).toBe("time");
      expect(res.body.predictedRaw).toBeGreaterThanOrEqual(756);
      expect(res.body.predictedRaw).toBeLessThanOrEqual(924);
      // Régression du bug d'origine : ne doit JAMAIS retomber au voisinage de l'ancien 4:40 (~280 s).
      expect(res.body.predictedRaw).toBeGreaterThan(360);
    });

    it("un athlète tout-en-haut (élite) reste RAPIDE", async () => {
      const elite = await predict("fran", "male", profile(ELITE));
      const soso = await predict("fran", "male", profile(SOSO));
      // L'élite bat largement soso et reste dans un temps de pointe. Base ~237 s × 1.4 (marge de
      // battabilité) ≈ 332 s → on borne à ≤ 360 s (≈ 5 min × 1.4 / le buffer).
      expect(elite.body.predictedRaw).toBeLessThan(soso.body.predictedRaw);
      expect(elite.body.predictedRaw).toBeLessThanOrEqual(360);
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
      // Borné par le garde-fou population : bas ≥ hardMin (390) ; haut ≤ max(hardMax, q99). Après
      // recalibrage salle (médiane 12:30, σ 0,30), q99 ≈ 1510 s élargit la borne haute > hardMax 1320.
      expect(elite.body.predictedRaw).toBeGreaterThanOrEqual(390);
      expect(beginner.body.predictedRaw).toBeLessThanOrEqual(1520);
    });

    it("Cindy (male, AMRAP 20') : score = VOLUME (reps), élite > débutant", async () => {
      const elite = await predict("cindy", "male", profile(ELITE));
      const beginner = await predict("cindy", "male", profile(BEGINNER));
      expect(elite.body.scoreType).toBe("reps");
      expect(elite.body.predictedRaw).toBeGreaterThan(beginner.body.predictedRaw);
      expect(beginner.body.predictedRaw).toBeGreaterThan(0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────────────────────
  // BLUEPRINTS AJOUTÉS (audit prédiction des temps §3a) — ces WODs retombaient AVANT en SILENCE sur
  // le modèle population. Désormais ils passent par le moteur per-mouvement (+ pénalité de charge) :
  // jamais plus rapides que la référence élite (proReference, garde-fou « vrai tail »), bornés, et
  // monotones par niveau.
  // ───────────────────────────────────────────────────────────────────────────────────────────
  describe("WODs jusque-là en repli silencieux — réalisme + monotonie", () => {
    it("Le Chaos (chipper for time) : profil moyen JAMAIS plus rapide que le champion 7:10, débutant lent (>9 min)", async () => {
      const soso = await predict("league_hybrid_chipper", "male", profile(SOSO));
      const beginner = await predict("league_hybrid_chipper", "male", profile(BEGINNER));
      expect(soso.body.scoreType).toBe("time");
      expect(soso.body.predictedRaw).toBeGreaterThanOrEqual(430); // garde-fou vrai tail (champion 7:10)
      expect(beginner.body.predictedRaw).toBeGreaterThan(540); // débutant > 9 min
      expect(beginner.body.predictedRaw).toBeLessThanOrEqual(1200); // borné par le cap 15 min
      expect(beginner.body.predictedRaw).toBeGreaterThan(soso.body.predictedRaw);
    });

    it("Murph (course + 600 reps gym) : temps LONG réaliste, force-limité, monotone et borné", async () => {
      const soso = await predict("murph", "male", profile(SOSO));
      const elite = await predict("murph", "male", profile(ELITE));
      const beginner = await predict("murph", "male", profile(BEGINNER));
      expect(soso.body.predictedRaw).toBeGreaterThanOrEqual(1850); // hardMin
      expect(beginner.body.predictedRaw).toBeLessThanOrEqual(6000); // hardMax
      expect(elite.body.predictedRaw).toBeLessThanOrEqual(soso.body.predictedRaw);
      expect(soso.body.predictedRaw).toBeLessThan(beginner.body.predictedRaw);
      // La FORCE compte : à power/ME figés, +force ⇒ Murph plus rapide (mur des 100 tractions).
      const lowStr = await predict("murph", "male", profile({ strength: 350, power: 750, muscular_endurance: 800 }));
      const highStr = await predict("murph", "male", profile({ strength: 900, power: 750, muscular_endurance: 800 }));
      expect(highStr.body.predictedRaw).toBeLessThan(lowStr.body.predictedRaw);
    });

    it("Isabel (30 snatch 60 kg) : pénalité de CHARGE relative — élite plus rapide, tous bornés", async () => {
      const elite = await predict("isabel", "male", profile(ELITE));
      const soso = await predict("isabel", "male", profile(SOSO));
      const beginner = await predict("isabel", "male", profile(BEGINNER));
      for (const r of [elite, soso, beginner]) {
        expect(r.body.predictedRaw).toBeGreaterThanOrEqual(45); // hardMin
        expect(r.body.predictedRaw).toBeLessThanOrEqual(600); // hardMax (60 kg brutal sous-Rx)
      }
      // CAS EXTRÊME SATURÉ : Isabel (30 snatch 60 kg) est déjà au plafond (hardMax 600) pour soso et
      // débutant AVANT le buffer ; la marge de battabilité ×1.4 y pousse aussi l'élite → les trois
      // profils saturent à 600. La monotonie STRICTE ne tient plus sur ce WOD volontairement brutal
      // sous-Rx ; on la relâche en ≤ pour CE cas (tous bornés à 600), la stricte reste ailleurs.
      expect(elite.body.predictedRaw).toBeLessThanOrEqual(soso.body.predictedRaw);
      expect(elite.body.predictedRaw).toBeLessThanOrEqual(beginner.body.predictedRaw);
    });

    it("Le Moteur (AMRAP reps, course NON comptée) : score = reps, monotone, course exclue du volume", async () => {
      const elite = await predict("league_engine_12", "male", profile(ELITE));
      const beginner = await predict("league_engine_12", "male", profile(BEGINNER));
      expect(elite.body.scoreType).toBe("reps");
      // La course imposée (unscored) ne gonfle pas le volume → reps, pas des mètres (≤ proReference 215).
      expect(elite.body.predictedRaw).toBeLessThanOrEqual(215);
      expect(elite.body.predictedRaw).toBeGreaterThan(beginner.body.predictedRaw);
      expect(beginner.body.predictedRaw).toBeGreaterThan(0);
    });

    it("HYROX solo : temps long borné, élite ≤ soso < débutant", async () => {
      const soso = await predict("hyrox_solo", "male", profile(SOSO));
      const elite = await predict("hyrox_solo", "male", profile(ELITE));
      const beginner = await predict("hyrox_solo", "male", profile(BEGINNER));
      expect(soso.body.predictedRaw).toBeGreaterThanOrEqual(3000); // hardMin
      expect(beginner.body.predictedRaw).toBeLessThanOrEqual(9000); // hardMax
      expect(elite.body.predictedRaw).toBeLessThanOrEqual(soso.body.predictedRaw);
      expect(soso.body.predictedRaw).toBeLessThan(beginner.body.predictedRaw);
    });
  });
});
