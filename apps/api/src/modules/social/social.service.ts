import { BadRequestException, ConflictException, ForbiddenException, Injectable } from "@nestjs/common";
import type { Sex } from "@prisma/client";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";
import { PostsService } from "../posts/posts.service";
import { PushService } from "../engagement/push.service";
import { serializeAvatar } from "../../common/avatar.serializer";

/** Valeur interne /1000 → OVR /100 affiché (null si non mesuré). */
const ovr = (internal: number | null | undefined): number | null =>
  internal == null ? null : Math.round(ratingFromInternal(internal));

/** Kudos unifié façon Strava : un seul applaudissement 👏 par (item, utilisateur), toggle on/off. */
const KUDOS = "👏";
/** Feed FINI (pas de scroll infini) : fenêtre bornée des activités les plus récentes. */
const FEED_LIMIT = 60;
/** Repli « Découvrir » : top de la ligue (même sexe) quand l'utilisateur ne suit personne. */
const DISCOVER_LIMIT = 20;

/** Portée du feed : 'all' = fil global (tous les actifs) ; 'following' = suivis + moi. */
export type FeedScope = "all" | "following";

@Injectable()
export class SocialService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
    private readonly moderation: ModerationService,
    private readonly push: PushService,
  ) {}

  // --- Follow ---
  async follow(me: string, target: string): Promise<{ following: true }> {
    if (me === target) throw new BadRequestException({ code: "VALIDATION_ERROR", message: "On ne se suit pas soi-même." });
    const exists = await this.prisma.user.findFirst({
      where: { id: target, status: "active" },
      select: { id: true },
    });
    if (!exists) throw new BadRequestException({ code: "NOT_FOUND", message: "Athlète introuvable." });
    // Sécurité : impossible de suivre quelqu'un avec qui il existe un blocage (dans un sens OU l'autre).
    if (await this.moderation.isBlockedBetween(me, target)) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Action impossible avec cet utilisateur." });
    }
    // Cahier des charges : « tout est public ». On ne gate PLUS sur la visibilité du profil — ce
    // contrôle bloquait à tort les follows. Seuls l'anti-auto-follow et l'anti-blocage subsistent.
    await this.prisma.follow.upsert({
      where: { followerId_followeeId: { followerId: me, followeeId: target } },
      create: { followerId: me, followeeId: target },
      update: {},
    });
    return { following: true };
  }

  async unfollow(me: string, target: string): Promise<{ following: false }> {
    await this.prisma.follow
      .delete({ where: { followerId_followeeId: { followerId: me, followeeId: target } } })
      .catch(() => undefined);
    return { following: false };
  }

  async listFollowing(me: string): Promise<unknown[]> {
    const rows = await this.prisma.follow.findMany({
      where: { followerId: me },
      include: { followee: { include: { profile: true, hybridIndex: true } } },
    });
    return rows.map((r) => this.athlete(r.followee));
  }

  async listFollowers(me: string): Promise<unknown[]> {
    const rows = await this.prisma.follow.findMany({
      where: { followeeId: me },
      include: { follower: { include: { profile: true, hybridIndex: true } } },
    });
    return rows.map((r) => this.athlete(r.follower));
  }

  // --- Kudos unifié (un seul applaudissement 👏 par event, toggle) ---
  async react(me: string, feedEventId: string): Promise<{ kudosCount: number; iKudo: true }> {
    const event = await this.prisma.feedEvent.findUnique({ where: { id: feedEventId }, select: { actorId: true } });
    if (!event) throw new BadRequestException({ code: "NOT_FOUND", message: "Événement introuvable." });
    if (event.actorId === me) throw new ConflictException({ code: "CONFLICT", message: "Pas d'auto-kudos." });
    // Sécurité : pas de kudos vers/depuis un utilisateur bloqué (dans un sens OU l'autre).
    if (await this.moderation.isBlockedBetween(me, event.actorId)) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Action impossible avec cet utilisateur." });
    }
    // Un seul kudos par user par event : on efface tout (y compris d'anciens emojis multiples) puis on pose 👏.
    await this.prisma.reaction.deleteMany({ where: { fromUserId: me, feedEventId } });
    await this.prisma.reaction.create({ data: { fromUserId: me, feedEventId, emoji: KUDOS } });
    const kudosCount = await this.prisma.reaction.count({ where: { feedEventId } });
    // Ré-engagement : on prévient l'AUTEUR applaudi (event.actorId), jamais celui qui applaudit.
    // Best-effort : un push KO ne doit jamais faire échouer le kudos (gating/cooldown gérés en aval).
    try {
      await this.push.notifyKudos(event.actorId, kudosCount);
    } catch {
      // best-effort : silencieux (le gating/no-op push est géré dans PushService)
    }
    return { kudosCount, iKudo: true };
  }

  async unreact(me: string, feedEventId: string): Promise<{ kudosCount: number; iKudo: false }> {
    await this.prisma.reaction.deleteMany({ where: { fromUserId: me, feedEventId } });
    const kudosCount = await this.prisma.reaction.count({ where: { feedEventId } });
    return { kudosCount, iKudo: false };
  }

  /**
   * LOT 3 — « Mur » d'un athlète : ses posts PUBLICS paginés par curseur. Délègue à
   * `PostsService.forProfile` (réutilise la sérialisation du feed → pas de divergence). Le blocage
   * bidirectionnel et la visibilité sont appliqués côté PostsService.
   */
  async userPosts(me: string, authorId: string, cursor?: string): Promise<{ items: unknown[]; nextCursor: string | null }> {
    return this.posts.forProfile(authorId, me, FEED_LIMIT, cursor);
  }

  // --- Recherche d'athlètes ---
  async explore(me: string, filters: { sex?: string; rank?: string; q?: string }): Promise<unknown[]> {
    // Sécurité : on exclut les utilisateurs avec qui il existe un blocage (dans un sens OU l'autre)
    // ainsi que soi-même.
    const blocked = await this.moderation.blockedIds(me);
    const excludeIds = [me, ...blocked];
    const profiles = await this.prisma.profile.findMany({
      where: {
        visibility: "public",
        user: { is: { status: "active" } },
        userId: { notIn: excludeIds },
        ...(filters.sex ? { sex: filters.sex as never } : {}),
        ...(filters.rank ? { rank: filters.rank as never } : {}),
        ...(filters.q ? { displayName: { contains: filters.q.slice(0, 50), mode: "insensitive" } } : {}),
      },
      include: { user: { include: { hybridIndex: { select: { value: true } } } } },
      take: 50,
    });
    return profiles
      .map((p) => ({
        userId: p.userId,
        displayName: p.displayName,
        sex: p.sex,
        goal: p.goal,
        rank: p.rank,
        index: ovr(p.user.hybridIndex?.value),
      }))
      .sort((a, b) => (b.index ?? 0) - (a.index ?? 0));
  }

  // --- Feed unifié (événements auto + posts authored), FINI, hors utilisateurs bloqués ---
  // scope='all' (défaut) : fil GLOBAL = activités publiques de TOUS les utilisateurs actifs.
  // scope='following' : fil restreint aux personnes suivies + moi (comportement historique).
  async feed(me: string, scope: FeedScope = "all"): Promise<unknown[]> {
    const [follows, blocked] = await Promise.all([
      this.prisma.follow.findMany({ where: { followerId: me }, select: { followeeId: true } }),
      this.moderation.blockedIds(me),
    ]);
    const blockedSet = new Set(blocked);
    const followeeIds = follows.map((f) => f.followeeId).filter((id) => !blockedSet.has(id));

    // Acteurs des ÉVÉNEMENTS auto (feed_event). En 'following' : suivis + moi. En 'all' : non borné.
    const actorIds = [...new Set([...followeeIds, me])].filter((id) => !blockedSet.has(id));

    // Filtre des événements selon le scope : 'following' = liste explicite ; 'all' = tous les
    // acteurs actifs, hors utilisateurs bloqués (dans un sens OU l'autre).
    // Les montées de rang ne sont PLUS émises (03/07) ; on filtre aussi celles déjà en base.
    const noRankUp = { type: { not: "rank_up" as const } };
    const eventWhere =
      scope === "following"
        ? { actorId: { in: actorIds }, visibility: "public" as const, ...noRankUp }
        : {
            visibility: "public" as const,
            actor: { is: { status: "active" } },
            ...(blocked.length ? { actorId: { notIn: blocked } } : {}),
            ...noRankUp,
          };

    const [events, postItems] = await Promise.all([
      this.prisma.feedEvent.findMany({
        where: eventWhere,
        // Tie-break id : des événements créés dans la MÊME milliseconde (rafale d'onboarding)
        // sortaient dans un ordre ALÉATOIRE par requête → feed instable entre deux GET.
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        take: FEED_LIMIT,
        include: {
          actor: {
            include: {
              profile: { select: { displayName: true, rank: true } },
              hybridIndex: { select: { value: true } },
              avatar: true,
            },
          },
          reactions: { select: { fromUserId: true } },
        },
      }),
      scope === "following"
        ? this.posts.forFeed(actorIds, me, FEED_LIMIT)
        : this.posts.forGlobalFeed(me, FEED_LIMIT, blocked),
    ]);

    const eventItems = events.map((e) => {
      // Kudos unifié : chaque réaction (y compris d'anciens emojis) compte pour 1 applaudissement.
      // Dé-doublonnage par utilisateur : la table Reaction (events) a une clé (user, event, emoji),
      // donc d'anciennes réactions multi-emoji pourraient compter un même user plusieurs fois.
      const kudosCount = new Set(e.reactions.map((r) => r.fromUserId)).size;
      const iKudo = e.reactions.some((r) => r.fromUserId === me);
      const reactions: Record<string, number> = kudosCount > 0 ? { [KUDOS]: kudosCount } : {};
      return {
        id: e.id,
        source: "event" as const,
        type: e.type as string,
        createdAt: e.createdAt.toISOString(),
        actor: {
          userId: e.actorId,
          displayName: e.actor.profile?.displayName ?? "—",
          rank: e.actor.profile?.rank ?? "rookie",
          index: ovr(e.actor.hybridIndex?.value),
          isMe: e.actorId === me,
          avatar: serializeAvatar(e.actor.avatar),
        },
        payload: e.payload,
        kudosCount,
        iKudo,
        commentCount: 0, // les événements auto ne portent pas de commentaires (posts seulement)
        reactions,
        myReactions: iKudo ? [KUDOS] : [],
        mentions: [], // les événements auto ne portent pas de mentions (posts/commentaires seulement)
      };
    });

    // Fusion + tri chronologique décroissant + fenêtre bornée (feed fini).
    const merged = [...eventItems, ...postItems]
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, FEED_LIMIT);

    // Fil « Découvrir » : si le fil est vide, on renvoie un repli engageant — le top de SA ligue —
    // plutôt qu'un vide mort. Chaque carte porte `canFollow:true` pour un bouton « Suivre » direct.
    // S'applique aux deux scopes (un fil global vide = communauté naissante → on suggère qui suivre).
    if (merged.length === 0) {
      return this.discover(me);
    }
    return merged;
  }

  /**
   * Repli « Découvrir » : top de la ligue de l'utilisateur (même sexe), athlètes qu'il ne suit pas
   * encore et qui ne le bloquent pas. Forme `source: "discover"` → carte « athlète à suivre ».
   */
  async discover(me: string): Promise<unknown[]> {
    const [profile, follows, blocked] = await Promise.all([
      this.prisma.profile.findUnique({ where: { userId: me }, select: { sex: true } }),
      this.prisma.follow.findMany({ where: { followerId: me }, select: { followeeId: true } }),
      this.moderation.blockedIds(me),
    ]);
    const exclude = new Set<string>([me, ...follows.map((f) => f.followeeId), ...blocked]);

    const top = await this.prisma.hybridIndex.findMany({
      where: {
        user: { is: { status: "active", profile: { is: { sex: (profile?.sex ?? "male") as Sex, visibility: "public" } } } },
      },
      orderBy: [{ value: "desc" }, { userId: "asc" }],
      take: DISCOVER_LIMIT + exclude.size,
      include: {
        user: {
          include: {
            profile: { select: { displayName: true, rank: true } },
            avatar: true,
          },
        },
      },
    });

    return top
      .filter((h) => !exclude.has(h.userId))
      .slice(0, DISCOVER_LIMIT)
      .map((h, i) => ({
        id: `discover:${h.userId}`,
        source: "discover" as const,
        type: "suggested_athlete" as const,
        createdAt: new Date().toISOString(),
        actor: {
          userId: h.userId,
          displayName: h.user.profile?.displayName ?? "—",
          rank: h.user.profile?.rank ?? "rookie",
          index: ovr(h.value),
          isMe: false,
          avatar: serializeAvatar(h.user.avatar),
        },
        payload: { position: i + 1, index: ovr(h.value) },
        canFollow: true,
        kudosCount: 0,
        iKudo: false,
        commentCount: 0,
        reactions: {},
        myReactions: [],
      }));
  }

  private athlete(user: {
    id: string;
    profile: { displayName: string; sex: string; goal: string; rank: string } | null;
    hybridIndex: { value: number } | null;
  }): unknown {
    return {
      userId: user.id,
      displayName: user.profile?.displayName ?? "—",
      sex: user.profile?.sex ?? "male",
      goal: user.profile?.goal ?? "all_round",
      rank: user.profile?.rank ?? "rookie",
      index: ovr(user.hybridIndex?.value),
    };
  }
}
