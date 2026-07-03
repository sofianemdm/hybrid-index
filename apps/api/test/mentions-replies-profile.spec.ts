import { PostsService } from "../src/modules/posts/posts.service";
import { CommentsService } from "../src/modules/posts/comments.service";
import { MentionsService } from "../src/modules/posts/mentions.service";
import { parseMentions, resolveMentions, buildDisplayNameIndex } from "../src/common/mentions.util";

/**
 * MISSION BACKEND 2 — LOT 3 (mur de profil), LOT 4 (réponses/threads 1 niveau), LOT 5 (mentions).
 * Prisma + dépendances mockés ; on cible la logique critique (validation niveau, notif parent,
 * parse/résolution/notif des @pseudo hors auto-mention, blocage, mur respecte blocage/visibilité).
 */

type AnyFn = jest.Mock;

function makePrismaMock() {
  return {
    // $transaction "batch" : exécute les promesses Prisma déjà construites (create/update mockés).
    $transaction: jest.fn((ops: Promise<unknown>[]) => Promise.all(ops)),
    post: { create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), findMany: jest.fn() },
    comment: { create: jest.fn(), findUnique: jest.fn(), findMany: jest.fn(), update: jest.fn(), delete: jest.fn() },
    commentReaction: { findMany: jest.fn().mockResolvedValue([]) },
    postReaction: { findMany: jest.fn().mockResolvedValue([]) },
    wodResult: { findMany: jest.fn().mockResolvedValue([]) },
    profile: { findMany: jest.fn().mockResolvedValue([]) },
  } as unknown as Record<string, Record<string, AnyFn>>; // unknown : $transaction (fn top-level) sort du gabarit table→méthodes
}
const redisOk = { rateLimit: jest.fn().mockResolvedValue(1) };

// ───────────────────────────────────────────────────────────────────────────
describe("LOT 5 — parsing/résolution des mentions (mentions.util)", () => {
  it("parseMentions : capture les @pseudo avec offsets, dé-doublonne (casse/accents)", () => {
    const text = "Bravo @Lea et @max, encore @LEA !";
    const out = parseMentions(text);
    expect(out.map((m) => m.raw)).toEqual(["Lea", "max"]); // @LEA = doublon de @Lea
    expect(out[0].offset).toBe(text.indexOf("@Lea"));
    expect(out[0].length).toBe("@Lea".length);
  });

  it("parseMentions : n'attrape pas une adresse e-mail (a@b)", () => {
    expect(parseMentions("écris à john@example.com")).toEqual([]);
  });

  it("resolveMentions : relie pseudo→userId via l'index (insensible casse/accents)", () => {
    const raw = parseMentions("salut @lea et @bob");
    const index = buildDisplayNameIndex([
      { userId: "u-lea", displayName: "Léa" },
      { userId: "u-bob", displayName: "Bob" },
    ]);
    const resolved = resolveMentions(raw, index);
    expect(resolved.map((m) => [m.pseudo, m.userId])).toEqual([
      ["Léa", "u-lea"],
      ["Bob", "u-bob"],
    ]);
  });
});

describe("LOT 5 — MentionsService.resolve (hors auto-mention + blocage)", () => {
  function makeSvc(prisma: Record<string, Record<string, AnyFn>>, blocked: string[] = []) {
    const moderation = { blockedIds: jest.fn().mockResolvedValue(blocked) };
    const push = { notifyMention: jest.fn().mockResolvedValue(undefined) };
    return { svc: new MentionsService(prisma as never, moderation as never, push as never), push };
  }

  it("résout les @pseudo, EXCLUT l'auto-mention et les utilisateurs bloqués", async () => {
    const prisma = makePrismaMock();
    prisma.profile.findMany.mockResolvedValue([
      { userId: "u-lea", displayName: "Lea" },
      { userId: "me", displayName: "Moi" },
      { userId: "u-blk", displayName: "Blocked" },
    ]);
    const { svc } = makeSvc(prisma, ["u-blk"]);
    const out = await svc.resolve("me", "cc @Lea @Moi @Blocked");
    expect(out.map((m) => m.userId)).toEqual(["u-lea"]); // ni moi, ni le bloqué
  });

  it("renvoie [] quand aucun @ dans le corps (pas de requête profils)", async () => {
    const prisma = makePrismaMock();
    const { svc } = makeSvc(prisma);
    expect(await svc.resolve("me", "aucune mention ici")).toEqual([]);
    expect(prisma.profile.findMany).not.toHaveBeenCalled();
  });

  it("notify : push best-effort à chaque mentionné (un échec ne propage pas)", async () => {
    const prisma = makePrismaMock();
    const moderation = { blockedIds: jest.fn() };
    const push = { notifyMention: jest.fn().mockRejectedValue(new Error("FCM down")) };
    const svc = new MentionsService(prisma as never, moderation as never, push as never);
    await expect(
      svc.notify([{ pseudo: "Lea", userId: "u-lea", offset: 0, length: 4 }], "Moi"),
    ).resolves.toBeUndefined();
    expect(push.notifyMention).toHaveBeenCalledWith("u-lea", "Moi");
  });
});

