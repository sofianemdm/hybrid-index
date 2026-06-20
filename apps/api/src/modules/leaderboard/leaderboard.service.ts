import { Injectable } from "@nestjs/common";
import type { Sex } from "@prisma/client";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";

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

export interface RivalResponse {
  state: "leader" | "active" | "none";
  gap: number | null;
  rival: { userId: string; displayName: string; value: number; position: number } | null;
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

  async leaderboard(sex: string, limit: number, meUserId?: string): Promise<LeaderboardResponse> {
    let rows = await this.redis.top(sex, limit);
    if (rows.length === 0) {
      rows = await this.pgTop(sex, limit);
    }

    const names = await this.namesFor(rows.map((r) => r.userId));
    const entries: LeaderboardEntry[] = rows.map((r, i) => ({
      position: i + 1,
      userId: r.userId,
      displayName: names.get(r.userId)?.displayName ?? "—",
      value: r.value,
      rank: names.get(r.userId)?.rank ?? "rookie",
      isMe: r.userId === meUserId,
    }));

    const total = (await this.redis.total(sex)) ?? (await this.pgCount(sex));

    let me: LeaderboardResponse["me"] = null;
    if (meUserId) {
      const pos = await this.positionOf(sex, meUserId);
      if (pos !== null) me = { position: pos.position, value: pos.value };
    }

    return { sex, total, entries, me };
  }

  async rival(userId: string): Promise<RivalResponse> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    const myIndex = await this.prisma.hybridIndex.findUnique({ where: { userId } });
    if (!profile || !myIndex) return { state: "none", gap: null, rival: null };

    const sex = profile.sex;
    const myPos = await this.positionOf(sex, userId);
    if (myPos === null) return { state: "none", gap: null, rival: null };
    if (myPos.position <= 1) return { state: "leader", gap: null, rival: null };

    // L'athlète juste au-dessus : déterminé via Postgres (autoritatif — la jointure profil ne
    // renvoie que de vrais utilisateurs, ce qui évite toute entrée Redis orpheline / divergence
    // et donc une référence rival_user_id vers un compte supprimé).
    const pg = await this.prisma.hybridIndex.findFirst({
      where: { value: { gt: myIndex.value }, user: { profile: { sex: sex as Sex } } },
      orderBy: { value: "asc" },
      select: { userId: true, value: true },
    });
    if (!pg) return { state: "leader", gap: null, rival: null };
    const above = { userId: pg.userId, value: pg.value };

    const names = await this.namesFor([above.userId]);
    const rivalProfile = names.get(above.userId);

    // Persiste l'état du rival (recalculé à la volée).
    await this.prisma.rival.upsert({
      where: { userId },
      create: { userId, rivalUserId: above.userId, rivalIndexValue: above.value, state: "active" },
      update: { rivalUserId: above.userId, rivalIndexValue: above.value, state: "active", recomputedAt: new Date() },
    });

    return {
      state: "active",
      gap: above.value - myIndex.value,
      rival: {
        userId: above.userId,
        displayName: rivalProfile?.displayName ?? "—",
        value: above.value,
        position: myPos.position - 1,
      },
    };
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

  private async namesFor(userIds: string[]): Promise<Map<string, { displayName: string; rank: string }>> {
    if (userIds.length === 0) return new Map();
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true, displayName: true, rank: true },
    });
    return new Map(profiles.map((p) => [p.userId, { displayName: p.displayName, rank: p.rank }]));
  }
}
