import { SocialService } from "../src/modules/social/social.service";
import { PostsService } from "../src/modules/posts/posts.service";
import { CommentsService } from "../src/modules/posts/comments.service";
import { ModerationService } from "../src/modules/moderation/moderation.service";

/**
 * Tests de la logique CRITIQUE du chantier « Communauté AAA » avec un Prisma mocké :
 *  - Kudos UNIFIÉ : un seul applaudissement par (item, user), compteur = nb de réactions.
 *  - Repli « Découvrir » : déclenché quand on ne suit personne et que le fil est vide.
 *  - Auto-masquage : un post passe en `hidden` au seuil de rapporteurs DISTINCTS (>= 3).
 */

type AnyFn = jest.Mock;

function makePrismaMock() {
  return {
    feedEvent: { findUnique: jest.fn(), findMany: jest.fn() },
    reaction: { deleteMany: jest.fn(), create: jest.fn(), count: jest.fn() },
    postReaction: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
    post: { findUnique: jest.fn(), update: jest.fn(), findMany: jest.fn(), delete: jest.fn() },
    comment: { create: jest.fn(), findUnique: jest.fn(), findMany: jest.fn(), update: jest.fn(), delete: jest.fn() },
    report: { upsert: jest.fn(), count: jest.fn(), findMany: jest.fn() },
    follow: { findMany: jest.fn(), upsert: jest.fn() },
    profile: { findUnique: jest.fn(), findMany: jest.fn() },
    hybridIndex: { findMany: jest.fn() },
    user: { findFirst: jest.fn() },
  } as Record<string, Record<string, AnyFn>>;
}

describe("Kudos unifié — événements de feed (SocialService)", () => {
  it("react() : efface toute réaction précédente puis pose UN 👏 ; renvoie le compteur + iKudo=true", async () => {
    const prisma = makePrismaMock();
    prisma.feedEvent.findUnique.mockResolvedValue({ actorId: "author" });
    prisma.reaction.deleteMany.mockResolvedValue({ count: 1 });
    prisma.reaction.create.mockResolvedValue({});
    prisma.reaction.count.mockResolvedValue(3);
    const push = { notifyKudos: jest.fn().mockResolvedValue(undefined) };
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false) };
    const svc = new SocialService(prisma as never, {} as never, moderation as never, push as never);

    const res = await svc.react("me", "evt-1");

    expect(prisma.reaction.deleteMany).toHaveBeenCalledWith({ where: { fromUserId: "me", feedEventId: "evt-1" } });
    expect(prisma.reaction.create).toHaveBeenCalledWith({ data: { fromUserId: "me", feedEventId: "evt-1", emoji: "👏" } });
    // Ré-engagement : on prévient l'AUTEUR applaudi (actorId), avec le compteur courant.
    expect(push.notifyKudos).toHaveBeenCalledWith("author", 3);
    expect(res).toEqual({ kudosCount: 3, iKudo: true });
  });

  it("react() : interdit l'auto-kudos (acteur == moi)", async () => {
    const prisma = makePrismaMock();
    prisma.feedEvent.findUnique.mockResolvedValue({ actorId: "me" });
    const svc = new SocialService(prisma as never, {} as never, {} as never, {} as never);
    await expect(svc.react("me", "evt-1")).rejects.toThrow();
  });

  it("unreact() : supprime mon kudos et renvoie le compteur restant + iKudo=false", async () => {
    const prisma = makePrismaMock();
    prisma.reaction.deleteMany.mockResolvedValue({ count: 1 });
    prisma.reaction.count.mockResolvedValue(2);
    const svc = new SocialService(prisma as never, {} as never, {} as never, {} as never);
    const res = await svc.unreact("me", "evt-1");
    expect(res).toEqual({ kudosCount: 2, iKudo: false });
  });
});

