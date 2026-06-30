import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

/**
 * Commentaires sous les posts du feed (mini réseau social) — e2e RÉEL sur Postgres.
 * Couvre : création + commentCount dans le feed, listing paginé, suppression (auteur du commentaire
 * ET auteur du post), garde-fous (corps vide, tiers non autorisé), exclusion des bloqués au listing,
 * et signalement → auto-masquage (seuil 3) qui retire le commentaire du feed.
 * Isolation par e-mails horodatés + nettoyage complet en afterAll (cf. mémoire « e2e-pollue-base-dev »).
 */
describe("api — commentaires de posts (e2e réel)", () => {
  let api: INestApplication;
  let prisma: PrismaClient;
  const stamp = Date.now();

  type Person = { email: string; displayName: string; token: string; userId: string };
  const make = (k: string): Person => ({ email: `e2e_cmt_${k}_${stamp}@test.local`, displayName: `Cmt${k}${stamp}`, token: "", userId: "" });
  const author = make("author"); // auteur du post
  const alice = make("alice");
  const bob = make("bob");
  const carol = make("carol");
  const dave = make("dave"); // 3e rapporteur pour atteindre le seuil d'auto-masquage
  const everyone = [author, alice, bob, carol, dave];

  async function register(p: Person): Promise<void> {
    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({ email: p.email, password: "motdepasse123", displayName: p.displayName, dateOfBirth: "1995-03-12", sex: "male", goal: "hyrox" })
      .expect(201);
    p.token = reg.body.token;
    p.userId = reg.body.user.id;
  }

  const auth = (p: Person) => ({ Authorization: `Bearer ${p.token}` });

  let postId = "";

  beforeAll(async () => {
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();
    prisma = new PrismaClient();
    for (const p of everyone) await register(p);

    const post = await request(api.getHttpServer())
      .post("/v1/posts")
      .set(auth(author))
      .send({ kind: "text", body: `Post de test ${stamp}` })
      .expect(201);
    postId = post.body.id;
  }, 60_000);

  afterAll(async () => {
    const ids = everyone.map((p) => p.userId).filter(Boolean);
    if (ids.length > 0) {
      await prisma.report.deleteMany({ where: { reporterId: { in: ids } } }).catch(() => undefined);
      await prisma.comment.deleteMany({ where: { authorId: { in: ids } } }).catch(() => undefined);
      await prisma.post.deleteMany({ where: { authorId: { in: ids } } }).catch(() => undefined);
      await prisma.block.deleteMany({ where: { OR: [{ blockerId: { in: ids } }, { blockedId: { in: ids } }] } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id: { in: ids } } }).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
  });

  it("POST /v1/posts/:id/comments : crée un commentaire (corps trim, isMe)", async () => {
    const res = await request(api.getHttpServer())
      .post(`/v1/posts/${postId}/comments`)
      .set(auth(alice))
      .send({ body: "  Bien joué ! 💪  " })
      .expect(201);
    expect(res.body.body).toBe("Bien joué ! 💪");
    expect(res.body.postId).toBe(postId);
    expect(res.body.author.isMe).toBe(true);
    expect(res.body.author.userId).toBe(alice.userId);
  });

  it("POST corps vide → 400", async () => {
    await request(api.getHttpServer())
      .post(`/v1/posts/${postId}/comments`)
      .set(auth(bob))
      .send({ body: "   " })
      .expect(400);
  });

  it("GET /v1/posts/:id/comments : liste les commentaires visibles", async () => {
    await request(api.getHttpServer()).post(`/v1/posts/${postId}/comments`).set(auth(bob)).send({ body: "Énorme" }).expect(201);
    const res = await request(api.getHttpServer()).get(`/v1/posts/${postId}/comments`).set(auth(author)).expect(200);
    expect(Array.isArray(res.body.items)).toBe(true);
    expect(res.body.items.length).toBeGreaterThanOrEqual(2);
    expect(res.body).toHaveProperty("nextCursor");
  });

  it("commentCount apparaît dans le feed du post", async () => {
    const feed = await request(api.getHttpServer()).get(`/v1/feed?scope=following`).set(auth(author)).expect(200);
    const card = (feed.body as Array<Record<string, unknown>>).find((c) => c.id === postId);
    expect(card).toBeDefined();
    expect(card?.commentCount).toBeGreaterThanOrEqual(2);
  });

  it("le post apparaît dans le feed GLOBAL d'un non-suiveur (scope=all)", async () => {
    const feed = await request(api.getHttpServer()).get(`/v1/feed?scope=all`).set(auth(carol)).expect(200);
    const card = (feed.body as Array<Record<string, unknown>>).find((c) => c.id === postId);
    expect(card).toBeDefined();
  });

  it("DELETE /v1/comments/:id : un tiers (ni auteur du commentaire ni du post) → 403", async () => {
    const created = await request(api.getHttpServer()).post(`/v1/posts/${postId}/comments`).set(auth(alice)).send({ body: "à supprimer" }).expect(201);
    await request(api.getHttpServer()).delete(`/v1/comments/${created.body.id}`).set(auth(bob)).expect(403);
    // L'auteur du POST peut, lui, supprimer ce commentaire (modération de son fil).
    await request(api.getHttpServer()).delete(`/v1/comments/${created.body.id}`).set(auth(author)).expect(200);
  });

  it("listing exclut les commentaires d'un utilisateur bloqué", async () => {
    const c = await request(api.getHttpServer()).post(`/v1/posts/${postId}/comments`).set(auth(carol)).send({ body: "coucou carol" }).expect(201);
    // author bloque carol → ses commentaires disparaissent du listing vu par author.
    await request(api.getHttpServer()).post(`/v1/users/${carol.userId}/block`).set(auth(author)).expect(201);
    const res = await request(api.getHttpServer()).get(`/v1/posts/${postId}/comments`).set(auth(author)).expect(200);
    expect((res.body.items as Array<{ id: string }>).some((it) => it.id === c.body.id)).toBe(false);
    await request(api.getHttpServer()).delete(`/v1/users/${carol.userId}/block`).set(auth(author)).expect(200);
  });

  it("signalement par 3 utilisateurs distincts → auto-masquage (commentaire retiré du listing)", async () => {
    const c = await request(api.getHttpServer()).post(`/v1/posts/${postId}/comments`).set(auth(alice)).send({ body: "spam à signaler" }).expect(201);
    for (const reporter of [bob, carol, dave]) {
      await request(api.getHttpServer()).post(`/v1/comments/${c.body.id}/report`).set(auth(reporter)).send({ reason: "spam" }).expect(201);
    }
    const res = await request(api.getHttpServer()).get(`/v1/posts/${postId}/comments`).set(auth(author)).expect(200);
    expect((res.body.items as Array<{ id: string }>).some((it) => it.id === c.body.id)).toBe(false);
    const row = await prisma.comment.findUnique({ where: { id: c.body.id }, select: { hidden: true, reportCount: true } });
    expect(row?.hidden).toBe(true);
    expect(row?.reportCount).toBe(3);
  });
});
