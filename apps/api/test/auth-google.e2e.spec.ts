import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";
import { GoogleTokenVerifier } from "../src/modules/auth/google-verifier";

/**
 * Auth Google : on MOCKE la vérification du token (pas de vrai token Google nécessaire) pour
 * tester la logique de provisionnement (login / lien compte / inscription + age-gate).
 * Le idToken de test encode "sub|email".
 */
const stubVerifier = {
  verify: async (idToken: string) => {
    const [sub, email] = idToken.split("|");
    return { sub, email };
  },
};

describe("api — auth Google (e2e, vérificateur mocké)", () => {
  let app: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();
  const email = `google_${stamp}@test.local`;
  const sub = `g-sub-${stamp}`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(GoogleTokenVerifier)
      .useValue(stubVerifier)
      .compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
    prisma = new PrismaClient();
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [email, `minor_${stamp}@test.local`] } } }).catch(() => undefined);
    await prisma.$disconnect().catch(() => undefined);
    await app?.close();
  });

  it("première connexion sans profil → 400 needsProfile", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/google")
      .send({ idToken: `${sub}|${email}` })
      .expect(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
    expect(res.body.error.details.needsProfile).toBe(true);
  });

  it("première connexion avec profil (adulte) → crée le compte (isNew)", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/google")
      .send({
        idToken: `${sub}|${email}`,
        profile: { displayName: `Goog${stamp}`, dateOfBirth: "1996-04-04", sex: "female", goal: "all_round" },
      })
      .expect(201);
    expect(res.body.token).toBeTruthy();
    expect(res.body.isNew).toBe(true);
  });

  it("connexion suivante (même sub) → login sans profil (isNew=false)", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/google")
      .send({ idToken: `${sub}|${email}` })
      .expect(201);
    expect(res.body.token).toBeTruthy();
    expect(res.body.isNew).toBe(false);
  });

  it("age-gate : nouveau compte Google mineur → 403", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/google")
      .send({
        idToken: `g-sub-minor-${stamp}|minor_${stamp}@test.local`,
        profile: { displayName: `Kid${stamp}`, dateOfBirth: "2016-01-01", sex: "male", goal: "hyrox" },
      })
      .expect(403);
    expect(res.body.error.code).toBe("AGE_RESTRICTED");
  });
});
