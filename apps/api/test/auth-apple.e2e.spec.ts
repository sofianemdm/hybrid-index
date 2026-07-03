import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";
import { AppleTokenVerifier } from "../src/modules/auth/apple-verifier";

/**
 * Auth Apple : on MOCKE la vérification du token (testée unitairement dans apple-verifier.spec)
 * pour vérifier le provisionnement : login / liaison de compte / inscription + age-gate, et la
 * particularité Apple « token de reconnexion SANS email » (l'identité suffit).
 * L'identityToken de test encode "sub|email" ("sub|" = token sans email).
 */
const stubVerifier = {
  verify: async (identityToken: string) => {
    const [sub, email] = identityToken.split("|");
    return { sub, email: email || null };
  },
};

describe("api — auth Apple (e2e, vérificateur mocké)", () => {
  let app: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();
  const email = `apple_${stamp}@privaterelay.test.local`;
  const linkEmail = `apple_link_${stamp}@test.local`;
  const sub = `a-sub-${stamp}`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(AppleTokenVerifier)
      .useValue(stubVerifier)
      .compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
    prisma = new PrismaClient();
  });

  afterAll(async () => {
    await prisma.user
      .deleteMany({ where: { email: { in: [email, linkEmail, `apple_minor_${stamp}@test.local`] } } })
      .catch(() => undefined);
    await prisma.$disconnect().catch(() => undefined);
    await app?.close();
  });

  it("première connexion sans profil → 400 needsProfile", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/apple")
      .send({ identityToken: `${sub}|${email}` })
      .expect(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
    expect(res.body.error.details.needsProfile).toBe(true);
  });

  it("age-gate : mineur de moins de 15 ans → 403 AGE_RESTRICTED", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/apple")
      .send({
        identityToken: `a-minor-${stamp}|apple_minor_${stamp}@test.local`,
        profile: { displayName: `Min${stamp % 100000}`, dateOfBirth: "2015-01-01", sex: "male" },
      })
      .expect(403);
    expect(res.body.error.code).toBe("AGE_RESTRICTED");
  });

  it("première connexion avec profil (adulte) → crée le compte (isNew)", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/apple")
      .send({
        identityToken: `${sub}|${email}`,
        profile: { displayName: `Appl${stamp % 100000}`, dateOfBirth: "1994-02-02", sex: "male" },
      })
      .expect(201);
    expect(res.body.isNew).toBe(true);
    expect(res.body.token).toBeTruthy();
  });

  it("reconnexion SANS email dans le token (cas Apple réel) → connexion via l'identité", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/apple")
      .send({ identityToken: `${sub}|` })
      .expect(201);
    expect(res.body.isNew).toBe(false);
    expect(res.body.user.email).toBe(email);
  });

  it("email déjà inscrit (compte mot de passe) → lie l'identité Apple, sans nouveau compte", async () => {
    await request(app.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email: linkEmail,
        password: "motdepasse123",
        displayName: `Link${stamp % 100000}`,
        dateOfBirth: "1990-01-01",
        sex: "female",
      })
      .expect(201);
    const res = await request(app.getHttpServer())
      .post("/v1/auth/apple")
      .send({ identityToken: `a-link-${stamp}|${linkEmail}` })
      .expect(201);
    expect(res.body.isNew).toBe(false);
    const identities = await prisma.authIdentity.findMany({
      where: { user: { email: linkEmail } },
      select: { provider: true },
    });
    expect(identities.map((i) => i.provider).sort()).toEqual(["apple", "email"]);
  });

  it("identité inconnue ET token sans email → 401 (impossible de créer/lier)", async () => {
    const res = await request(app.getHttpServer())
      .post("/v1/auth/apple")
      .send({ identityToken: `a-ghost-${stamp}|` })
      .expect(401);
    expect(res.body.error.code).toBe("UNAUTHENTICATED");
  });
});
