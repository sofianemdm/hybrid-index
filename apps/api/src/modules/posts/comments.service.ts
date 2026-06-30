import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";
import { PushService } from "../engagement/push.service";
import { serializeAvatar, type AvatarView } from "../../common/avatar.serializer";

const MAX_BODY = 500;
const PAGE_SIZE = 50;

/** Élément de commentaire normalisé pour le client. */
export interface CommentItem {
  id: string;
  postId: string;
  body: string;
  createdAt: string;
  author: { userId: string; displayName: string; rank: string; isMe: boolean; avatar: AvatarView | null };
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
  ) {}

  async create(me: string, postId: string, rawBody: string): Promise<CommentItem> {
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

    const comment = await this.prisma.comment.create({
      data: { postId, authorId: me, body },
      include: {
        author: { include: { profile: { select: { displayName: true, rank: true } }, avatar: true } },
      },
    });

    // Ré-engagement : on prévient l'AUTEUR du post (jamais le commentateur, ni en cas d'auto-commentaire).
    // Best-effort : un push KO ne doit jamais faire échouer la création du commentaire.
    if (post.authorId !== me) {
      try {
        await this.push.notifyComment(post.authorId, comment.author.profile?.displayName ?? "Un athlète");
      } catch {
        // silencieux (gating/no-op géré dans PushService)
      }
    }

    return this.serialize(comment, me);
  }

  /**
   * Liste paginée d'un post (du plus ancien au plus récent), hors commentaires masqués et hors
   * commentaires d'utilisateurs bloqués (dans un sens OU l'autre). Curseur = id du dernier vu.
   */
  async list(me: string, postId: string, cursor?: string): Promise<{ items: CommentItem[]; nextCursor: string | null }> {
    const blocked = await this.moderation.blockedIds(me);
    const rows = await this.prisma.comment.findMany({
      where: {
        postId,
        hidden: false,
        ...(blocked.length ? { authorId: { notIn: blocked } } : {}),
      },
      orderBy: [{ createdAt: "asc" }, { id: "asc" }],
      take: PAGE_SIZE + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        author: { include: { profile: { select: { displayName: true, rank: true } }, avatar: true } },
      },
    });
    const hasMore = rows.length > PAGE_SIZE;
    const page = hasMore ? rows.slice(0, PAGE_SIZE) : rows;
    return {
      items: page.map((c) => this.serialize(c, me)),
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  }

  /** Suppression : autorisée à l'auteur du commentaire OU à l'auteur du post commenté. */
  async delete(me: string, commentId: string): Promise<{ removed: true }> {
    const comment = await this.prisma.comment.findUnique({
      where: { id: commentId },
      select: { authorId: true, post: { select: { authorId: true } } },
    });
    if (!comment) throw new NotFoundException({ code: "NOT_FOUND", message: "Commentaire introuvable." });
    if (comment.authorId !== me && comment.post.authorId !== me) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Tu ne peux pas supprimer ce commentaire." });
    }
    await this.prisma.comment.delete({ where: { id: commentId } });
    return { removed: true };
  }

  private serialize(
    c: {
      id: string;
      postId: string;
      body: string;
      authorId: string;
      createdAt: Date;
      author: { profile: { displayName: string; rank: string } | null; avatar: unknown };
    },
    me: string,
  ): CommentItem {
    return {
      id: c.id,
      postId: c.postId,
      body: c.body,
      createdAt: c.createdAt.toISOString(),
      author: {
        userId: c.authorId,
        displayName: c.author.profile?.displayName ?? "—",
        rank: c.author.profile?.rank ?? "rookie",
        isMe: c.authorId === me,
        avatar: serializeAvatar(c.author.avatar as never),
      },
    };
  }
}
