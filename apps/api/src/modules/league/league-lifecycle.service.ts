import { Injectable, Logger } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { isoWeekKey, weekStart } from "../engagement/iso-week";
import { addDaysUTC, monthBounds, monthKeyOf, pickMonthlyWods } from "./league.rotation";
import { totalsBestPerWeek, rankTotals } from "./league.aggregate";

/**
 * Cycle de vie d'une saison de Ligue (mensuelle). Au lancement : 2 ligues H/F, 1 WOD sans matériel
 * imposé par semaine, divisionTier = 1. Les méthodes sont idempotentes et appelables par le seed,
 * les tests, ou un cron (@nestjs/schedule, à brancher quand la dépendance est ajoutée).
 */
@Injectable()
export class LeagueLifecycleService {
  private readonly logger = new Logger(LeagueLifecycleService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Ouvre (idempotent) la saison du mois courant. */
  async openCurrentSeason(now = new Date()): Promise<{ id: string; monthKey: string }> {
    return this.openSeasonForMonth(monthKeyOf(now));
  }

  /** Crée (idempotent) la saison d'un mois + ses 4 semaines de WODs sans matériel. */
  async openSeasonForMonth(monthKey: string): Promise<{ id: string; monthKey: string }> {
    const existing = await this.prisma.leagueSeason.findUnique({ where: { monthKey } });
    if (existing) return { id: existing.id, monthKey };

    const pool = await this.bodyweightWodPool();
    if (pool.length === 0) {
      // Garde-fou : WODs non seedés ⇒ on ne crée pas une saison cassée (cf. seed obligatoire en prod).
      throw new Error("Aucun WOD sans matériel en base — seed manquant ?");
    }
    const wodIds = pickMonthlyWods(pool, monthKey, 4);
    const { opensAt, closesAt } = monthBounds(monthKey);
    const firstMonday = weekStart(opensAt);

    const season = await this.prisma.leagueSeason.create({
      data: {
        monthKey,
        status: "active",
        divisionTier: 1, // lancement : ligue unique par sexe
        opensAt,
        closesAt,
        weeks: {
          create: wodIds.map((wodId, i) => {
            const wkStart = addDaysUTC(firstMonday, i * 7);
            return {
              weekIndex: i + 1,
              weekKey: isoWeekKey(wkStart),
              wodId,
              filiere: "bodyweight" as const,
              opensAt: wkStart,
              closesAt: addDaysUTC(wkStart, 7),
            };
          }),
        },
      },
    });
    this.logger.log(`Saison de Ligue ouverte (${monthKey}) — WODs : ${wodIds.join(", ")}`);
    return { id: season.id, monthKey };
  }

  /**
   * Clôture une saison : fige le classement final par sexe dans `league_standing`, passe en `closed`.
   * Idempotent (ne fait rien si déjà close). Au lancement (tier=1), `movement = null`. L'Index n'est
   * JAMAIS touché ; le reset des points se fait naturellement par changement de saison le mois suivant.
   */
  async closeSeason(monthKey: string): Promise<void> {
    const season = await this.prisma.leagueSeason.findUnique({ where: { monthKey } });
    if (!season || season.status === "closed") return;

    const rows = await this.prisma.leaguePoints.findMany({
      where: { seasonId: season.id, review: "ok" },
      select: { userId: true, weekId: true, points: true, sex: true },
    });

    const standings: Array<{
      seasonId: string;
      userId: string;
      sex: "male" | "female";
      finalRank: number;
      totalPoints: number;
    }> = [];
    for (const sex of ["male", "female"] as const) {
      const sexRows = rows.filter((r) => r.sex === sex);
      const ranked = rankTotals(totalsBestPerWeek(sexRows));
      ranked.forEach((t, i) => {
        standings.push({
          seasonId: season.id,
          userId: t.userId,
          sex,
          finalRank: i + 1,
          totalPoints: t.total,
        });
      });
    }

    await this.prisma.$transaction([
      ...standings.map((s) =>
        this.prisma.leagueStanding.upsert({
          where: { seasonId_userId: { seasonId: s.seasonId, userId: s.userId } },
          create: { ...s, filiere: "bodyweight", level: "rx", movement: null },
          update: { finalRank: s.finalRank, totalPoints: s.totalPoints },
        }),
      ),
      this.prisma.leagueSeason.update({
        where: { id: season.id },
        data: { status: "closed", closedAt: new Date() },
      }),
    ]);
    this.logger.log(`Saison de Ligue close (${monthKey}) — ${standings.length} athlètes classés.`);
  }

  private async bodyweightWodPool(): Promise<string[]> {
    const wods = await this.prisma.wod.findMany({
      where: { requiresEquipment: false, isCustom: false },
      select: { id: true },
      orderBy: { id: "asc" },
    });
    return wods.map((w) => w.id);
  }
}
