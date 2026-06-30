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
 * Anti-triche (decision verrouillee « justesse non negociable ») :
 *  - un saut > +30 % du sous-score vs le meilleur effort 7j -> review:'pending_review' (exclu) ;
 *  - le client ne peut plus fournir performedAt (heure serveur). Necessite Postgres + Redis up.
 */
describe("api — anti-triche resultats (e2e reel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;
  let redis: Redis;

  const stamp = Date.now();
  const email = `e2e_cheat_${stamp}@test.local`;
  let token = "";
  let userId = "";

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

    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({ email, password: "motdepasse123", displayName: `Cheat${stamp}`, dateOfBirth: "1995-05-10", sex: "male", goal: "hyrox" })
      .expect(201);
    token = reg.body.token;
    userId = reg.body.user.id;
  });

  afterAll(async () => {
    if (userId) {
      await prisma.hybridIndexHistory.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.progressWeekly.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
      await redis.zrem("leaderboard:male", userId).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    redis.disconnect();
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  it("1er effort sur un WOD : jamais flagge (pas de base de comparaison)", async () => {
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "fran", scoreType: "time", rawResult: 660 }) // ~11:00, mid-pack honnete (P50 du modele recalibre)
      .expect(201);
    const row = await prisma.wodResult.findFirst({ where: { userId, wodId: "fran" }, orderBy: { createdAt: "desc" } });
    expect(row?.review).toBe("ok");
  });

  it("saut > +30 % du sous-score vs 7j -> pending_review (exclu du classement)", async () => {
    // Fran ~2:10 (130s) = quasi-champion (sub ~1000) vs le 11:00 mid-pack (sub ~433) -> saut > +30 %.
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "fran", scoreType: "time", rawResult: 130 })
      .expect(201);
    const flagged = await prisma.wodResult.findFirst({
      where: { userId, wodId: "fran", rawResult: 130 },
      orderBy: { createdAt: "desc" },
    });
    expect(flagged?.review).toBe("pending_review");

    // Le classement Fran (filtre review:'ok') ne doit PAS exposer le temps flagge.
    const lb = await request(api.getHttpServer())
      .get("/v1/wods/fran/leaderboard?sex=male")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    const mine = (lb.body.entries as Array<{ isMe: boolean; rawResult: number }>).find((e) => e.isMe);
    // Si je suis present, c'est avec mon effort honnete (660), jamais le flagge (130).
    if (mine) expect(mine.rawResult).not.toBe(130);
  });

  it("performedAt fourni par le client est ignore (heure serveur)", async () => {
    const future = new Date(Date.now() + 90 * 86400000).toISOString(); // +90 jours
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "row_2k", scoreType: "time", rawResult: 480, performedAt: future })
      .expect(201);
    const row = await prisma.wodResult.findFirst({ where: { userId, wodId: "row_2k" }, orderBy: { createdAt: "desc" } });
    expect(row).toBeTruthy();
    // performedAt doit etre ~maintenant, jamais dans 90 jours.
    expect(row!.performedAt.getTime()).toBeLessThan(Date.now() + 5 * 60 * 1000);
  });

  // La VRAIE voie de log du mobile : /v1/wods/:id/results (wods.service), pas /v1/results.
  it("voie /v1/wods/:id/results : anti-triche actif (saut > +30 % quasi-élite -> pending_review)", async () => {
    // helen 700s (honnête) puis 400s (proche champion ~390s) → saut suspect.
    await request(api.getHttpServer())
      .post("/v1/wods/helen/results")
      .set("authorization", `Bearer ${token}`)
      .send({ rawResult: 700 })
      .expect(201);
    await request(api.getHttpServer())
      .post("/v1/wods/helen/results")
      .set("authorization", `Bearer ${token}`)
      .send({ rawResult: 400 })
      .expect(201);
    const flagged = await prisma.wodResult.findFirst({
      where: { userId, wodId: "helen", rawResult: 400 },
      orderBy: { createdAt: "desc" },
    });
    expect(flagged?.review).toBe("pending_review");
  });

  it("voie /v1/wods/:id/results : idempotence (même clé -> un seul résultat)", async () => {
    const key = `e2e_idem_${stamp}`;
    const body = { rawResult: 480, idempotencyKey: key };
    await request(api.getHttpServer())
      .post("/v1/wods/row_2k/results")
      .set("authorization", `Bearer ${token}`)
      .send(body)
      .expect(201);
    await request(api.getHttpServer())
      .post("/v1/wods/row_2k/results")
      .set("authorization", `Bearer ${token}`)
      .send(body)
      .expect(201); // rejeu accepté, mais pas de doublon
    const count = await prisma.wodResult.count({ where: { userId, idempotencyKey: key } });
    expect(count).toBe(1);
  });
});
