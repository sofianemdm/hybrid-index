import { Injectable } from "@nestjs/common";
import type { Sex } from "@prisma/client";
import { indexDisplayRating } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";

/** Valeur interne /1000 → OVR /100 affiché (shrinkage de couverture inclus ; le tri reste sur la
 *  valeur interne). `coverage` = nb d'attributs débloqués ; 6 par défaut (aucun shrinkage). */
const ovr = (internal: number, coverage = 6): number => Math.round(indexDisplayRating(internal, coverage));

export interface LeaderboardEntry {
  position: number; // 1-indexé
  userId: string;
  displayName: string;
  value: number;
  rank: string;
  isMe: boolean;
}

export interface LeaderboardResponse {
  sex: string;
  total: number;
  entries: LeaderboardEntry[];
  me: { position: number; value: number } | null;
}

/**
 * Classement par ligue (sexe) trié par HYBRID INDEX. Source de rang : sorted set Redis
 * (décision verrouillée) ; repli sur Postgres (source durable) si Redis est indisponible.
 */
@Injectable()
export class LeaderboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async leaderboard(sex: string, limit: number, meUserId?: string, memberIds?: string[]): Promise<LeaderboardResponse> {
    // Filtre club (C3) : on restreint à l'ensemble des membres via Postgres (la ligue globale, elle,
    // reste entière côté Redis). Le club n'est PAS une nouvelle ligue, juste une vue filtrée.
    let rows: Array<{ userId: string; value: number }>;
    if (memberIds) {
      const found = await this.prisma.hybridIndex.findMany({
        where: { userId: { in: memberIds }, user: { profile: { sex: sex as Sex } } },
        orderBy: { value: "desc" },
        take: limit,
        select: { userId: true, value: true },
      });
      rows = found.map((r) => ({ userId: r.userId, value: r.value }));
    } else {
      rows = await this.redis.top(sex, limit);
      if (rows.length === 0) rows = await this.pgTop(sex, limit);
    }

    const names = await this.namesFor(rows.map((r) => r.userId));
    const coverage = await this.coverageFor(rows.map((r) => r.userId));
    const entries: LeaderboardEntry[] = rows.map((r, i) => ({
      position: i + 1,
      userId: r.userId,
      displayName: names.get(r.userId)?.displayName ?? "—",
      value: ovr(r.value, coverage.get(r.userId) ?? 6),
      rank: names.get(r.userId)?.rank ?? "rookie",
      isMe: r.userId === meUserId,
    }));

    let total: number;
    let me: LeaderboardResponse["me"] = null;
    if (memberIds) {
      total = await this.prisma.hybridIndex.count({ where: { userId: { in: memberIds }, user: { profile: { sex: sex as Sex } } } });
      if (meUserId) {
        const mine = await this.prisma.hybridIndex.findUnique({ where: { userId: meUserId }, select: { value: true } });
        if (mine) {
          const above = await this.prisma.hybridIndex.count({
            where: { userId: { in: memberIds }, value: { gt: mine.value }, user: { profile: { sex: sex as Sex } } },
          });
          me = { position: above + 1, value: mine.value };
        }
      }
    } else {
      total = (await this.redis.total(sex)) ?? (await this.pgCount(sex));
      if (meUserId) {
        const pos = await this.positionOf(sex, meUserId);
        if (pos !== null) me = { position: pos.position, value: pos.value };
      }
    }

    let meCoverage = 6;
    if (me && meUserId) {
      meCoverage = coverage.get(meUserId) ?? (await this.coverageFor([meUserId])).get(meUserId) ?? 6;
    }
    return { sex, total, entries, me: me ? { position: me.position, value: ovr(me.value, meCoverage) } : null };
  }

  /** Position 1-indexée + valeur d'un utilisateur, via Redis puis Postgres. */
  async positionOf(sex: string, userId: string): Promise<{ position: number; value: number } | null> {
    const idx = await this.prisma.hybridIndex.findUnique({ where: { userId }, select: { value: true } });
    if (!idx) return null;

    const rRank = await this.redis.rank(sex, userId);
    if (rRank !== null) return { position: rRank + 1, value: idx.value };

    // Postgres : combien d'athlètes du même sexe ont un Index strictement supérieur.
    const above = await this.prisma.hybridIndex.count({
      where: { value: { gt: idx.value }, user: { profile: { sex: sex as Sex } } },
    });
    return { position: above + 1, value: idx.value };
  }

  private async pgTop(sex: string, limit: number): Promise<Array<{ userId: string; value: number }>> {
    const rows = await this.prisma.hybridIndex.findMany({
      where: { user: { profile: { sex: sex as Sex } } },
      orderBy: { value: "desc" },
      take: limit,
      select: { userId: true, value: true },
    });
    return rows.map((r) => ({ userId: r.userId, value: r.value }));
  }

  private async pgCount(sex: string): Promise<number> {
    return this.prisma.hybridIndex.count({ where: { user: { profile: { sex: sex as Sex } } } });
  }

  /** Couverture du radar (nb d'attributs débloqués) par userId — pour le shrinkage d'affichage. */
  private async coverageFor(userIds: string[]): Promise<Map<string, number>> {
    if (userIds.length === 0) return new Map();
    const rows = await this.prisma.hybridIndex.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true, radarCoverage: true },
    });
    return new Map(rows.map((r) => [r.userId, r.radarCoverage]));
  }

  private async namesFor(userIds: string[]): Promise<Map<string, { displayName: string; rank: string }>> {
    if (userIds.length === 0) return new Map();
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true, displayName: true, rank: true },
    });
    return new Map(profiles.map((p) => [p.userId, { displayName: p.displayName, rank: p.rank }]));
  }
}