describe("Kudos unifié — posts (PostsService)", () => {
  it("react() : upsert d'UN 👏 (emoji toujours normalisé) ; le compteur = nb de réactions", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ authorId: "author" });
    prisma.postReaction.upsert.mockResolvedValue({});
    prisma.postReaction.count.mockResolvedValue(5);
    prisma.post.update.mockResolvedValue({});
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false) };
    const svc = new PostsService(prisma as never, moderation as never);

    const res = await svc.react("me", "post-1");

    const upsertArg = prisma.postReaction.upsert.mock.calls[0][0];
    expect(upsertArg.create.emoji).toBe("👏");
    expect(upsertArg.update.emoji).toBe("👏");
    expect(res).toEqual({ kudosCount: 5, iKudo: true });
  });

  it("forFeed() : d'anciennes réactions multi-emoji comptent chacune pour 1 kudos ; iKudo si l'une est de moi", async () => {
    const prisma = makePrismaMock();
    const moderation = { reportedPostIds: jest.fn().mockResolvedValue([]) };
    prisma.post.findMany.mockResolvedValue([
      {
        id: "p1",
        kind: "text",
        body: "salut",
        wodResultId: null,
        authorId: "u2",
        createdAt: new Date("2026-06-28T10:00:00Z"),
        author: { profile: { displayName: "Léa", rank: "gold" }, hybridIndex: { value: 800 }, avatar: null },
        reactions: [
          { emoji: "❤️", fromUserId: "me" },
          { emoji: "🔥", fromUserId: "x" },
        ],
      },
    ]);
    const svc = new PostsService(prisma as never, moderation as never);

    const items = await svc.forFeed(["u2"], "me", 60);

    expect(items).toHaveLength(1);
    expect(items[0].kudosCount).toBe(2);
    expect(items[0].iKudo).toBe(true);
    // Compat : la map `reactions` n'expose plus que le kudos unifié.
    expect(items[0].reactions).toEqual({ "👏": 2 });
  });

  it("forFeed() : exclut les posts que MOI j'ai signalés (disparition immédiate de mon fil)", async () => {
    const prisma = makePrismaMock();
    const moderation = { reportedPostIds: jest.fn().mockResolvedValue(["p-reported"]) };
    prisma.post.findMany.mockResolvedValue([]);
    const svc = new PostsService(prisma as never, moderation as never);

    await svc.forFeed(["u2"], "me", 60);

    const whereArg = prisma.post.findMany.mock.calls[0][0].where;
    expect(whereArg.status).toBe("visible");
    expect(whereArg.id).toEqual({ notIn: ["p-reported"] });
  });
});

describe("Auto-masquage des posts signalés (ModerationService)", () => {
  it("report() d'un post sous le seuil : met à jour reportCount mais NE masque PAS", async () => {
    const prisma = makePrismaMock();
    prisma.report.upsert.mockResolvedValue({});
    prisma.report.count.mockResolvedValue(2); // 2 rapporteurs distincts < 3
    prisma.post.update.mockResolvedValue({});
    const svc = new ModerationService(prisma as never);

    await svc.report("r1", { targetType: "post", targetId: "p1", reason: "spam" });

    const updateArg = prisma.post.update.mock.calls[0][0];
    expect(updateArg.data.reportCount).toBe(2);
    expect(updateArg.data.status).toBeUndefined();
  });

  it("report() d'un post AU seuil (3 rapporteurs distincts) : passe le post en `hidden`", async () => {
    const prisma = makePrismaMock();
    prisma.report.upsert.mockResolvedValue({});
    prisma.report.count.mockResolvedValue(3);
    prisma.post.update.mockResolvedValue({});
    const svc = new ModerationService(prisma as never);

    await svc.report("r3", { targetType: "post", targetId: "p1", reason: "harassment" });

    const updateArg = prisma.post.update.mock.calls[0][0];
    expect(updateArg.data.reportCount).toBe(3);
    expect(updateArg.data.status).toBe("hidden");
  });

  it("report() d'un user (non-post) : pas de tentative d'auto-masquage de post", async () => {
    const prisma = makePrismaMock();
    prisma.report.upsert.mockResolvedValue({});
    const svc = new ModerationService(prisma as never);

    await svc.report("r1", { targetType: "user", targetId: "u9", reason: "other" });

    expect(prisma.post.update).not.toHaveBeenCalled();
  });

  it("reportedPostIds() : ne renvoie que les targetId de type post signalés par moi", async () => {
    const prisma = makePrismaMock();
    prisma.report.findMany.mockResolvedValue([{ targetId: "p1" }, { targetId: "p2" }]);
    const svc = new ModerationService(prisma as never);

    const ids = await svc.reportedPostIds("me");

    expect(prisma.report.findMany).toHaveBeenCalledWith({
      where: { reporterId: "me", targetType: "post" },
      select: { targetId: true },
    });
    expect(ids).toEqual(["p1", "p2"]);
  });
});

