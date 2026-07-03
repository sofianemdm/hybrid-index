import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

jest.setTimeout(60000); // boot score-service + api (cold-start ts-jest en run isolé)

/**
 * FIL DE CLUB (lot 2.C) — le contrat de sécurité et de lecture :
 *  (a) un MEMBRE publie dans le fil de son club (201, clubId persisté) ;
 *  (b) un NON-membre est rejeté (403) — sinon n'importe qui écrirait dans n'importe quel fil ;
 *  (c) GET /v1/posts/club/:id renvoie le fil paginé { items, nextCursor } (lecture ouverte) ;
 *  (d) après avoir REJOINT le club, l'ex-non-membre peut publier.
 */
describe("api — fil de club (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;

  const stamp = Date.now();
  const emailA = `e2e_clubfeed_a_${stamp}@test.local`;
  const emailB = `e2e_clubfeed_b_${stamp}@test.local`;
  let tokenA = "";
  let tokenB = "";
  let userA = "";
  let userB = "";
  let clubId = "";

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

    for (const [email, name] of [
      [emailA, `ClubFeedA${stamp}`],
      [emailB, `ClubFeedB${stamp}`],
    ] as const) {
      const reg = await request(api.getHttpServer())
        .post("/v1/auth/register")
        .send({ email, password: "motdepasse123", displayName: name, dateOfBirth: "1994-04-04", sex: "male", goal: "all_round", equipmentPref: "both" })
        .expect(201);
      if (email === emailA) {
        tokenA = reg.body.token;
        userA = reg.body.user.id;
      } else {
        tokenB = reg.body.token;
        userB = reg.body.user.id;
      }
    }

    const club = await request(api.getHttpServer())
      .post("/v1/clubs")
      .set("authorization", `Bearer ${tokenA}`)
      .send({ name: `Club Feed ${stamp}`, description: "e2e fil de club" })
      .expect(201);
    clubId = club.body.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: [userA, userB] } } }).catch(() => undefined);
    await prisma.$disconnect();
    await api.close();
    await scoreApp.close();
  });

  it("(a) un membre publie dans le fil du club (clubId persisté)", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/posts")
      .set("authorization", `Bearer ${tokenA}`)
      .send({ kind: "text", body: "Première du club 💪", clubId })
      .expect(201);
    const row = await prisma.post.findUnique({ where: { id: res.body.id }, select: { clubId: true } });
    expect(row?.clubId).toBe(clubId);
  });

  it("(b) un NON-membre est rejeté (403)", async () => {
    await request(api.getHttpServer())
      .post("/v1/posts")
      .set("authorization", `Bearer ${tokenB}`)
      .send({ kind: "text", body: "Je ne suis pas membre", clubId })
      .expect(403);
  });

  it("(c) le fil du club se lit paginé { items, nextCursor }", async () => {
    const res = await request(api.getHttpServer())
      .get(`/v1/posts/club/${clubId}`)
      .set("authorization", `Bearer ${tokenB}`) // lecture ouverte, même non-membre
      .expect(200);
    expect(Array.isArray(res.body.items)).toBe(true);
    expect(res.body.items.length).toBeGreaterThan(0);
    expect(res.body.items.some((p: { payload?: { body?: string } }) => p.payload?.body?.includes("Première du club"))).toBe(true);
  });

  it("(d) après avoir rejoint le club, l'ex-non-membre publie", async () => {
    await request(api.getHttpServer()).post(`/v1/clubs/${clubId}/join`).set("authorization", `Bearer ${tokenB}`).expect(201);
    await request(api.getHttpServer())
      .post("/v1/posts")
      .set("authorization", `Bearer ${tokenB}`)
      .send({ kind: "text", body: "Nouveau membre !", clubId })
      .expect(201);
  });
});
