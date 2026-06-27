import { Injectable } from "@nestjs/common";
import type { Sex } from "@prisma/client";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
import { avatarMapByUserId, type AvatarView } from "../../common/avatar.serializer";
import { primaryClubNameByUserId } from "../../common/club-lookup";

/** Valeur interne stockée (déjà ajustée par couverture) → OVR /100 affiché. Le tri (Redis/PG) se
 *  fait sur cette même valeur ajustée → classement et OVR cohérents. */
const ovr = (internal: number): number => Math.round(ratingFromInternal(internal));

export interface LeaderboardEntry {
  position: number; // 1-indexé
  userId: string;
  displayName: string;
  value: number;
  rank: string;
  isMe: boolean;
  avatar: AvatarView | null; // mini-vignette (mobile) ; null si l'athlète n'a pas d'avatar
  clubName: string | null; // club « principal » affiché à droite du nom ; null si sans club
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
        orderBy: [{ value: "desc" }, { userId: "asc" }], // tie-break déterministe (ordre total stable)
        take: limit,
        select: { userId: true, value: true },
      });
      rows = found.map((r) => ({ userId: r.userId, value: r.value }));
    } else {
      await this.ensureSynced(sex);
      rows = await this.redis.top(sex, limit);
      if (rows.length === 0) rows = await this.pgTop(sex, limit);
      // Redis départage les ex æquo par membre (userId) en ordre LEXICOGRAPHIQUE INVERSE, à l'opposé
      // de Postgres (userId asc). On re-trie pour un ordre total IDENTIQUE quelle que soit la source.
      rows = [...rows].sort((a, b) => b.value - a.value || (a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0));
    }

    const userIds = rows.map((r) => r.userId);
    const [names, avatars, clubs] = await Promise.all([
      this.namesFor(userIds),
      this.avatarsFor(userIds),
      this.clubsFor(userIds),
    ]);
    const entries: LeaderboardEntry[] = rows.map((r, i) => ({
      position: i + 1,
      userId: r.userId,
      displayName: names.get(r.userId)?.displayName ?? "—",
      value: ovr(r.value),
      rank: names.get(r.userId)?.rank ?? "rookie",
      isMe: r.userId === meUserId,
      avatar: avatars.get(r.userId) ?? null, // absent de la map = pas d'avatar → repli mobile
      clubName: clubs.get(r.userId) ?? null,
    }));

    let total: number;
    let me: LeaderboardResponse["me"] = null;
    if (memberIds) {
      total = await this.prisma.hybridIndex.count({ where: { userId: { in: memberIds }, user: { profile: { sex: sex as Sex } } } });
      if (meUserId) {
        const mine = await this.prisma.hybridIndex.findUnique({ where: { userId: meUserId }, select: { value: true } });
        if (mine) {
          // Position club avec le MÊME tie-break (value desc, userId asc) que la liste affichée.
          const base = { userId: { in: memberIds }, user: { profile: { sex: sex as Sex } } };
          const [strictlyAbove, tiedEarlier] = await Promise.all([
            this.prisma.hybridIndex.count({ where: { ...base, value: { gt: mine.value } } }),
            this.prisma.hybridIndex.count({ where: { ...base, value: mine.value, userId: { lt: meUserId } } }),
          ]);
          me = { position: strictlyAbove + tiedEarlier + 1, value: mine.value };
        }
      }
    } else {
      total = (await this.redis.total(sex)) ?? (await this.pgCount(sex));
      if (meUserId) {
        const pos = await this.positionOf(sex, meUserId);
        if (pos !== null) me = { position: pos.position, value: pos.value };
      }
    }

    return { sex, total, entries, me: me ? { position: me.position, value: ovr(me.value) } : null };
  }

  /** Position 1-indexée d'un utilisateur dans l'ordre total (value desc, userId asc). Calculée sur
   *  Postgres (le zrevrank Redis départage les ex æquo différemment → on ne l'utilise PAS pour la
   *  position, afin que liste, « ma position » et profil affichent TOUS le même rang). */
  async positionOf(sex: string, userId: string): Promise<{ position: number; value: number } | null> {
    const idx = await this.prisma.hybridIndex.findUnique({ where: { userId }, select: { value: true } });
    if (!idx) return null;
    const above = await this.aboveInTotalOrder(sex, idx.value, userId);
    return { position: above + 1, value: idx.value };
  }

  /** Nombre d'athlètes du même sexe STRICTEMENT devant dans l'ordre total : Index supérieur, OU
   *  Index égal mais userId inférieur (tie-break déterministe identique au tri des entrées). */
  private async aboveInTotalOrder(sex: string, value: number, userId: string): Promise<number> {
    const where = { user: { profile: { sex: sex as Sex } } };
    const [strictlyAbove, tiedEarlier] = await Promise.all([
      this.prisma.hybridIndex.count({ where: { ...where, value: { gt: value } } }),
      this.prisma.hybridIndex.count({ where: { ...where, value, userId: { lt: userId } } }),
    ]);
    return strictlyAbove + tiedEarlier;
  }

  // Anti-COUNT : on ne revérifie la synchro Redis/Postgres qu'au plus une fois par minute et par
  // sexe. Le classement est l'écran le plus consulté ; inutile de faire un COUNT Postgres à chaque
  // ouverture une fois synchro. La cohérence en écriture est assurée par setIndex/remove.
  private readonly lastSyncAt = new Map<string, number>();

  /** Auto-répare le sorted set Redis si son cardinal diffère de Postgres (seed sans REDIS_URL,
   *  flush Redis, comptes supprimés…). Postgres = source de vérité ; Redis = cache de tri rapide
   *  (décision verrouillée). Throttlé à 1×/min/sexe ; une fois synchro, plus de reconstruction. */
  private async ensureSynced(sex: string): Promise<void> {
    // Une écriture Redis ratée (setIndex/remove) a marqué le sexe « dirty » → reconstruction
    // IMMÉDIATE depuis Postgres, sans attendre le throttle ni un écart de cardinal (BUG-010 : un
    // score périmé à cardinal inchangé n'était jamais réparé).
    if (this.redis.consumeDirty(sex)) {
      await this.redis.rebuild(sex, await this.pgAll(sex));
      this.lastSyncAt.set(sex, Date.now());
      return;
    }
    const now = Date.now();
    if (now - (this.lastSyncAt.get(sex) ?? 0) < 60_000) return;
    const [rCount, pgCount] = await Promise.all([this.redis.total(sex), this.pgCount(sex)]);
    if (rCount === null) return; // Redis indisponible → pgTop prend le relais en lecture (pas de cache)
    if (rCount !== pgCount) {
      await this.redis.rebuild(sex, await this.pgAll(sex)); // reconstruction depuis la source de vérité
    }
    this.lastSyncAt.set(sex, now);
  }

  /** Toutes les entrées de classement d'un sexe (source de vérité Postgres), pour reconstruire Redis. */
  private async pgAll(sex: string): Promise<Array<{ userId: string; value: number }>> {
    const rows = await this.prisma.hybridIndex.findMany({
      where: { user: { profile: { sex: sex as Sex } } },
      orderBy: [{ value: "desc" }, { userId: "asc" }], // tie-break déterministe (ordre total stable)
      select: { userId: true, value: true },
    });
    return rows.map((r) => ({ userId: r.userId, value: r.value }));
  }

  private async pgTop(sex: string, limit: number): Promise<Array<{ userId: string; value: number }>> {
    const rows = await this.prisma.hybridIndex.findMany({
      where: { user: { profile: { sex: sex as Sex } } },
      orderBy: [{ value: "desc" }, { userId: "asc" }], // tie-break déterministe (ordre total stable)
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

  /** Avatars des athlètes affichés, en UNE requête batch (pas de N+1). Map userId -> vignette ;
   *  les athlètes sans avatar sont simplement absents → l'entrée porte `avatar: null`. */
  private async avatarsFor(userIds: string[]): Promise<Map<string, AvatarView>> {
    if (userIds.length === 0) return new Map();
    const avatars = await this.prisma.avatar.findMany({ where: { userId: { in: userIds } } });
    return avatarMapByUserId(avatars);
  }

  /** Club « principal » (1er rejoint, visible) des athlètes affichés, en UNE requête batch. Map
   *  userId -> nom de club ; les athlètes sans club sont absents → l'entrée porte `clubName: null`. */
  private async clubsFor(userIds: string[]): Promise<Map<string, string>> {
    if (userIds.length === 0) return new Map();
    const rows = await this.prisma.clubMember.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true, club: { select: { name: true, status: true } } },
      orderBy: { joinedAt: "asc" },
    });
    return primaryClubNameByUserId(rows);
  }
}