describe("Repli « Découvrir » (SocialService.feed)", () => {
  it("ne suit personne + fil vide ⇒ feed() renvoie le top de la ligue (cartes source=discover, canFollow)", async () => {
    const prisma = makePrismaMock();
    prisma.follow.findMany.mockResolvedValue([]); // ne suit personne
    prisma.feedEvent.findMany.mockResolvedValue([]); // aucun event (pas même les miens)
    prisma.profile.findUnique.mockResolvedValue({ sex: "male" });
    prisma.hybridIndex.findMany.mockResolvedValue([
      { userId: "top1", value: 900, user: { profile: { displayName: "Max", rank: "elite" }, avatar: null } },
      { userId: "me", value: 850, user: { profile: { displayName: "Moi", rank: "gold" }, avatar: null } },
    ]);
    const posts = { forFeed: jest.fn().mockResolvedValue([]), forGlobalFeed: jest.fn().mockResolvedValue([]) };
    const moderation = { blockedIds: jest.fn().mockResolvedValue([]) };
    const svc = new SocialService(prisma as never, posts as never, moderation as never, {} as never);

    const out = (await svc.feed("me")) as Array<Record<string, unknown>>;

    expect(out.length).toBeGreaterThan(0);
    expect(out.every((c) => c.source === "discover")).toBe(true);
    expect(out.every((c) => c.canFollow === true)).toBe(true);
    // « me » est exclu du repli (on ne se suggère pas soi-même).
    expect(out.some((c) => (c.actor as { userId: string }).userId === "me")).toBe(false);
  });
});

describe("Blocage — actions d'engagement (P0 sécurité)", () => {
  // --- follow() ---
  it("follow() : refuse de suivre un utilisateur avec qui il y a un blocage (un sens ou l'autre)", async () => {
    const prisma = makePrismaMock();
    prisma.user.findFirst.mockResolvedValue({ id: "target", profile: { visibility: "public" } });
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(true) };
    const svc = new SocialService(prisma as never, {} as never, moderation as never, {} as never);

    await expect(svc.follow("me", "target")).rejects.toThrow();
    expect(moderation.isBlockedBetween).toHaveBeenCalledWith("me", "target");
    expect(prisma.follow.upsert).not.toHaveBeenCalled();
  });

  it("follow() : autorise un athlète actif sans blocage (plus de gate de visibilité)", async () => {
    const prisma = makePrismaMock();
    prisma.user.findFirst.mockResolvedValue({ id: "target" });
    prisma.follow.upsert.mockResolvedValue({});
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false) };
    const svc = new SocialService(prisma as never, {} as never, moderation as never, {} as never);

    const res = await svc.follow("me", "target");
    expect(res).toEqual({ following: true });
    expect(prisma.follow.upsert).toHaveBeenCalled();
  });

  // --- react() événement ---
  it("react() (event) : refuse le kudos vers/depuis un utilisateur bloqué", async () => {
    const prisma = makePrismaMock();
    prisma.feedEvent.findUnique.mockResolvedValue({ actorId: "author" });
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(true) };
    const svc = new SocialService(prisma as never, {} as never, moderation as never, {} as never);

    await expect(svc.react("me", "evt-1")).rejects.toThrow();
    expect(moderation.isBlockedBetween).toHaveBeenCalledWith("me", "author");
    expect(prisma.reaction.create).not.toHaveBeenCalled();
  });

  // --- react() post ---
  it("react() (post) : refuse le kudos vers/depuis un utilisateur bloqué", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ authorId: "author" });
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(true) };
    const svc = new PostsService(prisma as never, moderation as never);

    await expect(svc.react("me", "post-1")).rejects.toThrow();
    expect(moderation.isBlockedBetween).toHaveBeenCalledWith("me", "author");
    expect(prisma.postReaction.upsert).not.toHaveBeenCalled();
  });

  // --- explore() ---
  it("explore() : exclut soi-même ET les utilisateurs bloqués (dans un sens ou l'autre) des résultats", async () => {
    const prisma = makePrismaMock();
    prisma.profile.findMany.mockResolvedValue([]);
    const moderation = { blockedIds: jest.fn().mockResolvedValue(["blocker", "blocked"]) };
    const svc = new SocialService(prisma as never, {} as never, moderation as never, {} as never);

    await svc.explore("me", {});

    expect(moderation.blockedIds).toHaveBeenCalledWith("me");
    const whereArg = prisma.profile.findMany.mock.calls[0][0].where;
    expect(whereArg.userId).toEqual({ notIn: ["me", "blocker", "blocked"] });
  });
});

