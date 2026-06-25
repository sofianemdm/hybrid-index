import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";

/**
 * #3 — Profil Express en Rx vs non-Rx (Scaled). Un effort « Scaled » (mouvements adaptés) doit donner
 * un sous-score LÉGÈREMENT plus bas (décote 0.9 côté score-service). e2e réel.
 */
describe("api — Profil Express Rx vs Scaled (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();
  const email = `e2e_scaled_${stamp}@test.local`;
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
      .send({ email, password: "motdepasse123", displayName: `Scaled${stamp}`, dateOfBirth: "1995-05-10", sex: "male", goal: "hyrox" })
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

  it("le même temps en Scaled donne un sous-score décoté (~0.9) vs Rx", async () => {
    const log = (rxCompliant: boolean) =>
      request(api.getHttpServer())
        .post("/v1/wods/profil_express/results")
        .set("authorization", `Bearer ${token}`)
        .send({ rawResult: 300, rxCompliant })
        .expect(201);

    await log(true); // Rx
    await log(false); // Scaled (même temps)

    const rows = await prisma.wodResult.findMany({
      where: { userId, wodId: "profil_express", subScore: { not: null } },
      orderBy: { createdAt: "asc" },
      select: { subScore: true, rxCompliant: true },
    });
    expect(rows.length).toBe(2);
    const rx = rows.find((r) => r.rxCompliant)!;
    const scaled = rows.find((r) => !r.rxCompliant)!;
    expect(rx.subScore).toBeGreaterThan(0);
    expect(scaled.subScore).toBe(Math.round(rx.subScore! * 0.9)); // décote appliquée
    expect(scaled.subScore!).toBeLessThan(rx.subScore!);
  });
});
