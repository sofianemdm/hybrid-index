import { SocialService } from "../src/modules/social/social.service";
import { PostsService } from "../src/modules/posts/posts.service";
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
    post: { findUnique: jest.fn(), update: jest.fn(), findMany: jest.fn() },
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
    const posts = { forFeed: jest.fn().mockResolvedValue([]) };
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

  it("follow() : refuse de suivre un profil non public (visibility != public)", async () => {
    const prisma = makePrismaMock();
    prisma.user.findFirst.mockResolvedValue({ id: "target", profile: { visibility: "private" } });
    const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false) };
    const svc = new SocialService(prisma as never, {} as never, moderation as never, {} as never);

    await expect(svc.follow("me", "target")).rejects.toThrow();
    expect(prisma.follow.upsert).not.toHaveBeenCalled();
  });

  it("follow() : autorise un profil public sans blocage", async () => {
    const prisma = makePrismaMock();
    prisma.user.findFirst.mockResolvedValue({ id: "target", profile: { visibility: "public" } });
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
