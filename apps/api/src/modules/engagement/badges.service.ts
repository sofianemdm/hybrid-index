import { Injectable } from "@nestjs/common";
import type { Sex } from "@prisma/client";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { LeaderboardService } from "../leaderboard/leaderboard.service";
import { StreakService } from "./streak.service";
import { BADGES, type BadgeContext, type BadgeDef, matchesCondition } from "./badges.data";

export interface BadgeView extends BadgeDef {
  unlocked: boolean;
  unlockedAt: string | null;
}

@Injectable()
export class BadgesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly leaderboard: LeaderboardService,
    private readonly streak: StreakService,
  ) {}

  private async buildContext(userId: string): Promise<BadgeContext> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    const idx = await this.prisma.hybridIndex.findUnique({ where: { userId } });
    const sex = (profile?.sex ?? "male") as Sex;

    const [logCount, distinct, equipmentFreeCount, unlockedAttrs, streakState] = await Promise.all([
      this.prisma.wodResult.count({ where: { userId } }),
      this.prisma.wodResult.findMany({ where: { userId }, distinct: ["wodId"], select: { wodId: true } }),
      this.prisma.wodResult.count({ where: { userId, wod: { requiresEquipment: false } } }),
      this.prisma.attributeScore.count({ where: { userId, unlocked: true } }),
      this.streak.evaluateAndGet(userId).catch(() => ({ current: 0, best: 0 })),
    ]);

    let percentile = 0;
    if (idx) {
      const total = await this.prisma.hybridIndex.count({ where: { user: { profile: { sex } } } });
      const above = await this.prisma.hybridIndex.count({
        where: { value: { gt: idx.value }, user: { profile: { sex } } },
      });
      percentile = total > 0 ? (1 - above / total) * 100 : 0;
    }

    const rival = await this.leaderboard.rival(userId).catch(() => ({ state: "none" as const }));

    return {
      logCount,
      distinctWods: distinct.length,
      equipmentFreeCount,
      rank: profile?.rank ?? "rookie",
      index: idx?.value ?? 0,
      percentile,
      attributesAllUnlocked: unlockedAttrs >= 6,
      streakCurrent: streakState.current,
      streakBest: streakState.best,
      beatRival: rival.state === "leader",
    };
  }

  /** Évalue toutes les conditions et attribue les badges manquants. Renvoie les nouveaux. */
  async evaluate(userId: string): Promise<BadgeDef[]> {
    const ctx = await this.buildContext(userId);
    const owned = new Set(
      (await this.prisma.userBadge.findMany({ where: { userId }, select: { badgeId: true } })).map((b) => b.badgeId),
    );
    const newly: BadgeDef[] = [];
    for (const badge of BADGES) {
      if (owned.has(badge.id)) continue;
      if (matchesCondition(badge.condition, ctx)) {
        await this.prisma.userBadge.create({ data: { userId, badgeId: badge.id } }).catch(() => undefined);
        newly.push(badge);
      }
    }
    return newly;
  }

  /** Liste tous les badges avec leur statut (débloqué ou non) pour l'utilisateur. */
  async listForUser(userId: string): Promise<BadgeView[]> {
    await this.evaluate(userId);
    const owned = new Map(
      (await this.prisma.userBadge.findMany({ where: { userId } })).map((b) => [b.badgeId, b.unlockedAt]),
    );
    return BADGES.map((b) => ({
      ...b,
      unlocked: owned.has(b.id),
      unlockedAt: owned.get(b.id)?.toISOString() ?? null,
    }));
  }
}
