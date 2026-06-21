import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";

const ALLOWED_EMOJIS = new Set(["💪", "🔥", "👏", "🚀"]);
const MAX_BODY = 500;

export interface CreatePostInput {
  kind: "text" | "perf_share";
  body?: string;
  wodResultId?: string;
}

/** Élément de feed normalisé (même forme qu'un FeedEvent côté client). */
export interface FeedPostItem {
  id: string;
  source: "post";
  type: "post_text" | "post_perf";
  createdAt: string;
  actor: { userId: string; displayName: string; rank: string; isMe: boolean };
  payload: Record<string, unknown>;
  reactions: Record<string, number>;
  myReactions: string[];
}

/** Posts authored par les utilisateurs (texte ou partage de perf). Photos NON gérées pour l'instant. */
@Injectable()
export class PostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly moderation: ModerationService,
  ) {}

  async create(me: string, input: CreatePostInput): Promise<FeedPostItem> {
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
        subScore: res.subScore ?? null,
      };
    }

    const post = await this.prisma.post.create({
      data: {
        authorId: me,
        kind: input.kind,
        body: body && body.length > 0 ? body : null,
        wodResultId: wodResultId ?? null,
      },
      include: { author: { include: { profile: { select: { displayName: true, rank: true } } } } },
    });

    return {
      id: post.id,
      source: "post",
      type: input.kind === "perf_share" ? "post_perf" : "post_text",
      createdAt: post.createdAt.toISOString(),
      actor: {
        userId: me,
        displayName: post.author.profile?.displayName ?? "—",
        rank: post.author.profile?.rank ?? "rookie",
        isMe: true,
      },
      payload: { body: post.body, ...payloadExtra },
      reactions: {},
      myReactions: [],
    };
  }

  async delete(me: string, postId: string): Promise<{ removed: true }> {
    const post = await this.prisma.post.findUnique({ where: { id: postId }, select: { authorId: true } });
    if (!post) throw new NotFoundException({ code: "NOT_FOUND", message: "Post introuvable." });
    if (post.authorId !== me) throw new ForbiddenException({ code: "FORBIDDEN", message: "Tu ne peux supprimer que tes posts." });
    await this.prisma.post.delete({ where: { id: postId } });
    return { removed: true };
  }

  async react(me: string, postId: string, emoji: string): Promise<{ emoji: string }> {
    if (!ALLOWED_EMOJIS.has(emoji)) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Réaction non autorisée." });
    }
    const post = await this.prisma.post.findUnique({ where: { id: postId }, select: { authorId: true } });
    if (!post) throw new NotFoundException({ code: "NOT_FOUND", message: "Post introuvable." });
    if (post.authorId === me) throw new ConflictException({ code: "CONFLICT", message: "Pas d'auto-kudos." });
    await this.prisma.postReaction.upsert({
      where: { postId_fromUserId: { postId, fromUserId: me } },
      create: { postId, fromUserId: me, emoji },
      update: { emoji },
    });
    await this.syncCount(postId);
    return { emoji };
  }

  async unreact(me: string, postId: string): Promise<{ removed: true }> {
    await this.prisma.postReaction.deleteMany({ where: { postId, fromUserId: me } });
    await this.syncCount(postId);
    return { removed: true };
  }

  private async syncCount(postId: string): Promise<void> {
    const count = await this.prisma.postReaction.count({ where: { postId } });
    await this.prisma.post.update({ where: { id: postId }, data: { reactionCount: count } }).catch(() => undefined);
  }

  /** Posts (texte + perf) des `actorIds`, normalisés pour le feed unifié. Exclut les statuts non visibles. */
  async forFeed(actorIds: string[], me: string, take: number): Promise<FeedPostItem[]> {
    if (actorIds.length === 0) return [];
    const posts = await this.prisma.post.findMany({
      where: { authorId: { in: actorIds }, status: "visible", visibility: "public" },
      orderBy: { createdAt: "desc" },
      take,
      include: {
        author: { include: { profile: { select: { displayName: true, rank: true } } } },
        reactions: { select: { emoji: true, fromUserId: true } },
      },
    });

    // Hydrate les perf_share avec les infos de séance.
    const resultIds = posts.map((p) => p.wodResultId).filter((x): x is string => !!x);
    const results = resultIds.length
      ? await this.prisma.wodResult.findMany({
          where: { id: { in: resultIds } },
          include: { wod: { select: { id: true, name: true, scoreType: true } } },
        })
      : [];
    const byId = new Map(results.map((r) => [r.id, r]));

    return posts.map((p) => {
      const counts: Record<string, number> = {};
      const mine: string[] = [];
      for (const r of p.reactions) {
        counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
        if (r.fromUserId === me) mine.push(r.emoji);
      }
      const payload: Record<string, unknown> = { body: p.body };
      if (p.kind === "perf_share" && p.wodResultId) {
        const res = byId.get(p.wodResultId);
        if (res) {
          payload.wodId = res.wod.id;
          payload.wodName = res.wod.name;
          payload.scoreType = res.wod.scoreType;
          payload.rawResult = Number(res.rawResult);
          payload.subScore = res.subScore ?? null;
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
          isMe: p.authorId === me,
        },
        payload,
        reactions: counts,
        myReactions: mine,
      };
    });
  }
}
