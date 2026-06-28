import { Injectable, Logger } from "@nestjs/common";
import { Prisma, type Sex } from "@prisma/client";
import { popPercentileIndex, ratingFromInternal, type AttributeResult } from "@hybrid-index/scoring-core";
import type { AttributeKey, Goal } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { FeedEventsService } from "../social/feed-events.service";
import { StreakService } from "./streak.service";
import { BADGES, type BadgeContext, type BadgeDef, matchesCondition } from "./badges.data";

/** Population minimale d'une ligue pour que les badges « Top X% » aient du sens (cf. décision
 *  verrouillée : classements crédibles à partir de ~200 users). En dessous, on ne les attribue pas. */
/** Population minimale d'une ligue pour attribuer les badges « Top X% » (décision verrouillée :
 *  classements crédibles à partir de ~200 users). En dessous, on ne les attribue pas (audit G-08). */
const MIN_LEAGUE_FOR_PERCENTILE = 200;

/** Effectif minimal pour qu'un palier « Top X% » fin ait des places réelles (jamais de flatterie à
 *  vide) : Top 1 % exige ≥1000 users, Top 5 % ≥200, le reste ≥ MIN_LEAGUE_FOR_PERCENTILE. */
function leagueBadgeAllowed(condition: string, leagueTotal: number): boolean {
  const m = condition.match(/^percentile>=(.+)$/);
  if (!m) return true;
  const p = Number(m[1]);
  if (p >= 99) return leagueTotal >= 1000;
  if (p >= 95) return leagueTotal >= 200;
  return leagueTotal >= MIN_LEAGUE_FOR_PERCENTILE;
}

export interface BadgeView extends BadgeDef {
  unlocked: boolean;
  unlockedAt: string | null;
}

@Injectable()
export class BadgesService {
  private readonly logger = new Logger(BadgesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly streak: StreakService,
    private readonly feedEvents: FeedEventsService,
  ) {}

  private async buildContext(userId: string): Promise<BadgeContext> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    const idx = await this.prisma.hybridIndex.findUnique({ where: { userId } });
    const sex = (profile?.sex ?? "male") as Sex;

    const [logCount, followersCount, distinct, equipmentFreeCount, unlockedAttrs, streakState, attrRows] = await Promise.all([
      this.prisma.wodResult.count({ where: { userId } }),
      this.prisma.follow.count({ where: { followeeId: userId } }), // followers (suivi PAR)
      this.prisma.wodResult.findMany({ where: { userId }, distinct: ["wodId"], select: { wodId: true } }),
      this.prisma.wodResult.count({ where: { userId, wod: { requiresEquipment: false } } }),
      this.prisma.attributeScore.count({ where: { userId, unlocked: true } }),
      this.streak.evaluateAndGet(userId).catch((e) => {
        this.logger.warn(`Streak indisponible pour les badges (${userId}) : ${e}`);
        return { current: 0, best: 0 };
      }),
      this.prisma.attributeScore.findMany({ where: { userId }, select: { attribute: true, score: true, unlocked: true } }),
    ]);

    // Percentile « humanité » (normes de population) : top X% des humains les plus en forme.
    const radar: AttributeResult[] = attrRows.map((a) => ({
      attribute: a.attribute as AttributeKey,
      score: a.score,
      unlocked: a.unlocked,
      isEstimated: false,
      isStale: false,
      bestAgeWeeks: null,
    }));
    const popP = popPercentileIndex(sex, (profile?.goal ?? "all_round") as Goal, radar);
    const humanityTopPercent = Math.max(1, Math.round((1 - popP) * 100));

    // Percentile de ligue : seulement si la population est suffisante (sinon « Top 1% » trivial).
    let percentile = 0;
    let leagueTotal = 0;
    if (idx) {
      leagueTotal = await this.prisma.hybridIndex.count({ where: { user: { profile: { sex } } } });
      if (leagueTotal >= MIN_LEAGUE_FOR_PERCENTILE) {
        const above = await this.prisma.hybridIndex.count({
          where: { value: { gt: idx.value }, user: { profile: { sex } } },
        });
        percentile = (1 - above / leagueTotal) * 100;
      }
    }

    // « Pionnier » : inscrit à la toute première saison de Ligue.
    const firstSeason = await this.prisma.leagueSeason.findFirst({ orderBy: { createdAt: "asc" }, select: { id: true } });
    const isLeaguePioneer = firstSeason
      ? (await this.prisma.leagueEntry.findUnique({
          where: { seasonId_userId: { seasonId: firstSeason.id, userId } },
          select: { userId: true },
        })) != null
      : false;