describe("LOT 5 — mentions au create d'un POST/COMMENTAIRE", () => {
  it("post.create : résout + notifie les mentions, expose `mentions` dans la réponse", async () => {
    const prisma = makePrismaMock();
    prisma.post.create.mockResolvedValue({
      id: "p1",
      kind: "text",
      body: "GG @Lea",
      createdAt: new Date("2026-06-30T10:00:00Z"),
      author: { profile: { displayName: "Moi", rank: "gold" }, hybridIndex: { value: 800 }, avatar: null },
    });
    const moderation = { isBlockedBetween: jest.fn(), isCleanName: jest.fn().mockReturnValue(true), blockedIds: jest.fn() };
    const resolved = [{ pseudo: "Léa", userId: "u-lea", offset: 3, length: 4 }];
    const mentions = { resolve: jest.fn().mockResolvedValue(resolved), notify: jest.fn().mockResolvedValue(undefined), resolveBatch: jest.fn() };
    const svc = new PostsService(prisma as never, moderation as never, {} as never, redisOk as never, mentions as never);

    const res = await svc.create("me", { kind: "text", body: "GG @Lea" });

    expect(mentions.resolve).toHaveBeenCalledWith("me", "GG @Lea");
    expect(mentions.notify).toHaveBeenCalledWith(resolved, "Moi");
    expect(res.mentions).toEqual(resolved);
  });

  it("comment.create : résout + notifie les mentions, expose `mentions`", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ id: "p1", authorId: "author", status: "visible" });
    prisma.comment.create.mockResolvedValue({
      id: "c1", postId: "p1", parentId: null, body: "yo @Bob", authorId: "me",
      createdAt: new Date("2026-06-30T10:00:00Z"), author: { profile: { displayName: "Moi", rank: "gold" }, avatar: null },
    });
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false), isCleanName: jest.fn().mockReturnValue(true) };
    const push = { notifyComment: jest.fn().mockResolvedValue(undefined) };
    const resolved = [{ pseudo: "Bob", userId: "u-bob", offset: 3, length: 4 }];
    const mentions = { resolve: jest.fn().mockResolvedValue(resolved), notify: jest.fn().mockResolvedValue(undefined), resolveBatch: jest.fn() };
    const svc = new CommentsService(prisma as never, moderation as never, push as never, redisOk as never, mentions as never);

    const res = await svc.create("me", "p1", "yo @Bob");

    expect(mentions.notify).toHaveBeenCalledWith(resolved, "Moi");
    expect(res.mentions).toEqual(resolved);
  });
});

describe("LOT 4 — réponses / threads (1 SEUL niveau)", () => {
  const baseComment = (over: Record<string, unknown> = {}) => ({
    id: "c-new", postId: "p1", parentId: null, body: "réponse", authorId: "me",
    createdAt: new Date("2026-06-30T10:05:00Z"), author: { profile: { displayName: "Moi", rank: "gold" }, avatar: null },
    ...over,
  });
  function makeSvc(prisma: Record<string, Record<string, AnyFn>>, push: Record<string, AnyFn>) {
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false), isCleanName: jest.fn().mockReturnValue(true) };
    const mentions = { resolve: jest.fn().mockResolvedValue([]), notify: jest.fn(), resolveBatch: jest.fn().mockResolvedValue(new Map()) };
    return new CommentsService(prisma as never, moderation as never, push as never, redisOk as never, mentions as never);
  }

  it("réponse à une RACINE : crée avec parentId, incrémente replyCount, notifie l'auteur parent", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ id: "p1", authorId: "poster", status: "visible" });
    prisma.comment.findUnique.mockResolvedValue({ id: "root1", postId: "p1", parentId: null, hidden: false, authorId: "parentAuthor" });
    prisma.comment.create.mockResolvedValue(baseComment({ parentId: "root1" }));
    prisma.comment.update.mockResolvedValue({});
    const push = { notifyCommentReply: jest.fn().mockResolvedValue(undefined), notifyComment: jest.fn() };

    const res = await makeSvc(prisma, push).create("me", "p1", "réponse", "root1");

    expect(prisma.comment.create.mock.calls[0][0].data.parentId).toBe("root1");
    expect(prisma.comment.update).toHaveBeenCalledWith({ where: { id: "root1" }, data: { replyCount: { increment: 1 } } });
    expect(push.notifyCommentReply).toHaveBeenCalledWith("parentAuthor", "Moi");
    expect(push.notifyComment).not.toHaveBeenCalled(); // pas la notif « commentaire racine »
    expect(res.parentId).toBe("root1");
  });

  it("REFUSE de répondre à une RÉPONSE (niveau 2) → erreur, pas de create", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ id: "p1", authorId: "poster", status: "visible" });
    prisma.comment.findUnique.mockResolvedValue({ id: "reply1", postId: "p1", parentId: "root1", hidden: false, authorId: "x" });
    const push = { notifyCommentReply: jest.fn(), notifyComment: jest.fn() };

    await expect(makeSvc(prisma, push).create("me", "p1", "niveau 2", "reply1")).rejects.toThrow();
    expect(prisma.comment.create).not.toHaveBeenCalled();
  });

  it("REFUSE un parent d'un AUTRE post → NOT_FOUND, pas de create", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ id: "p1", authorId: "poster", status: "visible" });
    prisma.comment.findUnique.mockResolvedValue({ id: "root1", postId: "AUTRE", parentId: null, hidden: false, authorId: "x" });
    const push = { notifyCommentReply: jest.fn(), notifyComment: jest.fn() };

    await expect(makeSvc(prisma, push).create("me", "p1", "x", "root1")).rejects.toThrow();
    expect(prisma.comment.create).not.toHaveBeenCalled();
  });

  it("list() : imbrique les réponses sous leur racine + replyCount/parentId", async () => {
    const prisma = makePrismaMock();
    // 1er findMany = racines ; 2e findMany = réponses.
    prisma.comment.findMany
      .mockResolvedValueOnce([
        { id: "root1", postId: "p1", parentId: null, body: "racine", authorId: "u2", createdAt: new Date("2026-06-30T10:00:00Z"), reactionCount: 0, replyCount: 1, author: { profile: { displayName: "Léa", rank: "gold" }, avatar: null } },
      ])
      .mockResolvedValueOnce([
        { id: "rep1", postId: "p1", parentId: "root1", body: "ma réponse", authorId: "u3", createdAt: new Date("2026-06-30T10:01:00Z"), reactionCount: 0, replyCount: 0, author: { profile: { displayName: "Max", rank: "silver" }, avatar: null } },
      ]);
    const moderation = { blockedIds: jest.fn().mockResolvedValue([]) };
    const mentions = { resolveBatch: jest.fn().mockResolvedValue(new Map()) };
    const svc = new CommentsService(prisma as never, moderation as never, {} as never, redisOk as never, mentions as never);

    const out = await svc.list("me", "p1");

    expect(out.items).toHaveLength(1); // une seule racine au niveau supérieur
    expect(out.items[0].id).toBe("root1");
    expect(out.items[0].replyCount).toBe(1);
    expect(out.items[0].replies).toHaveLength(1);
    expect(out.items[0].replies[0].id).toBe("rep1");
    expect(out.items[0].replies[0].parentId).toBe("root1");
    // La requête racines filtre bien parentId:null.
    expect(prisma.comment.findMany.mock.calls[0][0].where.parentId).toBeNull();
  });
});

