import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";
import { PushService } from "../engagement/push.service";
import { RedisService } from "../../infra/redis/redis.service";
import { enforceUserRateLimit } from "../../common/rate-limit.util";
import { serializeAvatar, type AvatarView } from "../../common/avatar.serializer";
import { MentionsService } from "./mentions.service";
import type { ResolvedMention } from "../../common/mentions.util";

/** Sous-score interne /1000 → note d'affichage /100 (null si absent). */
const ovrSub = (v: number | null | undefined): number | null =>
  v == null ? null : Math.round(ratingFromInternal(v));

/** Kudos unifié façon Strava : un seul applaudissement par (item, utilisateur), toggle on/off. */
const KUDOS = "👏";
const MAX_BODY = 500;

/** Anti-spam (par utilisateur, fenêtre glissante Redis). Fail-open si Redis indisponible. */
const RL_POST_CREATE = { action: "post:create", limit: 8, windowSec: 60 };
const RL_POST_REACT = { action: "post:react", limit: 30, windowSec: 60 };

export interface CreatePostInput {
  kind: "text" | "perf_share";
  body?: string;
  wodResultId?: string;
  /** Fil de club : le post est aussi rattaché à ce club (réservé aux MEMBRES du club). */
  clubId?: string;
}

/** Élément de feed normalisé (même forme qu'un FeedEvent côté client). */
export interface FeedPostItem {
  id: string;
  source: "post";
  type: "post_text" | "post_perf";
  createdAt: string;
  actor: { userId: string; displayName: string; rank: string; index: number | null; isMe: boolean; avatar: AvatarView | null };
  payload: Record<string, unknown>;
  /** Kudos unifié : nombre d'applaudissements + si j'ai applaudi. */
  kudosCount: number;
  iKudo: boolean;
  /** Nombre de commentaires visibles sous le post (mini réseau social). */
  commentCount: number;
  /** @deprecated conservé pour compat ; toujours mappé sur le kudos 👏. */
  reactions: Record<string, number>;
  /** @deprecated conservé pour compat. */
  myReactions: string[];
  /** LOT 5 — mentions @pseudo résolues (rend les @ cliquables côté client). Vide si aucune. */
  mentions: ResolvedMention[];
}

