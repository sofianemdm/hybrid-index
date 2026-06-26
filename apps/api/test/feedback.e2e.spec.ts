import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

/** Signalement de bug (bouton « Signaler un bug », bêta) : POST /v1/feedback authentifié
 *  persiste le message en base ; validation et auth couvertes (e2e réel sur Postgres). */
describe("api — feedback / signalement de bug (e2e réel)", () => {
  let api: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();
  const email = `e2e_feedback_${stamp}@test.local`;
  let token = "";
  let userId = "";

  beforeAll(async () => {
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();
    prisma = new PrismaClient();

    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email,
        password: "motdepasse123",
        displayName: `Feedback${stamp}`,
        dateOfBirth: "1995-05-10",
        sex: "male",
        goal: "hyrox",
      })
      .expect(201);
    token = reg.body.token;
    userId = reg.body.user.id;
  });

  afterAll(async () => {
    if (userId) {
      await prisma.feedback.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
  });

  it("POST authentifié → 201, { ok, id } et ligne créée en base", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/feedback")
      .set("authorization", `Bearer ${token}`)
      .send({ message: "bug X", context: "ecran=accueil; platform=android; v=1.0.0" })
      .expect(201);

    expect(res.body).toMatchObject({ ok: true });
    expect(typeof res.body.id).toBe("string");

    const row = await prisma.feedback.findUnique({ where: { id: res.body.id } });
    expect(row).not.toBeNull();
    expect(row?.userId).toBe(userId);
    expect(row?.message).toBe("bug X");
    expect(row?.context).toBe("ecran=accueil; platform=android; v=1.0.0");
  });

  it("context optionnel : message seul → 201 + context null en base", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/feedback")
      .set("authorization", `Bearer ${token}`)
      .send({ message: "autre bug sans contexte" })
      .expect(201);

    const row = await prisma.feedback.findUnique({ where: { id: res.body.id } });
    expect(row?.context).toBeNull();
  });

  it("message trop court → 400 VALIDATION_ERROR", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/feedback")
      .set("authorization", `Bearer ${token}`)
      .send({ message: "ab" })
      .expect(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("message vide → 400 VALIDATION_ERROR", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/feedback")
      .set("authorization", `Bearer ${token}`)
      .send({ message: "" })
      .expect(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("sans auth → 401", async () => {
    await request(api.getHttpServer()).post("/v1/feedback").send({ message: "bug sans token" }).expect(401);
  });
});
