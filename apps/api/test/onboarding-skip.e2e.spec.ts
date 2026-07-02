import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

/**
 * « Je n'ai aucune de ces infos » (POST /v1/onboarding/skip) : l'utilisateur entre dans l'app SANS
 * aucun effort. On vérifie que :
 *  (a) AVANT skip, sans Index → GET /me/profile renvoie 404 (→ l'app montre l'onboarding) ;
 *  (b) le skip réussit (201) ;
 *  (c) APRÈS skip → GET /me/profile renvoie 200 avec un profil VIDE (radarCoverage 0, radar
 *      entièrement verrouillé, HORS classement) → l'app entre au HomeShell, plus d'onboarding.
 */
jest.setTimeout(60000); // boot score-service + api (cold-start ts-jest en run isolé)

describe("api — onboarding/skip : entrer sans Index (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;

  const stamp = Date.now();
  const email = `e2e_skip_${stamp}@test.local`;
  let token = "";
  let userId = "";

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

    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({ email, password: "motdepasse123", displayName: `Skip${stamp}`, dateOfBirth: "1994-04-04", sex: "male", goal: "all_round", equipmentPref: "both" })
      .expect(201);
    token = reg.body.token;
    userId = reg.body.user.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
    await prisma.$disconnect();
    await api.close();
    await scoreApp.close();
  });

  it("(a) AVANT skip, aucun Index → GET /me/profile renvoie 404", async () => {
    await request(api.getHttpServer())
      .get("/v1/me/profile")
      .set("authorization", `Bearer ${token}`)
      .expect(404);
  });

  it("(b) POST /onboarding/skip réussit", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/onboarding/skip")
      .set("authorization", `Bearer ${token}`)
      .expect(201);
    expect(res.body).toEqual({ ok: true });
  });

  it("(c) APRÈS skip → profil VIDE (radarCoverage 0, radar verrouillé, hors classement)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/me/profile")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.index.radarCoverage).toBe(0);
    expect(res.body.radar).toHaveLength(6);
    expect(res.body.radar.every((a: { unlocked: boolean }) => a.unlocked === false)).toBe(true);
    // Hors classement : aucune position de ligue tant qu'aucun effort n'est loggé.
    expect(res.body.leaguePosition ?? null).toBeNull();
  });
});