describe("Commentaires (CommentsService)", () => {
  function commentRow(over: Record<string, unknown> = {}) {
    return {
      id: "c1",
      postId: "p1",
      body: "Bien joué !",
      authorId: "me",
      createdAt: new Date("2026-06-30T10:00:00Z"),
      author: { profile: { displayName: "Moi", rank: "gold" }, avatar: null },
      ...over,
    };
  }

  it("create() : valide, crée le commentaire et notifie l'AUTEUR DU POST (best-effort)", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ id: "p1", authorId: "author", status: "visible" });
    prisma.comment.create.mockResolvedValue(commentRow({ author: { profile: { displayName: "Léa", rank: "gold" }, avatar: null }, authorId: "me" }));
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false), isCleanName: jest.fn().mockReturnValue(true) };
    const push = { notifyComment: jest.fn().mockResolvedValue(undefined) };
    const svc = new CommentsService(prisma as never, moderation as never, push as never);

    const res = await svc.create("me", "p1", "  Bien joué !  ");

    expect(prisma.comment.create.mock.calls[0][0].data).toEqual({ postId: "p1", authorId: "me", body: "Bien joué !" });
    expect(push.notifyComment).toHaveBeenCalledWith("author", "Léa");
    expect(res.body).toBe("Bien joué !");
    expect(res.author.isMe).toBe(true);
  });

  it("create() : NE notifie PAS en cas d'auto-commentaire (auteur du post == moi)", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ id: "p1", authorId: "me", status: "visible" });
    prisma.comment.create.mockResolvedValue(commentRow());
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false), isCleanName: jest.fn().mockReturnValue(true) };
    const push = { notifyComment: jest.fn() };
    const svc = new CommentsService(prisma as never, moderation as never, push as never);

    await svc.create("me", "p1", "mon propre post");
    expect(push.notifyComment).not.toHaveBeenCalled();
  });

  it("create() : refuse un corps vide", async () => {
    const prisma = makePrismaMock();
    const moderation = { isBlockedBetween: jest.fn(), isCleanName: jest.fn().mockReturnValue(true) };
    const svc = new CommentsService(prisma as never, moderation as never, {} as never);
    await expect(svc.create("me", "p1", "   ")).rejects.toThrow();
    expect(prisma.comment.create).not.toHaveBeenCalled();
  });

  it("create() : refuse un terme interdit (filtre de noms)", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ id: "p1", authorId: "author", status: "visible" });
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false), isCleanName: jest.fn().mockReturnValue(false) };
    const svc = new CommentsService(prisma as never, moderation as never, {} as never);
    await expect(svc.create("me", "p1", "insulte")).rejects.toThrow();
    expect(prisma.comment.create).not.toHaveBeenCalled();
  });

  it("create() : refuse de commenter le post d'un utilisateur bloqué", async () => {
    const prisma = makePrismaMock();
    prisma.post.findUnique.mockResolvedValue({ id: "p1", authorId: "author", status: "visible" });
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(true), isCleanName: jest.fn().mockReturnValue(true) };
    const svc = new CommentsService(prisma as never, moderation as never, {} as never);
    await expect(svc.create("me", "p1", "salut")).rejects.toThrow();
    expect(prisma.comment.create).not.toHaveBeenCalled();
  });

  it("list() : exclut les commentaires masqués ET les auteurs bloqués ; pagine par curseur", async () => {
    const prisma = makePrismaMock();
    prisma.comment.findMany.mockResolvedValue([commentRow()]);
    const moderation = { blockedIds: jest.fn().mockResolvedValue(["blk"]) };
    const svc = new CommentsService(prisma as never, moderation as never, {} as never);

    const out = await svc.list("me", "p1");

    const whereArg = prisma.comment.findMany.mock.calls[0][0].where;
    expect(whereArg.hidden).toBe(false);
    expect(whereArg.authorId).toEqual({ notIn: ["blk"] });
    expect(out.items).toHaveLength(1);
    expect(out.nextCursor).toBeNull();
  });

  it("delete() : autorisé à l'auteur du commentaire", async () => {
    const prisma = makePrismaMock();
    prisma.comment.findUnique.mockResolvedValue({ authorId: "me", post: { authorId: "other" } });
    prisma.comment.delete.mockResolvedValue({});
    const svc = new CommentsService(prisma as never, {} as never, {} as never);
    await expect(svc.delete("me", "c1")).resolves.toEqual({ removed: true });
  });

  it("delete() : autorisé à l'auteur du POST (modération de son fil)", async () => {
    const prisma = makePrismaMock();
    prisma.comment.findUnique.mockResolvedValue({ authorId: "other", post: { authorId: "me" } });
    prisma.comment.delete.mockResolvedValue({});
    const svc = new CommentsService(prisma as never, {} as never, {} as never);
    await expect(svc.delete("me", "c1")).resolves.toEqual({ removed: true });
  });

  it("delete() : refusé à un tiers (ni auteur du commentaire ni du post)", async () => {
    const prisma = makePrismaMock();
    prisma.comment.findUnique.mockResolvedValue({ authorId: "other", post: { authorId: "poster" } });
    const svc = new CommentsService(prisma as never, {} as never, {} as never);
    await expect(svc.delete("me", "c1")).rejects.toThrow();
    expect(prisma.comment.delete).not.toHaveBeenCalled();
  });
});

