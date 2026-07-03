import { ConflictException, BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";
import { PushService } from "../engagement/push.service";
import { RedisService } from "../../infra/redis/redis.service";
import { enforceUserRateLimit } from "../../common/rate-limit.util";
import { serializeAvatar, type AvatarView } from "../../common/avatar.serializer";
import { MentionsService } from "./mentions.service";
import type { ResolvedMention } from "../../common/mentions.util";

const MAX_BODY = 500;
const PAGE_SIZE = 50;
/** Réponses chargées par commentaire racine au listing (1 seul niveau, borné pour rester léger). */
const REPLY_LIMIT = 20;

/** Anti-spam (par utilisateur, fenêtre glissante Redis). Fail-open si Redis indisponible. */
const RL_COMMENT_CREATE = { action: "comment:create", limit: 12, windowSec: 60 };
const RL_COMMENT_REACT = { action: "comment:react", limit: 30, windowSec: 60 };

/** Élément de commentaire normalisé pour le client. */
export interface CommentItem {
  id: string;
  postId: string;
  /** LOT 4 — id du commentaire racine si c'est une réponse, sinon null. */
  parentId: string | null;
  body: string;
  createdAt: string;
  author: { userId: string; displayName: string; rank: string; isMe: boolean; avatar: AvatarView | null };
  /** Kudos unifié (👏) sur le commentaire : nombre d'applaudissements + si j'ai applaudi. */
  kudosCount: number;
  iKudo: boolean;
  /** LOT 4 — nombre de réponses directes (n'a de sens que sur un commentaire racine). */
  replyCount: number;
  /** LOT 4 — réponses imbriquées (1 seul niveau ; bornées). Vide/absent sur une réponse. */
  replies: CommentItem[];
  /** LOT 5 — mentions @pseudo résolues (rend les @ cliquables côté client). Vide si aucune. */
  mentions: ResolvedMention[];
}

/**
 * Commentaires sous les posts du feed (mini réseau social).
 * - création (validation longueur + filtre de noms), notif best-effort à l'auteur du post ;
 * - liste paginée par curseur (createdAt asc), hors commentaires d'utilisateurs bloqués et hors masqués ;
 * - suppression par l'auteur du commentaire OU l'auteur du post.
 */
@Injectable()
export class CommentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly moderation: ModerationService,
    private readonly push: PushService,
    private readonly redis: RedisService,
    private readonly mentions: MentionsService,
  ) {}

  async create(me: string, postId: string, rawBody: string, parentId?: string): Promise<CommentItem> {
    await enforceUserRateLimit(this.redis, RL_COMMENT_CREATE.action, me, RL_COMMENT_CREATE.limit, RL_COMMENT_CREATE.windowSec);
    const body = rawBody?.trim();
    if (!body) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Le commentaire ne peut pas être vide." });
    }
    if (body.length > MAX_BODY) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: `Commentaire limité à ${MAX_BODY} caractères.` });
    }
    if (!this.moderation.isCleanName(body)) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Commentaire non conforme (termes interdits)." });
    }

    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, authorId: true, status: true },
    });
    if (!post || post.status !== "visible") {
      throw new NotFoundException({ code: "NOT_FOUND", message: "Post introuvable." });
    }
    // Sécurité : pas de commentaire vers/depuis un utilisateur bloqué (dans un sens OU l'autre).
    if (await this.moderation.isBlockedBetween(me, post.authorId)) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Action impossible avec cet utilisateur." });
    }

    // LOT 4 — réponse (thread 1 SEUL niveau) : le parent doit être un commentaire RACINE
    // (parentId == null) du MÊME post, non masqué. On refuse de répondre à une réponse (niveau 2).
    let parent: { authorId: string } | null = null;
    if (parentId) {
      const parentRow = await this.prisma.comment.findUnique({
        where: { id: parentId },
        select: { id: true, postId: true, parentId: true, hidden: true, authorId: true },
      });
      if (!parentRow || parentRow.hidden || parentRow.postId !== postId) {
        throw new NotFoundException({ code: "NOT_FOUND", message: "Commentaire parent introuvable." });
      }
      if (parentRow.parentId !== null) {
        throw new BadRequestException({ code: "VALIDATION_ERROR", message: "On ne peut répondre qu'à un commentaire de premier niveau." });
      }
      // Blocage : pas de réponse vers/depuis l'auteur du commentaire parent s'il y a blocage.
      if (await this.moderation.isBlockedBetween(me, parentRow.authorId)) {
        throw new ForbiddenException({ code: "FORBIDDEN", message: "Action impossible avec cet utilisateur." });
      }
      parent = { authorId: parentRow.authorId };
    }

    // ATOMIQUE : création + incrément du compteur du parent dans UNE transaction. Avant, l'incrément
    // était best-effort après coup → un échec laissait replyCount sous-compté pour toujours.
    const createArgs = {
      data: { postId, authorId: me, body, parentId: parentId ?? null },
      include: {
        author: { include: { profile: { select: { displayName: true, rank: true } }, avatar: true } },
      },
    };
    const comment = parent == null
        ? await this.prisma.comment.create(createArgs)
        : (
            await this.prisma.$transaction([
              this.prisma.comment.create(createArgs),
              this.prisma.comment.update({ where: { id: parentId }, data: { replyCount: { increment: 1 } } }),
            ])
          )[0];

    const authorName = comment.author.profile?.displayName ?? "Un athlète";

    if (parent) {
      // Réponse : notifie l'auteur du parent (hors auto-réponse). L'incrément est fait ci-dessus.
      if (parent.authorId !== me) {
        try {
          await this.push.notifyCommentReply(parent.authorId, authorName);
        } catch {
          // best-effort : silencieux (gating/no-op géré dans PushService)
        }
      }
    } else if (post.authorId !== me) {
      // Commentaire racine : on prévient l'AUTEUR du post (jamais en cas d'auto-commentaire).
      // Best-effort : un push KO ne doit jamais faire échouer la création du commentaire.
      try {
        await this.push.notifyComment(post.authorId, authorName);
      } catch {
        // silencieux (gating/no-op géré dans PushService)
      }
    }

    // LOT 5 — mentions @pseudo : résolution (hors auto-mention / bloqués) + push best-effort.
    const mentions = await this.mentions.resolve(me, body).catch(() => [] as ResolvedMention[]);
    if (mentions.length > 0) {
      void this.mentions.notify(mentions, authorName).catch(() => undefined);
    }

    // Commentaire fraîchement créé : 0 kudos, 0 réponse, pas encore applaudi par moi.
    return this.serialize(comment, me, 0, false, [], mentions);
  }

  /**
   * Liste paginée d'un post (du plus ancien au plus récent), hors commentaires masqués et hors
   * commentaires d'utilisateurs bloqués (dans un sens OU l'autre). Curseur = id du dernier vu.
   *
   * LOT 4 — threads 1 SEUL niveau : la pagination par curseur porte sur les commentaires RACINES
   * (parentId == null). Chaque racine porte ses `replies` IMBRIQUÉES (bornées à REPLY_LIMIT,
   * ordre chronologique), ce qui est le plus simple/robuste pour le client (pas de 2e endpoint).
   * Hydrate `kudosCount` (`reactionCount`) + `iKudo` + `mentions` pour racines ET réponses.
   */
  async list(me: string, postId: string, cursor?: string): Promise<{ items: CommentItem[]; nextCursor: string | null }> {
    const blocked = await this.moderation.blockedIds(me);
    const blockWhere = blocked.length ? { authorId: { notIn: blocked } } : {};
    const roots = await this.prisma.comment.findMany({
      where: { postId, hidden: false, parentId: null, ...blockWhere },
      orderBy: [{ createdAt: "asc" }, { id: "asc" }],
      take: PAGE_SIZE + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        author: { include: { profile: { select: { displayName: true, rank: true } }, avatar: true } },
      },
    });
    const hasMore = roots.length > PAGE_SIZE;
    const page = hasMore ? roots.slice(0, PAGE_SIZE) : roots;
    const rootIds = page.map((c) => c.id);

    // Réponses (1 niveau) des racines de la page, en UNE requête, hors masquées/bloquées.
    const replies = rootIds.length
      ? await this.prisma.comment.findMany({
          where: { parentId: { in: rootIds }, hidden: false, ...blockWhere },
          orderBy: [{ createdAt: "asc" }, { id: "asc" }],
          take: PAGE_SIZE * REPLY_LIMIT, // borne globale ; on tronque ensuite par parent
          include: {
            author: { include: { profile: { select: { displayName: true, rank: true } }, avatar: true } },
          },
        })
      : [];

    // Regroupe les réponses par racine (bornées à REPLY_LIMIT par racine). On ne garde que les
    // réponses dont le parentId pointe bien sur une racine de la page (robustesse).
    const rootIdSet = new Set(rootIds);
    const repliesByParent = new Map<string, typeof replies>();
    const keptReplies: typeof replies = [];
    for (const r of replies) {
      const key = r.parentId ?? "";
      if (!rootIdSet.has(key)) continue;
      const arr = repliesByParent.get(key) ?? [];
      if (arr.length < REPLY_LIMIT) {
        arr.push(r);
        keptReplies.push(r);
      }
      repliesByParent.set(key, arr);
    }

    // « Ai-je applaudi ? » : UNE requête bornée à tous les commentaires affichés (racines + réponses).
    const allIds = [...new Set([...rootIds, ...keptReplies.map((r) => r.id)])];
    const myKudos = allIds.length
      ? await this.prisma.commentReaction.findMany({
          where: { commentId: { in: allIds }, fromUserId: me },
          select: { commentId: true },
        })
      : [];
    const iKudoSet = new Set(myKudos.map((r) => r.commentId));

    // Mentions @pseudo résolues pour TOUS les commentaires affichés (1 requête profils).
    const mByComment = await this.mentions
      .resolveBatch([...page, ...keptReplies].map((c) => ({ id: c.id, body: c.body })))
      .catch(() => new Map<string, ResolvedMention[]>());

    const items = page.map((c) => {
      const childRows = repliesByParent.get(c.id) ?? [];
      const childItems = childRows.map((r) =>
        this.serialize(r, me, r.reactionCount ?? 0, iKudoSet.has(r.id), [], mByComment.get(r.id) ?? []),
      );
      return this.serialize(c, me, c.reactionCount ?? 0, iKudoSet.has(c.id), childItems, mByComment.get(c.id) ?? []);
    });

    return { items, nextCursor: hasMore ? page[page.length - 1].id : null };
  }

  /**
   * Applaudir un commentaire (kudos unifié 👏). Idempotent : un seul kudos par (commentaire, user).
   * Garde-fous : commentaire introuvable/masqué → 404 ; anti auto-kudos ; blocage (sens ou l'autre).
   * Notifie l'auteur du commentaire UNIQUEMENT au passage 0→1 (best-effort, jamais bloquant).
   */
  async react(me: string, commentId: string): Promise<{ kudosCount: number; iKudo: true }> {
    await enforceUserRateLimit(this.redis, RL_COMMENT_REACT.action, me, RL_COMMENT_REACT.limit, RL_COMMENT_REACT.windowSec);
    const comment = await this.prisma.comment.findUnique({
      where: { id: commentId },
      select: { id: true, authorId: true, hidden: true },
    });
    if (!comment || comment.hidden) {
      throw new NotFoundException({ code: "NOT_FOUND", message: "Commentaire introuvable." });
    }
    if (comment.authorId === me) {
      throw new ConflictException({ code: "CONFLICT", message: "Pas d'auto-kudos." });
    }
    if (await this.moderation.isBlockedBetween(me, comment.authorId)) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Action impossible avec cet utilisateur." });
    }
    // Passage 0→1 pour CE user : on note s'il applaudissait déjà avant l'upsert, pour ne notifier
    // qu'à un kudos RÉELLEMENT nouveau (pas à chaque re-like idempotent).
    const already = await this.prisma.commentReaction.findUnique({
      where: { commentId_fromUserId: { commentId, fromUserId: me } },
      select: { id: true },
    });
    await this.prisma.commentReaction.upsert({
      where: { commentId_fromUserId: { commentId, fromUserId: me } },
      create: { commentId, fromUserId: me },
      update: {},
    });
    const kudosCount = await this.syncReactionCount(commentId);
    if (!already) {
      try {
        await this.push.notifyCommentKudos(comment.authorId, kudosCount);
      } catch {
        // best-effort : silencieux (gating/no-op géré dans PushService)
      }
    }
    return { kudosCount, iKudo: true };
  }

  /** Retirer son kudos d'un commentaire (toggle off). Idempotent. */
  async unreact(me: string, commentId: string): Promise<{ kudosCount: number; iKudo: false }> {
    await this.prisma.commentReaction.deleteMany({ where: { commentId, fromUserId: me } });
    const kudosCount = await this.syncReactionCount(commentId);
    return { kudosCount, iKudo: false };
  }

  /** Recompte les kudos d'un commentaire et met à jour le compteur dénormalisé `reactionCount`. */
  private async syncReactionCount(commentId: string): Promise<number> {
    const count = await this.prisma.commentReaction.count({ where: { commentId } });
    await this.prisma.comment.update({ where: { id: commentId }, data: { reactionCount: count } }).catch(() => undefined);
    return count;
  }

  /** Suppression : autorisée à l'auteur du commentaire OU à l'auteur du post commenté. */
  async delete(me: string, commentId: string): Promise<{ removed: true }> {
    const comment = await this.prisma.comment.findUnique({
      where: { id: commentId },
      select: { authorId: true, parentId: true, post: { select: { authorId: true } } },
    });
    if (!comment) throw new NotFoundException({ code: "NOT_FOUND", message: "Commentaire introuvable." });
    if (comment.authorId !== me && comment.post.authorId !== me) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Tu ne peux pas supprimer ce commentaire." });
    }
    // Suppression d'une RÉPONSE : décrément atomique du compteur du parent (symétrie du create —
    // avant ce fix, replyCount surcomptait pour toujours après chaque suppression de réponse).
    if (comment.parentId != null) {
      await this.prisma.$transaction([
        this.prisma.comment.delete({ where: { id: commentId } }),
        this.prisma.comment.update({
          where: { id: comment.parentId },
          data: { replyCount: { decrement: 1 } },
        }),
      ]);
    } else {
      await this.prisma.comment.delete({ where: { id: commentId } });
    }
    return { removed: true };
  }

  private serialize(
    c: {
      id: string;
      postId: string;
      parentId?: string | null;
      body: string;
      authorId: string;
      createdAt: Date;
      replyCount?: number | null;
      author: { profile: { displayName: string; rank: string } | null; avatar: unknown };
    },
    me: string,
    kudosCount: number,
    iKudo: boolean,
    replies: CommentItem[] = [],
    mentions: ResolvedMention[] = [],
  ): CommentItem {
    return {
      id: c.id,
      postId: c.postId,
      parentId: c.parentId ?? null,
      body: c.body,
      createdAt: c.createdAt.toISOString(),
      author: {
        userId: c.authorId,
        displayName: c.author.profile?.displayName ?? "—",
        rank: c.author.profile?.rank ?? "rookie",
        isMe: c.authorId === me,
        avatar: serializeAvatar(c.author.avatar as never),
      },
      kudosCount,
      iKudo,
      replyCount: c.replyCount ?? 0,
      replies,
      mentions,
    };
  }
}
