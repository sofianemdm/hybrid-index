import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import Redis from "ioredis";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

/**
 * Boucle complète persistée (RÉELLE) : register → age-gate → onboarding/complete → log WOD →
 * classement, contre la vraie base + Redis + le vrai score-service en mémoire.
 * Nécessite Docker (Postgres + Redis) up et la base migrée/seedée.
 */
describe("api — boucle complète persistée (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;
  let redis: Redis;

  const stamp = Date.now();
  const email = `e2e_loop_${stamp}@test.local`;
  const displayName = `E2ELoop${stamp}`;
  let token = "";
  let userId = "";
  let customWodId = "";
  let overtakerUserId = "";

  beforeAll(async () => {
    const scoreRef = await Test.createTestingModule({ imports: [ScoreAppModule] }).compile();
    scoreApp = configureScoreApp(scoreRef.createNestApplication());
    await scoreApp.listen(0);
    const port = (scoreApp.getHttpServer().address() as AddressInfo).port;
    process.env.SCORE_SERVICE_URL = `http://127.0.0.1:${port}`;

    const { AppModule } = await import("../src/app.module");
    const { configureApp } = await import("../src/app.config");
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();

    prisma = new PrismaClient();
    redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379", { maxRetriesPerRequest: 1 });
  });

  afterAll(async () => {
    // Nettoyage : Postgres (cascade) + entrée Redis orpheline.
    if (userId) {
      await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
      await redis.zrem("leaderboard:male", userId).catch(() => undefined);
    }
    if (overtakerUserId) {
      await prisma.user.deleteMany({ where: { id: overtakerUserId } }).catch(() => undefined);
      await redis.zrem("leaderboard:male", overtakerUserId).catch(() => undefined);
    }
    if (customWodId) {
      await prisma.wod.deleteMany({ where: { id: customWodId } }).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    redis.disconnect();
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  it("refuse l'inscription d'un mineur (< 13 ans) → 403 AGE_RESTRICTED", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email: `kid_${stamp}@test.local`,
        password: "motdepasse123",
        displayName: `Kid${stamp}`,
        dateOfBirth: "2015-01-01",
        sex: "male",
        goal: "hyrox",
      })
      .expect(403);
    expect(res.body.error.code).toBe("AGE_RESTRICTED");
  });

  it("inscrit un adulte → token + user", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email,
        password: "motdepasse123",
        displayName,
        dateOfBirth: "1995-05-10",
        sex: "male",
        goal: "hyrox",
        equipmentPref: "both",
      })
      .expect(201);
    expect(res.body.token).toBeTruthy();
    expect(res.body.user.displayName).toBe(displayName);
    token = res.body.token;
    userId = res.body.user.id;
  });

  it("onboarding/complete persiste l'Index révélé", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${token}`)
      .send({ course: { distanceMeters: 5000, timeSeconds: 1440 }, estimatedPushups: 30 })
      .expect(201);
    expect(res.body.index.value).toBeGreaterThan(0);
    const engine = res.body.radar.find((a: { attribute: string }) => a.attribute === "engine");
    expect(engine.unlocked).toBe(true);

    // Persistance vérifiée via GET /v1/me/profile.
    const me = await request(api.getHttpServer())
      .get("/v1/me/profile")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(me.body.index.value).toBe(res.body.index.value);
  });

  it("log d'un WOD → recalcul, nouvel attribut débloqué (no-drop)", async () => {
    const before = await request(api.getHttpServer())
      .get("/v1/me/profile")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    const coverageBefore = before.body.index.radarCoverage as number;

    const res = await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "fran", scoreType: "time", rawResult: 300 })
      .expect(201);
    expect(res.body.result.subScore).toBeGreaterThan(0);
    expect(res.body.profile.index.radarCoverage).toBeGreaterThanOrEqual(coverageBefore);
    const power = res.body.profile.radar.find((a: { attribute: string }) => a.attribute === "power");
    expect(power.unlocked).toBe(true);
    // H1 : feedback de compétence — Fran débloque/améliore des attributs ⇒ gains non vides + point faible.
    expect(Array.isArray(res.body.profile.gains)).toBe(true);
    expect(res.body.profile.gains.length).toBeGreaterThan(0);
    expect(res.body.profile.gains.every((g: { delta: number }) => g.delta > 0)).toBe(true);
    expect(typeof res.body.profile.weakest).toBe("string");
  });

  it("rejette un résultat hors bornes (422)", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "fran", scoreType: "time", rawResult: 5 })
      .expect(422);
    expect(res.body.error.code).toBe("WOD_RESULT_OUT_OF_BOUNDS");
  });

  it("log idempotent : même idempotencyKey → pas de double comptage", async () => {
    const payload = { wodId: "row_2k", scoreType: "time", rawResult: 440, idempotencyKey: `e2e_${stamp}_row` };
    await request(api.getHttpServer()).post("/v1/results").set("authorization", `Bearer ${token}`).send(payload).expect(201);
    await request(api.getHttpServer()).post("/v1/results").set("authorization", `Bearer ${token}`).send(payload).expect(201);
    const rows = (await prisma.wodResult.findMany({ where: { userId, idempotencyKey: payload.idempotencyKey } }));
    expect(rows.length).toBe(1);
  });

  it("classement Hommes inclut l'utilisateur et le surligne", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/leaderboard?sex=male&limit=100")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.total).toBeGreaterThan(0);
    expect(res.body.me).not.toBeNull();
    const mine = res.body.entries.find((e: { isMe: boolean }) => e.isMe);
    expect(mine).toBeTruthy();
  });

  it("coach : Index projeté >= actuel + séances ciblées", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/coach?attribute=power")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.targetAttribute).toBe("power");
    expect(res.body.projection.projected).toBeGreaterThanOrEqual(res.body.projection.current);
    expect(res.body.sessions.length).toBeGreaterThan(0);
    expect(res.body.sessions[0].primaryAttribute).toBe("power");
  });

  it("profil public : radar + Index visibles (tout est public)", async () => {
    const res = await request(api.getHttpServer())
      .get(`/v1/profiles/${userId}`)
      .expect(200);
    expect(res.body.displayName).toBe(displayName);
    expect(res.body.index.value).toBeGreaterThan(0);
    expect(res.body.radar.length).toBe(6);
  });

  it("streak : structure + progression de la semaine", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/streak")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.weeklyGoal).toBe(3);
    expect(res.body.thisWeekCount).toBeGreaterThanOrEqual(1);
    expect(typeof res.body.current).toBe("number");
  });

  it("badges : au moins un débloqué (rang/index élevé)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/badges")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(16);
    expect(res.body.some((b: { unlocked: boolean }) => b.unlocked)).toBe(true);
  });

  it("notifications : lecture + mise à jour du dailyCap", async () => {
    await request(api.getHttpServer())
      .get("/v1/me/notifications")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    const res = await request(api.getHttpServer())
      .patch("/v1/me/notifications")
      .set("authorization", `Bearer ${token}`)
      .send({ dailyCap: 1 })
      .expect(200);
    expect(res.body.dailyCap).toBe(1);
  });

  it("RGPD : export contient profil + résultats, sans hash de mot de passe", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/export")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.profile.displayName).toBe(displayName);
    expect(Array.isArray(res.body.wodResults)).toBe(true);
    expect(res.body.passwordHash).toBeUndefined();
  });

  it("avatar : personnalisation persistée", async () => {
    await request(api.getHttpServer())
      .patch("/v1/me/avatar")
      .set("authorization", `Bearer ${token}`)
      .send({ skinTone: 4, hairStyle: 3, hairColor: 2, beardStyle: 1 })
      .expect(200);
    const res = await request(api.getHttpServer())
      .get("/v1/me/avatar")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body).toMatchObject({ skinTone: 4, hairStyle: 3, hairColor: 2, beardStyle: 1 });
  });

  it("flux de notifications : tableau d'items cohérents", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/notifications/feed")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    for (const item of res.body) {
      expect(typeof item.title).toBe("string");
      expect(["high", "medium", "low"]).toContain(item.priority);
    }
  });

  it("streak : réglage de l'objectif hebdo", async () => {
    const res = await request(api.getHttpServer())
      .patch("/v1/me/streak")
      .set("authorization", `Bearer ${token}`)
      .send({ weeklyGoal: 4 })
      .expect(200);
    expect(res.body.weeklyGoal).toBe(4);
  });

  it("endgame : Grand Chelem + rang mondial cohérents", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/endgame")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.grandSlam.total).toBe(15);
    expect(res.body.grandSlam.beaten).toBeGreaterThanOrEqual(0);
    expect(res.body.grandSlam.beaten).toBeLessThanOrEqual(15);
    expect(res.body.globalRank).toBeGreaterThanOrEqual(1);
  });

  it("WOD : catalogue contient les références", async () => {
    const res = await request(api.getHttpServer()).get("/v1/wods").expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.some((w: { id: string }) => w.id === "fran")).toBe(true);
  });

  it("WOD : fiche Fran avec paliers + mon meilleur effort", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/wods/fran")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.scoreType).toBe("time");
    expect(res.body.levels.male.champion).toBeLessThan(res.body.levels.male.intermediate);
    expect(res.body.myBest.subScore).toBeGreaterThan(0); // l'utilisateur a loggé Fran
  });

  it("WOD : classement Fran (Hommes) inclut l'utilisateur", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/wods/fran/leaderboard?sex=male")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.entries.some((e: { isMe: boolean }) => e.isMe)).toBe(true);
  });

  it("mouvements : catalogue exposé", async () => {
    const res = await request(api.getHttpServer()).get("/v1/movements").expect(200);
    expect(res.body.length).toBeGreaterThanOrEqual(30);
    expect(res.body.some((m: { id: string }) => m.id === "thruster")).toBe(true);
  });

  it("estimation ad-hoc d'un WOD custom", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/wods/estimate")
      .send({
        sex: "male",
        scoreType: "time",
        wodType: "for_time",
        blocks: [
          { movementId: "thruster", reps: 30, loadKg: 43 },
          { movementId: "pull_up", reps: 30 },
        ],
        userResult: 240,
      })
      .expect(201);
    expect(res.body.references.length).toBe(3);
    expect(res.body.subScore).toBeGreaterThan(0);
    expect(res.body.confidence).toBe("estimated");
  });

  it("WOD custom : création → log noté par estimation → compte dans l'Index → classement", async () => {
    const create = await request(api.getHttpServer())
      .post("/v1/wods")
      .set("authorization", `Bearer ${token}`)
      .send({
        name: `Test WOD ${stamp}`,
        type: "for_time",
        scoreType: "time",
        requiresEquipment: false,
        blocks: [
          { movementId: "burpee", reps: 50 },
          { movementId: "air_squat", reps: 50 },
        ],
      })
      .expect(201);
    customWodId = create.body.id;
    expect(create.body.isCustom).toBe(true);
    expect(create.body.targetAttributes.length).toBeGreaterThan(0);

    const cat = await request(api.getHttpServer()).get("/v1/wods").expect(200);
    expect(cat.body.some((w: { id: string }) => w.id === customWodId)).toBe(true);

    const log = await request(api.getHttpServer())
      .post(`/v1/wods/${customWodId}/results`)
      .set("authorization", `Bearer ${token}`)
      .send({ rawResult: 360 })
      .expect(201);
    expect(log.body.result.subScore).toBeGreaterThan(0);
    expect(log.body.profile.index.value).toBeGreaterThan(0);

    const lb = await request(api.getHttpServer())
      .get(`/v1/wods/${customWodId}/leaderboard?sex=male`)
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(lb.body.entries.some((e: { isMe: boolean }) => e.isMe)).toBe(true);
  });

  it("feed : contient mes propres événements (PR/WOD loggés)", async () => {
    const res = await request(api.getHttpServer()).get("/v1/feed").set("authorization", `Bearer ${token}`).expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body[0].actor.isMe).toBe(true);
  });

  it("kudos : auto-kudos interdit (409)", async () => {
    const feed = (await request(api.getHttpServer()).get("/v1/feed").set("authorization", `Bearer ${token}`)).body;
    await request(api.getHttpServer())
      .post("/v1/reactions")
      .set("authorization", `Bearer ${token}`)
      .send({ feedEventId: feed[0].id, emoji: "💪" })
      .expect(409);
  });

  it("follow : suivre un athlète + apparaître dans following", async () => {
    const lb = (await request(api.getHttpServer()).get("/v1/leaderboard?sex=male&limit=5").set("authorization", `Bearer ${token}`)).body;
    const other = lb.entries.find((e: { isMe: boolean }) => !e.isMe);
    if (!other) return;
    await request(api.getHttpServer()).post(`/v1/follow/${other.userId}`).set("authorization", `Bearer ${token}`).expect(201);
    const following = (await request(api.getHttpServer()).get("/v1/me/following").set("authorization", `Bearer ${token}`)).body;
    expect(following.some((a: { userId: string }) => a.userId === other.userId)).toBe(true);
  });

  it("explore : recherche d'athlètes filtrée par sexe (Hommes)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/explore?sex=male")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body.every((a: { sex: string }) => a.sex === "male")).toBe(true);
    // trié par Index décroissant
    for (let i = 1; i < res.body.length; i++) {
      expect(res.body[i - 1].index ?? 0).toBeGreaterThanOrEqual(res.body[i].index ?? 0);
    }
  });

  it("explore : recherche par pseudo (insensible à la casse)", async () => {
    const all = (await request(api.getHttpServer()).get("/v1/explore").set("authorization", `Bearer ${token}`)).body;
    const target = all.find((a: { displayName: string }) => a.displayName && a.displayName.length >= 3);
    if (!target) return;
    const frag = target.displayName.slice(0, 3).toUpperCase();
    const res = await request(api.getHttpServer())
      .get(`/v1/explore?q=${encodeURIComponent(frag)}`)
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.some((a: { userId: string }) => a.userId === target.userId)).toBe(true);
  });

  it("preuve sociale : percentile population toujours présent, app masqué hors top 30%/ligue<200", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/profile")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    // Humanité : toujours présent, bande pop_* cohérente.
    expect(res.body.socialProof).toBeDefined();
    expect(res.body.socialProof.population.band).toMatch(/^pop_/);
    expect(res.body.socialProof.population.percentile).toBeGreaterThan(0);
    expect(res.body.socialProof.population.percentile).toBeLessThan(1);
    // App : la ligue de test (~quelques dizaines d'users) < 200 → bloc app masqué, jamais dévalorisant.
    expect(res.body.socialProof.app.visible).toBe(false);
    expect(res.body.socialProof.app.topPercent).toBeNull();
    // Invariant produit : un utilisateur qui s'entraîne est au-dessus de la médiane des humains.
    expect(res.body.socialProof.population.percentile).toBeGreaterThan(0.5);
  });

  it("notif « dépassé sur un WOD » : un athlète suivi qui bat mon temps déclenche l'alerte", async () => {
    // 2e athlète qui écrase mon Fran (130 s < 300 s) puis je le suis → notif wod-overtaken.
    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email: `e2e_overtaker_${stamp}@test.local`,
        password: "motdepasse123",
        displayName: `E2EOver${stamp}`,
        dateOfBirth: "1993-02-02",
        sex: "male",
        goal: "crossfit_strength",
        equipmentPref: "both",
      })
      .expect(201);
    const t2 = reg.body.token as string;
    overtakerUserId = reg.body.user.id as string;
    await request(api.getHttpServer())
      .post("/v1/onboarding/complete")
      .set("authorization", `Bearer ${t2}`)
      .send({ course: { distanceMeters: 5000, timeSeconds: 1200 }, estimatedPushups: 40 })
      .expect(201);
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${t2}`)
      .send({ wodId: "fran", scoreType: "time", rawResult: 130 })
      .expect(201);

    // Je suis l'athlète, puis je consulte mon flux de notifications.
    await request(api.getHttpServer())
      .post(`/v1/follow/${overtakerUserId}`)
      .set("authorization", `Bearer ${token}`)
      .expect(201);
    const feed = await request(api.getHttpServer())
      .get("/v1/me/notifications/feed")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(feed.body.some((i: { key: string }) => i.key === "wod-overtaken")).toBe(true);
  });

  it("RGPD : suppression de compte (effacement) — DOIT être le dernier test", async () => {
    const res = await request(api.getHttpServer())
      .delete("/v1/me")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.deleted).toBe(true);
    userId = ""; // déjà supprimé : évite le double-nettoyage afterAll
  });
});
