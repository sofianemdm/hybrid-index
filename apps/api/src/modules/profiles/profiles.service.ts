import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService } from "../profile/profile-scoring.service";
import { LeaderboardService } from "../leaderboard/leaderboard.service";

/** Profil public d'un athlète (tout est public — décision verrouillée). */
@Injectable()
export class ProfilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly profileScoring: ProfileScoringService,
    private readonly leaderboard: LeaderboardService,
  ) {}

  async publicProfile(userId: string, viewerId?: string): Promise<unknown> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile || profile.visibility !== "public") {
      throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable ou privé." });
    }
    const scoring = await this.profileScoring.getMyProfile(userId);
    const pos = await this.leaderboard.positionOf(profile.sex, userId);

    let isFollowing = false;
    if (viewerId && viewerId !== userId) {
      const f = await this.prisma.follow.findUnique({
        where: { followerId_followeeId: { followerId: viewerId, followeeId: userId } },
      });
      isFollowing = !!f;
    }

    const [resultCount, followCount] = await Promise.all([
      this.prisma.wodResult.count({ where: { userId } }),
      this.prisma.follow.count({ where: { followerId: userId } }),
    ]);

    return {
      userId,
      isConfirmed: resultCount >= 5 && followCount >= 5, // « Athlète confirmé » (anti-bot)
      displayName: profile.displayName,
      sex: profile.sex,
      goal: profile.goal,
      rank: profile.rank,
      index: scoring?.index ?? null,
      radar: scoring?.radar ?? [],
      position: pos?.position ?? null,
      isFollowing,
      isMe: viewerId === userId,
    };
  }
}
