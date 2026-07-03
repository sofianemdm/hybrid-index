import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { MailService } from "../src/infra/mail/mail.service";

/**
 * « Mot de passe oublié » (e2e réel, base de test dédiée) :
 *  (a) forgot → toujours { ok: true }, même pour un email inconnu (pas d'énumération) ;
 *  (b) le code capturé (MailService stubé) permet de définir un nouveau mot de passe ;
 *  (c) l'ancien mot de passe ne marche plus, le nouveau si ;
 *  (d) le code est à usage unique (rejouer → RESET_INVALID) ;
 *  (e) un code faux est refusé, et 5 essais faux brûlent le code (anti brute-force).
 * Pas de score-service : le flux auth n'en dépend pas.
 */
jest.setTimeout(60000);

describe("api — mot de passe oublié (e2e réel)", () => {
  let api: INestApplication;
  let prisma: PrismaClient;
  /** Dernier code envoyé, capturé à la place de l'envoi réel. */
  let lastCode: string | null = null;
  let lastTo: string | null = null;

  const stamp = Date.now();
  const email = `e2e_reset_${stamp}@test.local`;
  const oldPassword = "ancienmdp123";
  const newPassword = "nouveaumdp456";

  const register = () =>
    request(api.getHttpServer()).post("/v1/auth/register").send({
      email,
      password: oldPassword,
      displayName: `Reset${stamp % 100000}`,
      dateOfBirth: "1990-01-01",
      sex: "male",
    });

  beforeAll(async () => {
    const { AppModule } = await import("../src/app.module");
    const { configureApp } = await import("../src/app.config");
    const apiRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(MailService)
      .useValue({
        sendPasswordResetCode: async (to: string, code: string) => {
          lastTo = to;
          lastCode = code;
        },
        send: async () => undefined,
      })
      .compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();
    prisma = new PrismaClient();
    await register().expect(201);
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } }).catch(() => undefined);
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
  });

  it("forgot : { ok: true } même pour un email inconnu, et aucun code émis", async () => {
    lastCode = null;
    const res = await request(api.getHttpServer())
      .post("/v1/auth/forgot")
      .send({ email: `inconnu_${stamp}@test.local` })
      .expect(201);
    expect(res.body).toEqual({ ok: true });
    expect(lastCode).toBeNull();
  });

  it("forgot : émet un code à 6 chiffres pour un compte existant", async () => {
    const res = await request(api.getHttpServer()).post("/v1/auth/forgot").send({ email }).expect(201);
    expect(res.body).toEqual({ ok: true });
    expect(lastTo).toBe(email);
    expect(lastCode).toMatch(/^\d{6}$/);
  });

  it("reset : un code FAUX est refusé (RESET_INVALID), sans brûler le bon", async () => {
    const wrong = lastCode === "000000" ? "000001" : "000000";
    const res = await request(api.getHttpServer())
      .post("/v1/auth/reset")
      .send({ email, code: wrong, newPassword })
      .expect(400);
    expect(res.body.error.code).toBe("RESET_INVALID");
  });

  it("reset : le bon code définit le nouveau mot de passe", async () => {
    await request(api.getHttpServer())
      .post("/v1/auth/reset")
      .send({ email, code: lastCode, newPassword })
      .expect(201);
    // Ancien mot de passe → refusé ; nouveau → accepté.
    await request(api.getHttpServer()).post("/v1/auth/login").send({ email, password: oldPassword }).expect(401);
    const login = await request(api.getHttpServer())
      .post("/v1/auth/login")
      .send({ email, password: newPassword })
      .expect(201);
    expect(login.body.token).toBeTruthy();
  });

  it("reset : le code est à usage unique (rejeu → RESET_INVALID)", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/auth/reset")
      .send({ email, code: lastCode, newPassword: "encoreun789" })
      .expect(400);
    expect(res.body.error.code).toBe("RESET_INVALID");
  });

  it("anti brute-force : 5 essais faux brûlent le code, même donné juste ensuite", async () => {
    // Nouveau code (cooldown 60 s : on purge la rangée précédente pour re-demander tout de suite).
    const user = await prisma.user.findUnique({ where: { email }, select: { id: true } });
    await prisma.passwordResetCode.deleteMany({ where: { userId: user!.id } });
    await request(api.getHttpServer()).post("/v1/auth/forgot").send({ email }).expect(201);
    const good = lastCode!;
    const wrong = good === "000000" ? "000001" : "000000";
    for (let i = 0; i < 5; i++) {
      await request(api.getHttpServer())
        .post("/v1/auth/reset")
        .send({ email, code: wrong, newPassword: "bruteforce123" })
        .expect(400);
    }
    // Le BON code est désormais refusé : le compteur d'essais a tué la rangée.
    const res = await request(api.getHttpServer())
      .post("/v1/auth/reset")
      .send({ email, code: good, newPassword: "bruteforce123" })
      .expect(400);
    expect(res.body.error.code).toBe("RESET_INVALID");
    // Et le mot de passe légitime précédent fonctionne toujours.
    await request(api.getHttpServer()).post("/v1/auth/login").send({ email, password: newPassword }).expect(201);
  });
});
