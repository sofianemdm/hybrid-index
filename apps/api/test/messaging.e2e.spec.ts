import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

/**
 * Sécurité de la messagerie privée (DM) — flux non couvert par l'audit.
 * Couvre : éligibilité, envoi entre comptes éligibles, refus en cas de blocage (les deux sens),
 * age-gating (séparation stricte mineurs/adultes), marquage `readAt` à l'ouverture,
 * et refus d'envoi à soi-même / à un compte inexistant / corps vide.
 * Test e2e RÉEL sur Postgres : isolation par e-mails horodatés + nettoyage complet en afterAll
 * (cf. mémoire « e2e-pollue-base-dev » : on ne laisse aucun user/conversation/message orphelin).
 */
describe("api — messagerie privée / sécurité DM (e2e réel)", () => {
  let api: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();

  // Trois adultes (même tranche d'âge) + un mineur, pour couvrir blocage et age-gating.
  type Person = { email: string; displayName: string; token: string; userId: string; dateOfBirth: string };
  const alice: Person = { email: `e2e_dm_alice_${stamp}@test.local`, displayName: `DmAlice${stamp}`, token: "", userId: "", dateOfBirth: "1995-03-12" };
  const bob: Person = { email: `e2e_dm_bob_${stamp}@test.local`, displayName: `DmBob${stamp}`, token: "", userId: "", dateOfBirth: "1992-08-01" };
  const carol: Person = { email: `e2e_dm_carol_${stamp}@test.local`, displayName: `DmCarol${stamp}`, token: "", userId: "", dateOfBirth: "1990-01-05" };
  // Mineur : né il y a ~15 ans (toujours < 18 ans à la date du test).
  const minorYear = new Date().getFullYear() - 15;
  const teen: Person = { email: `e2e_dm_teen_${stamp}@test.local`, displayName: `DmTeen${stamp}`, token: "", userId: "", dateOfBirth: `${minorYear}-06-15` };

  const everyone = [alice, bob, carol, teen];

  async function register(p: Person): Promise<void> {
    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({
        email: p.email,
        password: "motdepasse123",
        displayName: p.displayName,
        dateOfBirth: p.dateOfBirth,
        sex: "male",
        goal: "hyrox",
      })
      .expect(201);
    p.token = reg.body.token;
    p.userId = reg.body.user.id;
  }

  beforeAll(async () => {
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();
    prisma = new PrismaClient();
    for (const p of everyone) {
      await register(p);
    }
  }, 60_000);

  afterAll(async () => {
    const ids = everyone.map((p) => p.userId).filter(Boolean);
    if (ids.length > 0) {
      // Ordre : messages → conversations → blocks → users (FK).
      const convs = await prisma.conversation
        .findMany({ where: { OR: [{ userAId: { in: ids } }, { userBId: { in: ids } }] }, select: { id: true } })
        .catch(() => [] as { id: string }[]);
      const convIds = convs.map((c) => c.id);
      if (convIds.length > 0) {
        await prisma.message.deleteMany({ where: { conversationId: { in: convIds } } }).catch(() => undefined);
        await prisma.conversation.deleteMany({ where: { id: { in: convIds } } }).catch(() => undefined);
      }
      await prisma.block.deleteMany({ where: { OR: [{ blockerId: { in: ids } }, { blockedId: { in: ids } }] } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id: { in: ids } } }).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
  });

  it("can-dm entre deux adultes éligibles → allowed:true", async () => {
    const res = await request(api.getHttpServer())
      .get(`/v1/users/${bob.userId}/can-dm`)
      .set("authorization", `Bearer ${alice.token}`)
      .expect(200);
    expect(res.body).toMatchObject({ allowed: true });
  });

  it("envoi entre deux comptes éligibles → 201, message créé, isMine:true, readAt:null", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/messages")
      .set("authorization", `Bearer ${alice.token}`)
      .send({ toUserId: bob.userId, body: "Salut Bob !" })
      .expect(201);

    expect(typeof res.body.conversationId).toBe("string");
    expect(res.body.message).toMatchObject({ body: "Salut Bob !", senderId: alice.userId, isMine: true, readAt: null });

    const row = await prisma.message.findUnique({ where: { id: res.body.message.id } });
    expect(row).not.toBeNull();
    expect(row?.senderId).toBe(alice.userId);
    expect(row?.readAt).toBeNull();
  });

  it("ouverture de la conversation par le destinataire → marque readAt (accusé de lecture)", async () => {
    // Bob liste ses conversations puis ouvre celle d'Alice.
    const convList = await request(api.getHttpServer())
      .get("/v1/conversations")
      .set("authorization", `Bearer ${bob.token}`)
      .expect(200);
    const conv = convList.body.find((c: { other: { userId: string } }) => c.other.userId === alice.userId);
    expect(conv).toBeDefined();
    expect(conv.unread).toBeGreaterThanOrEqual(1);

    const opened = await request(api.getHttpServer())
      .get(`/v1/conversations/${conv.id}/messages`)
      .set("authorization", `Bearer ${bob.token}`)
      .expect(200);
    expect(opened.body.messages.length).toBeGreaterThanOrEqual(1);
    // Le message d'Alice n'est PAS de Bob, et doit être marqué lu après ouverture.
    const aliceMsg = opened.body.messages.find((m: { senderId: string }) => m.senderId === alice.userId);
    expect(aliceMsg.isMine).toBe(false);

    // En base : readAt renseigné pour les messages reçus par Bob.
    const unreadForBob = await prisma.message.count({
      where: { conversation: { OR: [{ userAId: bob.userId }, { userBId: bob.userId }] }, senderId: alice.userId, readAt: null },
    });
    expect(unreadForBob).toBe(0);
  });

  it("refus si l'EXPÉDITEUR a bloqué le destinataire → 403 DM_NOT_ALLOWED + can-dm:false(blocked)", async () => {
    // Carol bloque Alice.
    await request(api.getHttpServer())
      .post(`/v1/users/${alice.userId}/block`)
      .set("authorization", `Bearer ${carol.token}`)
      .expect(201);

    const elig = await request(api.getHttpServer())
      .get(`/v1/users/${alice.userId}/can-dm`)
      .set("authorization", `Bearer ${carol.token}`)
      .expect(200);
    expect(elig.body).toMatchObject({ allowed: false, reason: "blocked" });

    const res = await request(api.getHttpServer())
      .post("/v1/messages")
      .set("authorization", `Bearer ${carol.token}`)
      .send({ toUserId: alice.userId, body: "tentative bloquée" })
      .expect(403);
    expect(res.body.error.code).toBe("DM_NOT_ALLOWED");
  });

  it("refus DANS L'AUTRE SENS : la cible (Alice) ne peut pas écrire à qui l'a bloquée (Carol) → 403", async () => {
    const elig = await request(api.getHttpServer())
      .get(`/v1/users/${carol.userId}/can-dm`)
      .set("authorization", `Bearer ${alice.token}`)
      .expect(200);
    expect(elig.body).toMatchObject({ allowed: false, reason: "blocked" });

    const res = await request(api.getHttpServer())
      .post("/v1/messages")
      .set("authorization", `Bearer ${alice.token}`)
      .send({ toUserId: carol.userId, body: "réponse impossible" })
      .expect(403);
    expect(res.body.error.code).toBe("DM_NOT_ALLOWED");
  });

  it("age-gating : un adulte ne peut pas écrire à un mineur (et inversement) → reason:age + 403", async () => {
    const elig = await request(api.getHttpServer())
      .get(`/v1/users/${teen.userId}/can-dm`)
      .set("authorization", `Bearer ${alice.token}`)
      .expect(200);
    expect(elig.body).toMatchObject({ allowed: false, reason: "age" });

    await request(api.getHttpServer())
      .post("/v1/messages")
      .set("authorization", `Bearer ${alice.token}`)
      .send({ toUserId: teen.userId, body: "interdit (mineur)" })
      .expect(403);

    // Sens inverse : le mineur non plus.
    const eligInv = await request(api.getHttpServer())
      .get(`/v1/users/${alice.userId}/can-dm`)
      .set("authorization", `Bearer ${teen.token}`)
      .expect(200);
    expect(eligInv.body).toMatchObject({ allowed: false, reason: "age" });
  });

  it("refus d'envoi à soi-même → 403 (reason self)", async () => {
    const elig = await request(api.getHttpServer())
      .get(`/v1/users/${alice.userId}/can-dm`)
      .set("authorization", `Bearer ${alice.token}`)
      .expect(200);
    expect(elig.body).toMatchObject({ allowed: false, reason: "self" });

    await request(api.getHttpServer())
      .post("/v1/messages")
      .set("authorization", `Bearer ${alice.token}`)
      .send({ toUserId: alice.userId, body: "à moi-même" })
      .expect(403);
  });

  it("refus d'envoi à un utilisateur inexistant → 403 DM_NOT_ALLOWED (not_connected)", async () => {
    const ghost = "00000000-0000-4000-8000-000000000000";
    const res = await request(api.getHttpServer())
      .post("/v1/messages")
      .set("authorization", `Bearer ${bob.token}`)
      .send({ toUserId: ghost, body: "fantôme" })
      .expect(403);
    expect(res.body.error.code).toBe("DM_NOT_ALLOWED");
  });

  it("corps vide → 400 VALIDATION_ERROR (Zod, body.min(1))", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/messages")
      .set("authorization", `Bearer ${bob.token}`)
      .send({ toUserId: alice.userId, body: "" })
      .expect(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });

  it("sans auth → 401", async () => {
    await request(api.getHttpServer())
      .post("/v1/messages")
      .send({ toUserId: bob.userId, body: "no token" })
      .expect(401);
  });

  // ─── Pagination par curseur (charger les messages précédents) ──────────────
  it("pagination : page récente bornée par limit + hasMore/nextBefore, et `before` charge l'antérieur", async () => {
    // Deux acteurs frais (aucun blocage entre eux) pour un fil isolé.
    const pagA: Person = { email: `e2e_dm_pgA_${stamp}@test.local`, displayName: `DmPgA${stamp}`, token: "", userId: "", dateOfBirth: "1991-04-04" };
    const pagB: Person = { email: `e2e_dm_pgB_${stamp}@test.local`, displayName: `DmPgB${stamp}`, token: "", userId: "", dateOfBirth: "1989-09-09" };
    await register(pagA);
    await register(pagB);
    everyone.push(pagA, pagB); // nettoyage en afterAll

    // 12 messages alternés de A (l'envoi crée la conversation au 1er message).
    let convId = "";
    for (let i = 0; i < 12; i++) {
      const r = await request(api.getHttpServer())
        .post("/v1/messages")
        .set("authorization", `Bearer ${pagA.token}`)
        .send({ toUserId: pagB.userId, body: `msg #${i}` })
        .expect(201);
      convId = r.body.conversationId;
    }

    // Page récente (limit=5) : 5 derniers messages, ordre asc, hasMore=true, nextBefore renseigné.
    const recent = await request(api.getHttpServer())
      .get(`/v1/conversations/${convId}/messages?limit=5`)
      .set("authorization", `Bearer ${pagA.token}`)
      .expect(200);
    expect(recent.body.messages.length).toBe(5);
    expect(recent.body.hasMore).toBe(true);
    expect(typeof recent.body.nextBefore).toBe("string");
    // Ordre croissant + ce sont bien les 5 derniers (#7..#11).
    const recentBodies = recent.body.messages.map((m: { body: string }) => m.body);
    expect(recentBodies).toEqual(["msg #7", "msg #8", "msg #9", "msg #10", "msg #11"]);

    // Page antérieure via `before` = nextBefore (id du plus ancien de la page récente) → #2..#6.
    const older = await request(api.getHttpServer())
      .get(`/v1/conversations/${convId}/messages?limit=5&before=${recent.body.nextBefore}`)
      .set("authorization", `Bearer ${pagA.token}`)
      .expect(200);
    expect(older.body.messages.length).toBe(5);
    expect(older.body.hasMore).toBe(true);
    const olderBodies = older.body.messages.map((m: { body: string }) => m.body);
    expect(olderBodies).toEqual(["msg #2", "msg #3", "msg #4", "msg #5", "msg #6"]);

    // Dernière page (#0..#1) → hasMore=false, nextBefore=null.
    const last = await request(api.getHttpServer())
      .get(`/v1/conversations/${convId}/messages?limit=5&before=${older.body.nextBefore}`)
      .set("authorization", `Bearer ${pagA.token}`)
      .expect(200);
    expect(last.body.messages.map((m: { body: string }) => m.body)).toEqual(["msg #0", "msg #1"]);
    expect(last.body.hasMore).toBe(false);
    expect(last.body.nextBefore).toBeNull();

    // `before` inconnu (id étranger) → retombe sur la page la plus récente, sans erreur dure.
    const fallback = await request(api.getHttpServer())
      .get(`/v1/conversations/${convId}/messages?limit=5&before=00000000-0000-0000-0000-000000000000`)
      .set("authorization", `Bearer ${pagA.token}`)
      .expect(200);
    expect(fallback.body.messages.map((m: { body: string }) => m.body)).toEqual(recentBodies);
  });
});