    return {
      logCount,
      followersCount,
      distinctWods: distinct.length,
      equipmentFreeCount,
      rank: profile?.rank ?? "rookie",
      index: idx ? Math.round(ratingFromInternal(idx.value)) : 0, // OVR /100 (valeur déjà ajustée par couverture)
      percentile,
      leagueTotal,
      humanityTopPercent,
      attributesAllUnlocked: unlockedAttrs >= 6,
      streakCurrent: streakState.current,
      streakBest: streakState.best,
      isLeaguePioneer,
    };
  }

  /** Évalue toutes les conditions et attribue les badges manquants. Renvoie les nouveaux. */
  async evaluate(userId: string): Promise<BadgeDef[]> {
    const ctx = await this.buildContext(userId);
    const owned = new Set(
      (await this.prisma.userBadge.findMany({ where: { userId }, select: { badgeId: true } })).map((b) => b.badgeId),
    );
    // Première évaluation (compte neuf) : un athlète déjà fort débloque d'un coup une grappe de
    // badges. On les ATTRIBUE mais SANS inonder le feed — l'arrivée est annoncée par un unique
    // événement « member_joined » (cf. onboarding). Les déblocages ultérieurs s'annoncent un par un.
    const isFirstBatch = owned.size === 0;
    const newly: BadgeDef[] = [];
    for (const badge of BADGES) {
      if (owned.has(badge.id)) continue;
      if (!matchesCondition(badge.condition, ctx)) continue;
      // Paliers « Top X% » de ligue : bornés par effectif (Top 1 % ≥1000, Top 5 % ≥200) → plus de
      // « Top 1 % » mensonger à 20 membres (audit G-08).
      if (badge.category === "performance" && !leagueBadgeAllowed(badge.condition, ctx.leagueTotal)) continue;
      try {
        await this.prisma.userBadge.create({ data: { userId, badgeId: badge.id } });
        newly.push(badge); // poussé UNIQUEMENT si l'attribution a réussi (anti double-célébration).
      } catch (e) {
        // P2002 = déjà attribué par une requête concurrente : on ignore sans le compter comme nouveau.
        if (!(e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002")) {
          this.logger.warn(`Attribution badge ${badge.id} échouée (${userId}) : ${e}`);
        }
      }
    }
    // AAA anti-spam du feed Communauté : AU PLUS UN post par évaluation, et seulement pour un badge
    // PRESTIGIEUX (epic / legendary). Une grappe de seuils (ex. Index 68→95 d'un coup) ⇒ UN SEUL post,
    // le plus haut. Les badges common/rare se débloquent en silence (toujours visibles sur le profil).
    if (!isFirstBatch && newly.length > 0) {
      const RARITY: Record<string, number> = { common: 0, rare: 1, epic: 2, legendary: 3 };
      const headline = newly
        .filter((b) => RARITY[b.rarity] >= RARITY.epic)
        .sort((a, b) => RARITY[b.rarity] - RARITY[a.rarity] || (b.seriesOrder ?? 0) - (a.seriesOrder ?? 0))[0];
      if (headline) {
        await this.feedEvents.emit(userId, "badge_unlocked", {
          badgeId: headline.id,
          name: headline.name,
          rarity: headline.rarity,
        });
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

  /** Cosmétiques actifs d'un utilisateur = les `cosmeticUnlock` des badges qu'il a débloqués.
   *  Lecture seule (PAS d'évaluation) → sûr et rapide pour le profil/le classement. */
  async activeCosmetics(userId: string): Promise<string[]> {
    const owned = new Set(
      (await this.prisma.userBadge.findMany({ where: { userId }, select: { badgeId: true } })).map((b) => b.badgeId),
    );
    return BADGES.filter((b) => b.cosmeticUnlock && owned.has(b.id)).map((b) => b.cosmeticUnlock as string);
  }

  /** Vue « carte de joueur » : badges RÉELLEMENT gagnés (du plus récent au plus ancien) + cosmétiques
   *  actifs. Évalue d'abord (attribue les badges mérités), puis ne renvoie QUE les débloqués — forme
   *  compacte destinée à l'affichage sur la carte. */
  async cardForUser(userId: string): Promise<BadgeCard> {
    await this.evaluate(userId);
    const owned = await this.prisma.userBadge.findMany({
      where: { userId },
      select: { badgeId: true, unlockedAt: true },
    });
    const byId = new Map(BADGES.map((b) => [b.id, b]));
    const earned: EarnedBadge[] = owned
      .map((u): EarnedBadge | null => {
        const def = byId.get(u.badgeId);
        if (!def) return null; // badge retiré du catalogue mais encore en base → ignoré
        return {
          id: def.id,
          label: def.name,
          description: def.description,
          category: def.category,
          rarity: def.rarity,
          cosmeticUnlock: def.cosmeticUnlock,
          unlockedAt: u.unlockedAt.toISOString(),
        };
      })
      .filter((b): b is EarnedBadge => b !== null)
      .sort((a, b) => b.unlockedAt.localeCompare(a.unlockedAt)); // plus récent d'abord

    const ownedIds = new Set(earned.map((b) => b.id));
    const activeCosmetics = BADGES.filter((b) => b.cosmeticUnlock && ownedIds.has(b.id)).map(
      (b) => b.cosmeticUnlock as string,
    );
    return { earned, activeCosmetics, total: earned.length };
  }
}

/** Un badge gagné, forme compacte pour la carte de joueur. */
export interface EarnedBadge {
  id: string;
  label: string; // = name du catalogue
  description: string;
  category: string;
  rarity: string;
  cosmeticUnlock: string | null;
  unlockedAt: string; // ISO 8601
}

/** Réponse de la carte de joueur : badges gagnés + cosmétiques actifs. */
export interface BadgeCard {
  earned: EarnedBadge[];
  activeCosmetics: string[];
  total: number;
}
