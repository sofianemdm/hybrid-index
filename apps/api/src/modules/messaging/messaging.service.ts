import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { dmAgeAllowed } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";

const MAX_BODY = 2000;

export interface DmEligibility {
  allowed: boolean;
  reason?: "self" | "blocked" | "age" | "not_connected";
}

/**
 * Messagerie privée (Phase C5). Portée PRUDENTE : on n'écrit qu'à quelqu'un avec qui on a un
 * lien réel (abonnement mutuel OU club commun), jamais à un inconnu, jamais en cas de blocage,
 * et UNIQUEMENT dans la même tranche d'âge (séparation stricte mineurs/adultes — voir contracts).
 */
@Injectable()
export class MessagingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly moderation: ModerationService,
  ) {}

  /** Couple canonique (ordre stable) pour une conversation 1‑à‑1. */
  private pair(a: string, b: string): { userAId: string; userBId: string } {
    return a < b ? { userAId: a, userBId: b } : { userAId: b, userBId: a };
  }

  /** Lien social requis : abonnement MUTUEL ou appartenance à un club commun. */
  private async areConnected(me: string, other: string): Promise<boolean> {
    const mutual = await this.prisma.follow.count({
      where: { OR: [{ followerId: me, followeeId: other }, { followerId: other, followeeId: me }] },
    });
    if (mutual >= 2) return true;
    const sharedClub = await this.prisma.clubMember.count({
      where: { userId: me, club: { members: { some: { userId: other } } } },
    });
    return sharedClub > 0;
  }

  async eligibility(me: string, other: string): Promise<DmEligibility> {
    if (me === other) return { allowed: false, reason: "self" };
    const [meUser, otherUser] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: me }, select: { dateOfBirth: true } }),
      this.prisma.user.findUnique({ where: { id: other }, select: { dateOfBirth: true } }),
    ]);
    if (!meUser || !otherUser) return { allowed: false, reason: "not_connected" };
    if (await this.moderation.isBlockedBetween(me, other)) return { allowed: false, reason: "blocked" };
    if (!dmAgeAllowed(meUser.dateOfBirth, otherUser.dateOfBirth, new Date())) return { allowed: false, reason: "age" };
    if (!(await this.areConnected(me, other))) return { allowed: false, reason: "not_connected" };
    return { allowed: true };
  }

  private async assertCanDm(me: string, other: string): Promise<void> {
    const elig = await this.eligibility(me, other);
    if (elig.allowed) return;
    const messages: Record<NonNullable<DmEligibility["reason"]>, string> = {
      self: "On ne s'écrit pas à soi-même.",
      blocked: "Échange impossible avec cet utilisateur.",
      age: "Les messages privés ne sont possibles qu'entre comptes de la même tranche d'âge.",
      not_connected: "Tu dois vous suivre mutuellement ou partager un club pour échanger en privé.",
    };
    throw new ForbiddenException({ code: "DM_NOT_ALLOWED", message: messages[elig.reason ?? "not_connected"] });
  }

  /** Envoie un message (crée la conversation au besoin). */
  async send(me: string, toUserId: string, rawBody: string): Promise<unknown> {
    const body = rawBody.trim();
    if (!body) throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Message vide." });
    if (body.length > MAX_BODY) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: `Message limité à ${MAX_BODY} caractères.` });
    }
    await this.assertCanDm(me, toUserId);

    const { userAId, userBId } = this.pair(me, toUserId);
    const now = new Date();
    const conv = await this.prisma.conversation.upsert({
      where: { userAId_userBId: { userAId, userBId } },
      create: { userAId, userBId, lastMessageAt: now },
      update: { lastMessageAt: now },
    });
    const msg = await this.prisma.message.create({
      data: { conversationId: conv.id, senderId: me, body },
    });
    return {
      conversationId: conv.id,
      message: { id: msg.id, senderId: me, body: msg.body, createdAt: msg.createdAt.toISOString(), isMine: true },
    };
  }

  /** Mes conversations (autre participant + dernier message + non-lus). */
  async conversations(me: string): Promise<unknown[]> {
    const convs = await this.prisma.conversation.findMany({
      where: { OR: [{ userAId: me }, { userBId: me }], lastMessageAt: { not: null } },
      orderBy: { lastMessageAt: "desc" },
      take: 50,
      include: {
        userA: { include: { profile: { select: { displayName: true, rank: true } } } },
        userB: { include: { profile: { select: { displayName: true, rank: true } } } },
        messages: { orderBy: { createdAt: "desc" }, take: 1 },
      },
    });
    const result = [];
    for (const c of convs) {
      const other = c.userAId === me ? c.userB : c.userA;
      const last = c.messages[0];
      const unread = await this.prisma.message.count({
        where: { conversationId: c.id, senderId: { not: me }, readAt: null },
      });
      result.push({
        id: c.id,
        other: {
          userId: other.id,
          displayName: other.profile?.displayName ?? "—",
          rank: other.profile?.rank ?? "rookie",
        },
        lastMessage: last ? { body: last.body, createdAt: last.createdAt.toISOString(), isMine: last.senderId === me } : null,
        unread,
      });
    }
    return result;
  }

  /** Messages d'une conversation (participant requis) + marquage comme lus. */
  async messages(me: string, conversationId: string): Promise<unknown> {
    const conv = await this.prisma.conversation.findUnique({ where: { id: conversationId } });
    if (!conv) throw new NotFoundException({ code: "NOT_FOUND", message: "Conversation introuvable." });
    if (conv.userAId !== me && conv.userBId !== me) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Conversation non accessible." });
    }
    const otherId = conv.userAId === me ? conv.userBId : conv.userAId;
    const [rows, other] = await Promise.all([
      this.prisma.message.findMany({
        where: { conversationId, status: "visible" },
        orderBy: { createdAt: "asc" },
        take: 200,
      }),
      this.prisma.user.findUnique({
        where: { id: otherId },
        include: { profile: { select: { displayName: true, rank: true } } },
      }),
    ]);
    await this.prisma.message.updateMany({
      where: { conversationId, senderId: { not: me }, readAt: null },
      data: { readAt: new Date() },
    });
    return {
      id: conv.id,
      other: {
        userId: otherId,
        displayName: other?.profile?.displayName ?? "—",
        rank: other?.profile?.rank ?? "rookie",
      },
      messages: rows.map((m) => ({
        id: m.id,
        senderId: m.senderId,
        body: m.body,
        createdAt: m.createdAt.toISOString(),
        isMine: m.senderId === me,
      })),
    };
  }
}
