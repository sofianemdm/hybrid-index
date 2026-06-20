import { BadRequestException, ConflictException, Injectable } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";

const ALLOWED_EMOJIS = new Set(["💪", "🔥", "👏", "🚀"]);

@Injectable()
export class SocialService {
  constructor(private readonly prisma: PrismaService) {}

  // --- Follow ---
  async follow(me: string, target: string): Promise<{ following: true }> {
    if (me === target) throw new BadRequestException({ code: "VALIDATION_ERROR", message: "On ne se suit pas soi-même." });
    const exists = await this.prisma.user.findUnique({ where: { id: target }, select: { id: true } });
    if (!exists) throw new BadRequestException({ code: "NOT_FOUND", message: "Athlète introuvable." });
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

  // --- Kudos / réactions ---
  async react(me: string, feedEventId: string, emoji: string): Promise<{ emoji: string }> {
    if (!ALLOWED_EMOJIS.has(emoji)) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Réaction non autorisée." });
    }
    const event = await this.prisma.feedEvent.findUnique({ where: { id: feedEventId }, select: { actorId: true } });
    if (!event) throw new BadRequestException({ code: "NOT_FOUND", message: "Événement introuvable." });
    if (event.actorId === me) throw new ConflictException({ code: "CONFLICT", message: "Pas d'auto-kudos." });
    // 1 réaction par user par event (emoji modifiable) : on remplace l'éventuelle précédente.
    await this.prisma.reaction.deleteMany({ where: { fromUserId: me, feedEventId } });
    await this.prisma.reaction.create({ data: { fromUserId: me, feedEventId, emoji } });
    return { emoji };
  }

  async unreact(me: string, feedEventId: string): Promise<{ removed: true }> {
    await this.prisma.reaction.deleteMany({ where: { fromUserId: me, feedEventId } });
    return { removed: true };
  }

  // --- Feed ---
  async feed(me: string): Promise<unknown[]> {
    const follows = await this.prisma.follow.findMany({ where: { followerId: me }, select: { followeeId: true } });
    const actorIds = [...follows.map((f) => f.followeeId), me];
    const events = await this.prisma.feedEvent.findMany({
      where: { actorId: { in: actorIds }, visibility: "public" },
      orderBy: { createdAt: "desc" },
      take: 50,
      include: {
        actor: { include: { profile: { select: { displayName: true, rank: true } } } },
        reactions: { select: { emoji: true, fromUserId: true } },
      },
    });
    return events.map((e) => {
      const counts: Record<string, number> = {};
      const mine: string[] = [];
      for (const r of e.reactions) {
        counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
        if (r.fromUserId === me) mine.push(r.emoji);
      }
      return {
        id: e.id,
        type: e.type,
        createdAt: e.createdAt.toISOString(),
        actor: {
          userId: e.actorId,
          displayName: e.actor.profile?.displayName ?? "—",
          rank: e.actor.profile?.rank ?? "rookie",
          isMe: e.actorId === me,
        },
        payload: e.payload,
        reactions: counts,
        myReactions: mine,
      };
    });
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
      index: user.hybridIndex?.value ?? null,
    };
  }
}