describe("Auto-masquage des commentaires signalés (ModerationService)", () => {
  it("report() d'un commentaire AU seuil (3) : passe le commentaire en hidden=true", async () => {
    const prisma = makePrismaMock();
    prisma.report.upsert.mockResolvedValue({});
    prisma.report.count.mockResolvedValue(3);
    prisma.comment.update.mockResolvedValue({});
    const svc = new ModerationService(prisma as never);

    await svc.report("r3", { targetType: "comment", targetId: "c1", reason: "harassment" });

    const updateArg = prisma.comment.update.mock.calls[0][0];
    expect(updateArg.data.reportCount).toBe(3);
    expect(updateArg.data.hidden).toBe(true);
  });

  it("report() d'un commentaire sous le seuil : reportCount maj mais PAS masqué", async () => {
    const prisma = makePrismaMock();
    prisma.report.upsert.mockResolvedValue({});
    prisma.report.count.mockResolvedValue(1);
    prisma.comment.update.mockResolvedValue({});
    const svc = new ModerationService(prisma as never);

    await svc.report("r1", { targetType: "comment", targetId: "c1", reason: "spam" });

    const updateArg = prisma.comment.update.mock.calls[0][0];
    expect(updateArg.data.reportCount).toBe(1);
    expect(updateArg.data.hidden).toBeUndefined();
  });
});

describe("Feed global vs following (SocialService.feed)", () => {
  function makeSvc(prisma: Record<string, Record<string, AnyFn>>, posts: Record<string, AnyFn>, blocked: string[] = []) {
    const moderation = { blockedIds: jest.fn().mockResolvedValue(blocked) };
    return new SocialService(prisma as never, posts as never, moderation as never, {} as never);
  }

  it("scope='all' : interroge les events de TOUS les acteurs actifs (pas de filtre actorId in) et appelle forGlobalFeed", async () => {
    const prisma = makePrismaMock();
    prisma.follow.findMany.mockResolvedValue([]);
    prisma.feedEvent.findMany.mockResolvedValue([]);
    const posts = { forGlobalFeed: jest.fn().mockResolvedValue([{ id: "p", source: "post", createdAt: "2026-06-30T10:00:00Z" }]), forFeed: jest.fn() };
    const svc = makeSvc(prisma, posts, ["blk"]);

    await svc.feed("me", "all");

    const evWhere = prisma.feedEvent.findMany.mock.calls[0][0].where;
    expect(evWhere.actorId).toEqual({ notIn: ["blk"] });
    expect(evWhere.actor).toEqual({ is: { status: "active" } });
    expect(posts.forGlobalFeed).toHaveBeenCalledWith("me", expect.any(Number), ["blk"]);
    expect(posts.forFeed).not.toHaveBeenCalled();
  });

  it("scope='following' : restreint les events aux acteurs (suivis + moi) et appelle forFeed", async () => {
    const prisma = makePrismaMock();
    prisma.follow.findMany.mockResolvedValue([{ followeeId: "f1" }]);
    prisma.feedEvent.findMany.mockResolvedValue([]);
    const posts = { forFeed: jest.fn().mockResolvedValue([{ id: "p", source: "post", createdAt: "2026-06-30T10:00:00Z" }]), forGlobalFeed: jest.fn() };
    const svc = makeSvc(prisma, posts);

    await svc.feed("me", "following");

    const evWhere = prisma.feedEvent.findMany.mock.calls[0][0].where;
    expect(evWhere.actorId).toEqual({ in: expect.arrayContaining(["f1", "me"]) });
    expect(posts.forFeed).toHaveBeenCalled();
    expect(posts.forGlobalFeed).not.toHaveBeenCalled();
  });
});

describe("Follow — plus de gate de visibilité (cahier : tout est public)", () => {
  it("follow() : suit un user actif sans lire sa visibilité de profil", async () => {
    const prisma = makePrismaMock();
    prisma.user.findFirst.mockResolvedValue({ id: "target" });
    prisma.follow.upsert.mockResolvedValue({});
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false) };
    const svc = new SocialService(prisma as never, {} as never, moderation as never, {} as never);

    const res = await svc.follow("me", "target");
    expect(res).toEqual({ following: true });
    // Le select ne demande plus la visibilité du profil.
    const selectArg = prisma.user.findFirst.mock.calls[0][0].select;
    expect(selectArg.profile).toBeUndefined();
  });
});