/** Posts authored par les utilisateurs (texte ou partage de perf). Photos NON gérées pour l'instant. */
@Injectable()
export class PostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly moderation: ModerationService,
    private readonly push: PushService,
    private readonly redis: RedisService,
    private readonly mentions: MentionsService,
  ) {}

  async create(me: string, input: CreatePostInput): Promise<FeedPostItem> {
    await enforceUserRateLimit(this.redis, RL_POST_CREATE.action, me, RL_POST_CREATE.limit, RL_POST_CREATE.windowSec);
    const body = input.body?.trim();
    if (input.kind === "text") {
      if (!body) throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Le message ne peut pas être vide." });
    }
    if (body && body.length > MAX_BODY) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: `Message limité à ${MAX_BODY} caractères.` });
    }
    if (body && !this.moderation.isCleanName(body)) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Message non conforme (termes interdits)." });
    }

    let payloadExtra: Record<string, unknown> = {};
    let wodResultId: string | undefined;
    if (input.kind === "perf_share") {
      if (!input.wodResultId) {
        throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Résultat de séance requis pour partager une perf." });
      }
      const res = await this.prisma.wodResult.findUnique({
        where: { id: input.wodResultId },
        include: { wod: { select: { id: true, name: true, scoreType: true } } },
      });
      if (!res) throw new NotFoundException({ code: "NOT_FOUND", message: "Résultat introuvable." });
      if (res.userId !== me) throw new ForbiddenException({ code: "FORBIDDEN", message: "Ce résultat ne t'appartient pas." });
      wodResultId = res.id;
      payloadExtra = {
        wodId: res.wod.id,
        wodName: res.wod.name,
        scoreType: res.wod.scoreType,
        rawResult: Number(res.rawResult),
        subScore: ovrSub(res.subScore),
      };
    }

    // Post de CLUB : réservé aux membres (sinon n'importe qui écrirait dans n'importe quel fil).
    if (input.clubId) {
      const member = await this.prisma.clubMember.findUnique({
        where: { clubId_userId: { clubId: input.clubId, userId: me } },
      });
      if (!member) {
        throw new ForbiddenException({ code: "FORBIDDEN", message: "Réservé aux membres du club." });
      }
    }

    const post = await this.prisma.post.create({
      data: {
        authorId: me,
        kind: input.kind,
        body: body && body.length > 0 ? body : null,
        wodResultId: wodResultId ?? null,
        clubId: input.clubId ?? null,
      },
      include: {
        author: {
          include: {
            profile: { select: { displayName: true, rank: true } },
            hybridIndex: { select: { value: true } },
            avatar: true,
          },
        },
      },
    });

    // LOT 5 — mentions @pseudo : résolution (hors auto-mention / bloqués) + push best-effort.
    const authorName = post.author.profile?.displayName ?? "Un athlète";
    const mentions = await this.mentions.resolve(me, post.body).catch(() => [] as ResolvedMention[]);
    if (mentions.length > 0) {
      void this.mentions.notify(mentions, authorName).catch(() => undefined);
    }

    return {
      id: post.id,
      source: "post",
      type: input.kind === "perf_share" ? "post_perf" : "post_text",
      createdAt: post.createdAt.toISOString(),
      actor: {
        userId: me,
        displayName: post.author.profile?.displayName ?? "—",
        rank: post.author.profile?.rank ?? "rookie",
        index: ovrSub(post.author.hybridIndex?.value),
        isMe: true,
        avatar: serializeAvatar(post.author.avatar),
      },
      payload: { body: post.body, ...payloadExtra },
      kudosCount: 0,
      iKudo: false,
      commentCount: 0,
      reactions: {},
      myReactions: [],
      mentions,
    };
  }

  async delete(me: string, postId: string): Promise<{ removed: true }> {
    const post = await this.prisma.post.findUnique({ where: { id: postId }, select: { authorId: true } });
    if (!post) throw new NotFoundException({ code: "NOT_FOUND", message: "Post introuvable." });
    if (post.authorId !== me) throw new ForbiddenException({ code: "FORBIDDEN", message: "Tu ne peux supprimer que tes posts." });
    await this.prisma.post.delete({ where: { id: postId } });
    return { removed: true };
  }

  /** Applaudir un post (kudos unifié). L'emoji est toujours normalisé sur 👏 : un seul kudos par (post, user). */
  async react(me: string, postId: string): Promise<{ kudosCount: number; iKudo: true }> {
    await enforceUserRateLimit(this.redis, RL_POST_REACT.action, me, RL_POST_REACT.limit, RL_POST_REACT.windowSec);
    const post = await this.prisma.post.findUnique({ where: { id: postId }, select: { authorId: true } });
    if (!post) throw new NotFoundException({ code: "NOT_FOUND", message: "Post introuvable." });
    if (post.authorId === me) throw new ConflictException({ code: "CONFLICT", message: "Pas d'auto-kudos." });
    // Sécurité : pas de kudos vers/depuis un utilisateur bloqué (dans un sens OU l'autre).
    if (await this.moderation.isBlockedBetween(me, post.authorId)) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Action impossible avec cet utilisateur." });
    }
    // Passage 0→1 pour CE user : on note s'il applaudissait déjà AVANT l'upsert, pour ne notifier
    // l'auteur qu'à un kudos RÉELLEMENT nouveau (pas à chaque re-like idempotent).
    const already = await this.prisma.postReaction.findUnique({
      where: { postId_fromUserId: { postId, fromUserId: me } },
      select: { id: true },
    });
    await this.prisma.postReaction.upsert({
      where: { postId_fromUserId: { postId, fromUserId: me } },
      create: { postId, fromUserId: me, emoji: KUDOS },
      update: { emoji: KUDOS },
    });
    const kudosCount = await this.syncCount(postId);
    // Ré-engagement : on prévient l'AUTEUR du post UNIQUEMENT au premier kudos de ce user (jamais
    // en auto-kudos — déjà bloqué plus haut). Best-effort : un push KO n'échoue jamais le kudos.
    if (!already) {
      try {
        await this.push.notifyPostKudos(post.authorId, kudosCount);
      } catch {
        // silencieux (gating/no-op géré dans PushService)
      }
    }
    return { kudosCount, iKudo: true };
  }

  async unreact(me: string, postId: string): Promise<{ kudosCount: number; iKudo: false }> {
    await this.prisma.postReaction.deleteMany({ where: { postId, fromUserId: me } });
    const kudosCount = await this.syncCount(postId);
    return { kudosCount, iKudo: false };
  }

  private async syncCount(postId: string): Promise<number> {
    const count = await this.prisma.postReaction.count({ where: { postId } });
    await this.prisma.post.update({ where: { id: postId }, data: { reactionCount: count } }).catch(() => undefined);
    return count;
  }

  /**
   * Posts (texte + perf) des `actorIds`, normalisés pour le feed unifié.
   * Exclut les posts non visibles (status != visible → masqués par modération/auto-masquage)
   * ET les posts que `me` a déjà signalés (ils disparaissent immédiatement de SON feed).
   */
  async forFeed(actorIds: string[], me: string, take: number): Promise<FeedPostItem[]> {
    if (actorIds.length === 0) return [];
    return this.queryFeedPosts({ authorId: { in: actorIds } }, me, take);
  }

  /**
   * LOT 3 — « Mur » d'un athlète : posts PUBLICS et visibles d'UN auteur, paginés par curseur
   * (createdAt desc). Respecte le blocage BIDIRECTIONNEL (si `me` et `authorId` sont bloqués dans
   * un sens OU l'autre → mur vide) et l'auto-masquage / mes signalements (via `queryFeedPosts`).
   * Réutilise la sérialisation commune du feed (pas de divergence). `take` borné [1..50].
   */
  async forProfile(
    authorId: string,
    me: string,
    take: number,
    cursor?: string,
  ): Promise<{ items: FeedPostItem[]; nextCursor: string | null }> {
    const safeTake = Math.max(1, Math.min(take || 20, 50));
    // Blocage bidirectionnel : on ne dévoile jamais le mur d'un utilisateur bloqué (ou qui me bloque).
    if (me !== authorId && (await this.moderation.isBlockedBetween(me, authorId))) {
      return { items: [], nextCursor: null };
    }
    // On lit `safeTake + 1` pour savoir s'il reste une page (curseur = id du dernier élément rendu).
    const rows = await this.queryFeedPosts({ authorId }, me, safeTake + 1, cursor);
    const hasMore = rows.length > safeTake;
    const items = hasMore ? rows.slice(0, safeTake) : rows;
    return { items, nextCursor: hasMore ? items[items.length - 1].id : null };
  }

  /** Fil d'un CLUB : posts rattachés au club, paginés (createdAt desc). Lecture ouverte à tous
   *  (« tout est public ») ; l'ÉCRITURE, elle, est réservée aux membres (cf. create). Réutilise la
   *  sérialisation commune (auto-masquage / mes signalements appliqués par queryFeedPosts). */
  async forClub(
    clubId: string,
    me: string,
    take: number,
    cursor?: string,
  ): Promise<{ items: FeedPostItem[]; nextCursor: string | null }> {
    const safeTake = Math.max(1, Math.min(take || 20, 50));
    const rows = await this.queryFeedPosts({ clubId }, me, safeTake + 1, cursor);
    const hasMore = rows.length > safeTake;
    const items = hasMore ? rows.slice(0, safeTake) : rows;
    return { items, nextCursor: hasMore ? items[items.length - 1].id : null };
  }

  /**
   * Feed GLOBAL : posts PUBLICS de TOUS les utilisateurs actifs, en excluant les auteurs bloqués
   * (dans un sens OU l'autre) — `blockedIds` est fourni par l'appelant (SocialService).
   * Soi-même n'est PAS exclu (mes posts apparaissent aussi dans le fil global).
   */
  async forGlobalFeed(me: string, take: number, blockedIds: string[]): Promise<FeedPostItem[]> {
    return this.queryFeedPosts(
      {
        author: { is: { status: "active" } },
        ...(blockedIds.length ? { authorId: { notIn: blockedIds } } : {}),
      },
      me,
      take,
    );
  }

  /** Cœur commun des feeds (following / global / mur de profil) : applique status/visibility +
   *  exclusion de MES signalements. `cursor` (optionnel) = id du dernier post vu (pagination desc). */
  private async queryFeedPosts(
    extraWhere: Record<string, unknown>,
    me: string,
    take: number,
    cursor?: string,
  ): Promise<FeedPostItem[]> {
    const reportedIds = await this.moderation.reportedPostIds(me);
    const posts = await this.prisma.post.findMany({
      where: {
        ...extraWhere,
        status: "visible",
        visibility: "public",
        ...(reportedIds.length ? { id: { notIn: reportedIds } } : {}),
      },
      // Tie-break id : ordre TOTAL stable (même createdAt possible en rafale) — curseur fiable.
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        author: {
          include: {
            profile: { select: { displayName: true, rank: true } },
            hybridIndex: { select: { value: true } },
            avatar: true,
          },
        },
        // Dette lecture (LOT 6) : on ne charge PLUS toutes les réactions de chaque post pour les
        // dé-doublonner en mémoire. La clé @@unique([postId, fromUserId]) garantit un kudos par
        // user → `_count` donne directement le compteur. `iKudo` est résolu par UNE requête ciblée.
        _count: { select: { reactions: true, comments: { where: { hidden: false } } } },
      },
    });

    // « Ai-je applaudi ? » en UNE requête bornée aux posts de la page (au lieu de charger toutes
    // les réactions de chaque post). Set d'appartenance → O(1) par post.
    const postIds = posts.map((p) => p.id);
    const myKudos = postIds.length
      ? await this.prisma.postReaction.findMany({
          where: { postId: { in: postIds }, fromUserId: me },
          select: { postId: true },
        })
      : [];
    const iKudoSet = new Set(myKudos.map((r) => r.postId));

    // Hydrate les perf_share avec les infos de séance.
    const resultIds = posts.map((p) => p.wodResultId).filter((x): x is string => !!x);
    const results = resultIds.length
      ? await this.prisma.wodResult.findMany({
          where: { id: { in: resultIds } },
          include: { wod: { select: { id: true, name: true, scoreType: true } } },
        })
      : [];
    const byId = new Map(results.map((r) => [r.id, r]));

    // LOT 5 — mentions @pseudo résolues pour CETTE page (1 requête profils, pas de N+1) afin de
    // rendre les @ cliquables côté client. Best-effort : un échec ⇒ aucune mention (pas de crash).
    const mentionsByPost = await this.mentions
      .resolveBatch(posts.map((p) => ({ id: p.id, body: p.body })))
      .catch(() => new Map<string, ResolvedMention[]>());

    return posts.map((p) => {
      // Kudos unifié : un seul applaudissement par user (clé unique) → `_count` EST le compteur.
      const kudosCount = p._count?.reactions ?? 0;
      const iKudo = iKudoSet.has(p.id);
      const reactions: Record<string, number> = kudosCount > 0 ? { [KUDOS]: kudosCount } : {};
      const payload: Record<string, unknown> = { body: p.body };
      if (p.kind === "perf_share" && p.wodResultId) {
        const res = byId.get(p.wodResultId);
        if (res) {
          payload.wodId = res.wod.id;
          payload.wodName = res.wod.name;
          payload.scoreType = res.wod.scoreType;
          payload.rawResult = Number(res.rawResult);
          payload.subScore = ovrSub(res.subScore);
        }
      }
      return {
        id: p.id,
        source: "post" as const,
        type: p.kind === "perf_share" ? ("post_perf" as const) : ("post_text" as const),
        createdAt: p.createdAt.toISOString(),
        actor: {
          userId: p.authorId,
          displayName: p.author.profile?.displayName ?? "—",
          rank: p.author.profile?.rank ?? "rookie",
          index: ovrSub(p.author.hybridIndex?.value),
          isMe: p.authorId === me,
          avatar: serializeAvatar(p.author.avatar),
        },
        payload,
        kudosCount,
        iKudo,
        commentCount: p._count?.comments ?? 0,
        reactions,
        myReactions: iKudo ? [KUDOS] : [],
        mentions: mentionsByPost.get(p.id) ?? [],
      };
    });
  }
}
