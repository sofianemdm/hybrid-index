import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService } from "../profile/profile-scoring.service";
import { LeaderboardService } from "../leaderboard/leaderboard.service";
import { cosmeticsFor } from "../engagement/badges.data";
import { serializeAvatar } from "../../common/avatar.serializer";

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
    // App 100 % publique (décision verrouillée) : tous les profils sont visibles. Le champ
    // `visibility` reste en base pour un usage futur mais N'EST PAS appliqué pour l'instant.
    if (!profile) {
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

    const [resultCount, followCount, badges, avatar, clubMembers] = await Promise.all([
      this.prisma.wodResult.count({ where: { userId } }),
      this.prisma.follow.count({ where: { followeeId: userId } }), // followers (suivi PAR)
      this.prisma.userBadge.findMany({ where: { userId }, select: { badgeId: true } }),
      this.prisma.avatar.findUnique({ where: { userId } }),
      this.prisma.clubMember.findMany({
        where: { userId },
        select: { club: { select: { name: true, status: true } } },
        orderBy: { joinedAt: "asc" },
      }),
    ]);
    // Clubs visibles de l'athlète (affichés sur son profil public). Vide s'il n'est dans aucun club.
    const clubs = clubMembers.filter((m) => m.club.status === "visible").map((m) => m.club.name);

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
      // Avatar évolutif visible sur le profil public (IC-03) + cosmétiques débloqués (G-03).
      avatar: serializeAvatar(avatar),
      activeCosmetics: cosmeticsFor(new Set(badges.map((b) => b.badgeId))),
      clubs, // noms des clubs de l'athlète (peut être vide)
    };
  }
}
