import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

/** A8 — PR Wall : GET /v1/results/prs renvoie le MEILLEUR effort par WOD (e2e réel). */
describe("api — records personnels (A8, e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();
  const email = `e2e_prs_${stamp}@test.local`;
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
      .send({ email, password: "motdepasse123", displayName: `Prs${stamp}`, dateOfBirth: "1995-05-10", sex: "male", goal: "hyrox" })
      .expect(201);
    token = reg.body.token;
    userId = reg.body.user.id;
  });

  afterAll(async () => {
    if (userId) await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  it("ne garde que le meilleur effort par WOD", async () => {
    const post = (wodId: string, rawResult: number) =>
      request(api.getHttpServer())
        .post("/v1/results")
        .set("authorization", `Bearer ${token}`)
        .send({ wodId, scoreType: "time", rawResult })
        .expect(201);

    await post("fran", 360); // 6:00
    await post("fran", 340); // 5:40 (meilleur) — amélioration modeste, pas de flag anti-triche
    await post("row_2k", 480);

    const res = await request(api.getHttpServer())
      .get("/v1/results/prs")
      .set("authorization", `Bearer ${token}`)
      .expect(200);

    const prs = res.body as Array<{ wodId: string; rawResult: number }>;
    expect(prs).toHaveLength(2); // fran + row_2k (un seul PR par WOD)
    const fran = prs.find((p) => p.wodId === "fran");
    expect(fran?.rawResult).toBe(340); // le meilleur des deux frans
  });
});
