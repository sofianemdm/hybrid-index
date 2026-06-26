import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";
import { ATTRIBUTE_KEYS } from "@hybrid-index/contracts";
import { SESSIONS, attributeWeights, sessionsForAttribute } from "../src/modules/coach/sessions.data";

/**
 * Bibliothèque de séances PAR ATTRIBUT (écran mobile « Séances de [attribut] »).
 * (a) poids dérivés + override forgeron (logique pure) ;
 * (b) GET /v1/coach/library?attribute= trié par weight desc, weight>=0.35, filtre matériel ("none") ;
 * (c) GET /v1/coach/weekly = weekly-forgeron ;
 * (d) GET /v1/coach (existant) marche toujours.
 * Nécessite Postgres + Redis up + le vrai score-service (en mémoire) pour /v1/coach.
 */
describe("api — bibliothèque de séances par attribut (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;

  const stamp = Date.now();
  // User « équipé » (matériel autorisé) — sert aussi à /v1/coach (onboarding requis).
  const emailGeared = `e2e_lib_geared_${stamp}@test.local`;
  let tokenGeared = "";
  let userGeared = "";
  // User « sans matériel » (equipmentPref: "none").
  const emailNoGear = `e2e_lib_nogear_${stamp}@test.local`;
  let tokenNoGear = "";
  let userNoGear = "";

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

    const regGeared = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({ email: emailGeared, password: "motdepasse123", displayName: `LibGeared${stamp}`, dateOfBirth: "1995-05-10", sex: "male", goal: "hyrox", equipmentPref: "both" })
      .expect(201);
    tokenGeared = regGeared.body.token;
    userGeared = regGeared.body.user.id;
    // Onboarding pour débloquer des attributs (nécessaire à /v1/coach).
    await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${tokenGeared}`)
      .send({ course: { distanceMeters: 5000, timeSeconds: 1440 }, estimatedPushups: 30 })
      .expect(201);

    const regNoGear = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({ email: emailNoGear, password: "motdepasse123", displayName: `LibNoGear${stamp}`, dateOfBirth: "1992-03-03", sex: "female", goal: "all_round", equipmentPref: "none" })
      .expect(201);
    tokenNoGear = regNoGear.body.token;
    userNoGear = regNoGear.body.user.id;
  });

  afterAll(async () => {
    for (const id of [userGeared, userNoGear]) {
      if (id) {
        await prisma.hybridIndexHistory.deleteMany({ where: { userId: id } }).catch(() => undefined);
        await prisma.progressWeekly.deleteMany({ where: { userId: id } }).catch(() => undefined);
        await prisma.user.deleteMany({ where: { id } }).catch(() => undefined);
      }
    }
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  // ─── (a) Logique pure : attributeWeights ──────────────────────────────────
  describe("attributeWeights (barème §3)", () => {
    it("dérive le barème depuis les tags d'une séance type (primaire=1, sec 0.60/0.45, plancher 0.10)", () => {
      // speed-hill-sprints : primaire=speed, secondaires=[power, strength] → power 0.60, strength 0.45.
      const s = SESSIONS.find((x) => x.id === "speed-hill-sprints")!;
      const w = attributeWeights(s);
      expect(w.speed).toBe(1.0); // primaire
      expect(w.power).toBe(0.6); // 1er secondaire
      expect(w.strength).toBe(0.45); // 2e secondaire
      expect(w.engine).toBe(0.1); // plancher
      expect(w.muscular_endurance).toBe(0.1);
      expect(w.hybrid).toBe(0.1);
      // Les 6 clés sont présentes.
      expect(Object.keys(w).sort()).toEqual([...ATTRIBUTE_KEYS].sort());
    });

    it("applique le 3e secondaire à 0.35 (hybrid-emom-mixed-30)", () => {
      // primaire=hybrid, secondaires=[engine, muscular_endurance, power] → 0.60/0.45/0.35.
      const w = attributeWeights(SESSIONS.find((x) => x.id === "hybrid-emom-mixed-30")!);
      expect(w.hybrid).toBe(1.0);
      expect(w.engine).toBe(0.6);
      expect(w.muscular_endurance).toBe(0.45);
      expect(w.power).toBe(0.35);
      expect(w.speed).toBe(0.1);
      expect(w.strength).toBe(0.1);
    });

    it("utilise les poids calibrés main pour weekly-forgeron (exception §3)", () => {
      const w = attributeWeights(SESSIONS.find((x) => x.id === "weekly-forgeron")!);
      expect(w).toEqual({ hybrid: 1.0, engine: 0.9, muscular_endurance: 0.8, power: 0.4, speed: 0.3, strength: 0.15 });
    });

    it("sessionsForAttribute trie par weight desc et exclut le plancher (< 0.35)", () => {
      const list = sessionsForAttribute("speed", false);
      expect(list.length).toBeGreaterThan(0);
      expect(list.every((s) => s.weight >= 0.35)).toBe(true);
      for (let i = 1; i < list.length; i++) {
        expect(list[i - 1].weight).toBeGreaterThanOrEqual(list[i].weight);
      }
      // noGear ⇒ que du sans-matériel.
      expect(sessionsForAttribute("speed", true).every((s) => !s.requiresEquipment)).toBe(true);
    });
  });

  // ─── (b) GET /v1/coach/library ────────────────────────────────────────────
  it("library : séances triées par weight desc, toutes weight>=0.35 (user équipé)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/coach/library?attribute=speed")
      .set("authorization", `Bearer ${tokenGeared}`)
      .expect(200);
    expect(res.body.attribute).toBe("speed");
    expect(Array.isArray(res.body.sessions)).toBe(true);
    expect(res.body.sessions.length).toBeGreaterThan(0);
    expect(res.body.sessions.every((s: { weight: number }) => s.weight >= 0.35)).toBe(true);
    for (let i = 1; i < res.body.sessions.length; i++) {
      expect(res.body.sessions[i - 1].weight).toBeGreaterThanOrEqual(res.body.sessions[i].weight);
    }
    // En tête : les primaires (weight = 1) sur l'attribut demandé.
    expect(res.body.sessions[0].weight).toBe(1.0);
    expect(res.body.sessions[0].primaryAttribute).toBe("speed");
    // Forme JSON : chaque séance porte les champs attendus par le mobile.
    const first = res.body.sessions[0];
    expect(first).toMatchObject({
      id: expect.any(String),
      name: expect.any(String),
      primaryAttribute: expect.any(String),
      secondaryAttributes: expect.any(Array),
      requiresEquipment: expect.any(Boolean),
      durationMin: expect.any(Number),
      intensity: expect.stringMatching(/^(low|medium|high)$/),
      description: expect.any(String),
      weight: expect.any(Number),
    });
    // User équipé ⇒ contient au moins une séance avec matériel.
    expect(res.body.sessions.some((s: { requiresEquipment: boolean }) => s.requiresEquipment)).toBe(true);
  });

  it("library : user equipmentPref=\"none\" ne reçoit QUE du sans-matériel", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/coach/library?attribute=speed")
      .set("authorization", `Bearer ${tokenNoGear}`)
      .expect(200);
    expect(res.body.sessions.length).toBeGreaterThan(0);
    expect(res.body.sessions.every((s: { requiresEquipment: boolean }) => s.requiresEquipment === false)).toBe(true);
    // Toujours trié + seuil respecté.
    expect(res.body.sessions.every((s: { weight: number }) => s.weight >= 0.35)).toBe(true);
    for (let i = 1; i < res.body.sessions.length; i++) {
      expect(res.body.sessions[i - 1].weight).toBeGreaterThanOrEqual(res.body.sessions[i].weight);
    }
  });

  it("library : attribut invalide → 400 VALIDATION_ERROR ; sans attribut → 400", async () => {
    const bad = await request(api.getHttpServer())
      .get("/v1/coach/library?attribute=cardio")
      .set("authorization", `Bearer ${tokenGeared}`)
      .expect(400);
    expect(bad.body.error.code).toBe("VALIDATION_ERROR");
    await request(api.getHttpServer())
      .get("/v1/coach/library")
      .set("authorization", `Bearer ${tokenGeared}`)
      .expect(400);
  });

  // ─── (c) GET /v1/coach/weekly ─────────────────────────────────────────────
  it("weekly : renvoie la séance signature weekly-forgeron", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/coach/weekly")
      .set("authorization", `Bearer ${tokenGeared}`)
      .expect(200);
    expect(res.body.session.id).toBe("weekly-forgeron");
    expect(res.body.session.primaryAttribute).toBe("hybrid");
    expect(res.body.session.requiresEquipment).toBe(false);
    expect(typeof res.body.session.description).toBe("string");
  });

  // ─── (d) GET /v1/coach (existant) ─────────────────────────────────────────
  it("coach (existant) : Index projeté + séances ciblées sur primaryAttribute", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/coach?attribute=power")
      .set("authorization", `Bearer ${tokenGeared}`)
      .expect(200);
    expect(res.body.targetAttribute).toBe("power");
    expect(res.body.projection.projected).toBeGreaterThanOrEqual(res.body.projection.current);
    expect(res.body.sessions.length).toBeGreaterThan(0);
    expect(res.body.sessions.every((s: { primaryAttribute: string }) => s.primaryAttribute === "power")).toBe(true);
  });
});