describe("LOT 3 — mur de profil (PostsService.forProfile)", () => {
  function makeSvc(prisma: Record<string, Record<string, AnyFn>>, blocked = false) {
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(blocked), reportedPostIds: jest.fn().mockResolvedValue([]) };
    const mentions = { resolveBatch: jest.fn().mockResolvedValue(new Map()) };
    return new PostsService(prisma as never, moderation as never, {} as never, redisOk as never, mentions as never);
  }

  it("renvoie les posts de l'auteur (visibles/publics) avec curseur", async () => {
    const prisma = makePrismaMock();
    prisma.post.findMany.mockResolvedValue([
      { id: "p1", kind: "text", body: "salut", wodResultId: null, authorId: "author", createdAt: new Date("2026-06-30T10:00:00Z"), author: { profile: { displayName: "Léa", rank: "gold" }, hybridIndex: { value: 800 }, avatar: null }, _count: { reactions: 0, comments: 0 } },
    ]);
    const out = await makeSvc(prisma).forProfile("author", "me", 20);
    expect(out.items).toHaveLength(1);
    expect(out.nextCursor).toBeNull();
    const where = prisma.post.findMany.mock.calls[0][0].where;
    expect(where.authorId).toBe("author");
    expect(where.status).toBe("visible");
    expect(where.visibility).toBe("public");
  });

  it("blocage bidirectionnel : mur VIDE, aucune requête de posts", async () => {
    const prisma = makePrismaMock();
    const out = await makeSvc(prisma, true).forProfile("author", "me", 20);
    expect(out).toEqual({ items: [], nextCursor: null });
    expect(prisma.post.findMany).not.toHaveBeenCalled();
  });

  it("nextCursor renseigné quand il reste une page (take+1)", async () => {
    const prisma = makePrismaMock();
    // forProfile(take=1) → lit 2 ; on en renvoie 1 + curseur = id du dernier rendu.
    prisma.post.findMany.mockResolvedValue([
      { id: "p1", kind: "text", body: "a", wodResultId: null, authorId: "author", createdAt: new Date("2026-06-30T10:00:00Z"), author: { profile: { displayName: "L", rank: "gold" }, hybridIndex: null, avatar: null }, _count: { reactions: 0, comments: 0 } },
      { id: "p2", kind: "text", body: "b", wodResultId: null, authorId: "author", createdAt: new Date("2026-06-30T09:00:00Z"), author: { profile: { displayName: "L", rank: "gold" }, hybridIndex: null, avatar: null }, _count: { reactions: 0, comments: 0 } },
    ]);
    const out = await makeSvc(prisma).forProfile("author", "me", 1);
    expect(out.items).toHaveLength(1);
    expect(out.items[0].id).toBe("p1");
    expect(out.nextCursor).toBe("p1");
  });
});
