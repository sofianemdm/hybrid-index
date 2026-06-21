import { BadRequestException, ConflictException, Injectable } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";
import { PostsService } from "../posts/posts.service";

const ALLOWED_EMOJIS = new Set(["💪", "🔥", "👏", "🚀"]);
/** Feed FINI (pas de scroll infini) : fenêtre bornée des activités les plus récentes. */
const FEED_LIMIT = 60;

@Injectable()
export class SocialService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
    private readonly moderation: ModerationService,
  ) {}

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

  // --- Recherche d'athlètes ---
  async explore(filters: { sex?: string; rank?: string; q?: string }): Promise<unknown[]> {
    const profiles = await this.prisma.profile.findMany({
      where: {
        visibility: "public",
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
        index: p.user.hybridIndex?.value ?? null,
      }))
      .sort((a, b) => (b.index ?? 0) - (a.index ?? 0));
  }

  // --- Feed unifié (événements auto + posts authored), FINI, hors utilisateurs bloqués ---
  async feed(me: string): Promise<unknown[]> {
    const [follows, blocked] = await Promise.all([
      this.prisma.follow.findMany({ where: { followerId: me }, select: { followeeId: true } }),
      this.moderation.blockedIds(me),
    ]);
    const blockedSet = new Set(blocked);
    const actorIds = [...new Set([...follows.map((f) => f.followeeId), me])].filter((id) => !blockedSet.has(id));

    const [events, postItems] = await Promise.all([
      this.prisma.feedEvent.findMany({
        where: { actorId: { in: actorIds }, visibility: "public" },
        orderBy: { createdAt: "desc" },
        take: FEED_LIMIT,
        include: {
          actor: { include: { profile: { select: { displayName: true, rank: true } } } },
          reactions: { select: { emoji: true, fromUserId: true } },
        },
      }),
      this.posts.forFeed(actorIds, me, FEED_LIMIT),
    ]);

    const eventItems = events.map((e) => {
      const counts: Record<string, number> = {};
      const mine: string[] = [];
      for (const r of e.reactions) {
        counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
        if (r.fromUserId === me) mine.push(r.emoji);
      }
      return {
        id: e.id,
        source: "event" as const,
        type: e.type as string,
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

    // Fusion + tri chronologique décroissant + fenêtre bornée (feed fini).
    return [...eventItems, ...postItems]
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, FEED_LIMIT);
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
