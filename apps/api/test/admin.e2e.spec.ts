import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

/** Panneau admin : accès réservé à la whitelist ADMIN_EMAILS (401 sans token, 403 non-admin,
 *  200 admin) ; overview/visits cohérents avec SA cohorte (suites parallèles) ; le middleware
 *  de visites journalise les requêtes API avec IP et user. E2E réel sur Postgres. */
describe("api — panneau admin (e2e réel)", () => {
  let api: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();
  const adminEmail = `e2e_admin_${stamp}@test.local`;
  const userEmail = `e2e_admin_user_${stamp}@test.local`;
  let adminToken = "";
  let userToken = "";
  let adminId = "";
  let userId = "";
  const prevAdminEmails = process.env.ADMIN_EMAILS;

  beforeAll(async () => {
    process.env.ADMIN_EMAILS = ` ${adminEmail.toUpperCase()} , autre@exemple.fr `; // casse + espaces tolérés
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();
    prisma = new PrismaClient();

    const register = (email: string, name: string) =>
      request(api.getHttpServer())
        .post("/v1/auth/register")
        .send({ email, password: "motdepasse123", displayName: name, dateOfBirth: "1995-05-10", sex: "male", goal: "hyrox" })
        .expect(201);
    const reg1 = await register(adminEmail, `Admin${stamp}`);
    adminToken = reg1.body.token;
    adminId = reg1.body.user.id;
    const reg2 = await register(userEmail, `Membre${stamp}`);
    userToken = reg2.body.token;
    userId = reg2.body.user.id;
  });

  afterAll(async () => {
    process.env.ADMIN_EMAILS = prevAdminEmails;
    await prisma.visitLog.deleteMany({ where: { userId: { in: [adminId, userId].filter(Boolean) } } }).catch(() => undefined);
    await prisma.user.deleteMany({ where: { id: { in: [adminId, userId].filter(Boolean) } } }).catch(() => undefined);
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
  });

  it("sans token → 401 UNAUTHENTICATED", async () => {
    const res = await request(api.getHttpServer()).get("/v1/admin/overview").expect(401);
    expect(res.body.error?.code).toBe("UNAUTHENTICATED");
  });

  it("token valide mais email hors whitelist → 403 (générique, pas d'oracle)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/admin/overview")
      .set("authorization", `Bearer ${userToken}`)
      .expect(403);
    expect(res.body.error?.code).toBe("FORBIDDEN");
  });

  it("email whitelisté → 200 avec les blocs de KPIs attendus", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/admin/overview")
      .set("authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.users.total).toBeGreaterThanOrEqual(2);
    expect(res.body.users.new7d).toBeGreaterThanOrEqual(2); // notre cohorte vient d'être créée
    for (const key of ["users", "visits", "sessions", "posts", "clubs", "push", "feedbacks", "notifications"]) {
      expect(res.body).toHaveProperty(key);
    }
  });

  it("le middleware journalise les requêtes : IP présente + user résolu, et lastLoginAt est posé", async () => {
    // La requête authentifiée du test précédent a dû être journalisée (write async → petite attente).
    await new Promise((r) => setTimeout(r, 300));
    const res = await request(api.getHttpServer())
      .get(`/v1/admin/visits?userId=${adminId}&limit=10`)
      .set("authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.entries.length).toBeGreaterThanOrEqual(1);
    const entry = res.body.entries[0];
    expect(entry.ip).toBeTruthy();
    expect(entry.userId).toBe(adminId);
    expect(entry.userEmail).toBe(adminEmail);

    const admin = await prisma.user.findUnique({ where: { id: adminId }, select: { lastLoginAt: true } });
    expect(admin?.lastLoginAt).not.toBeNull();
  });

  it("visitors : visiteurs uniques par IP du jour — notre IP de test présente avec compteur et dernier user", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/admin/visitors?days=1&limit=200")
      .set("authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.totalUniqueIps).toBeGreaterThanOrEqual(1);
    expect(res.body.entries.length).toBeGreaterThanOrEqual(1);
    const e = res.body.entries[0];
    expect(e.ip).toBeTruthy();
    expect(e.hits).toBeGreaterThanOrEqual(1);
    expect(e.firstSeen).toBeTruthy();
    expect(e.lastSeen).toBeTruthy();
    // Nos requêtes authentifiées viennent de la même IP → le dernier user connu est renseigné.
    expect(e.lastUserEmail).toBeTruthy();
  });

  it("filtre visits par IP inexistante → liste vide (pas d'erreur)", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/admin/visits?ip=203.0.113.99")
      .set("authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.entries).toEqual([]);
    expect(res.body.nextCursor).toBeNull();
  });

  it("users : recherche par email retrouve SA cohorte avec Index /100 nullable", async () => {
    const res = await request(api.getHttpServer())
      .get(`/v1/admin/users?q=e2e_admin_user_${stamp}`)
      .set("authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.entries).toHaveLength(1);
    const u = res.body.entries[0];
    expect(u.userId).toBe(userId);
    expect(u.index).toBeNull(); // pas encore de séance → pas d'Index
    expect(u.sessions).toBe(0);
  });

  it("users/:id : fiche détaillée complète ; id inconnu → 404", async () => {
    const res = await request(api.getHttpServer())
      .get(`/v1/admin/users/${userId}`)
      .set("authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.profile.displayName).toBe(`Membre${stamp}`);
    expect(res.body.counts.sessions).toBe(0);
    await request(api.getHttpServer())
      .get("/v1/admin/users/00000000-0000-0000-0000-000000000000")
      .set("authorization", `Bearer ${adminToken}`)
      .expect(404);
  });

  it("timeseries : 30 points datés, le jour courant compte nos 2 inscriptions", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/admin/timeseries?days=30")
      .set("authorization", `Bearer ${adminToken}`)
      .expect(200);
    expect(res.body.series).toHaveLength(30);
    const today = res.body.series[res.body.series.length - 1];
    expect(today.day).toBe(new Date().toISOString().slice(0, 10));
    expect(today.signups).toBeGreaterThanOrEqual(2);
  });
});
