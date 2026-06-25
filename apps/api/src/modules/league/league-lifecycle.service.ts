import { Injectable, Logger, type OnApplicationBootstrap } from "@nestjs/common";
import { Cron } from "@nestjs/schedule";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { isoWeekKey } from "../engagement/iso-week";
import { addDaysUTC, isoWeeksOfMonth, monthBounds, monthKeyOf, pickMonthlyWods } from "./league.rotation";
import { totalsBestPerWeek, rankTotals } from "./league.aggregate";

// WODs SANS matériel exclus du pool imposé (trop longs / non répétables chaque semaine sans risque) —
// cf. spec sport-science. Ils restent jouables pour l'Index, mais ne sont jamais imposés en Ligue.
const LEAGUE_EXCLUDED_WODS = ["marathon", "half_marathon", "track_10000m", "run_free_distance", "max_air_squats", "murph"];

/**
 * Cycle de vie d'une saison de Ligue (mensuelle). Au lancement : 2 ligues H/F, 1 WOD sans matériel
 * imposé par semaine, divisionTier = 1. Les méthodes sont idempotentes et appelables par le seed,
 * les tests, ou un cron (@nestjs/schedule, à brancher quand la dépendance est ajoutée).
 */
@Injectable()
export class LeagueLifecycleService implements OnApplicationBootstrap {
  private readonly logger = new Logger(LeagueLifecycleService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Au démarrage de l'app : clôture les saisons échues et assure la saison du mois courant
   * (idempotent). Garantit qu'une Ligue existe dès le déploiement, sans attendre le 1er du mois.
   * Best-effort : une erreur (ex. WODs non seedés) est loguée mais ne bloque pas le boot.
   */
  async onApplicationBootstrap(): Promise<void> {
    // En test, on n'ouvre pas de saison automatiquement (les e2e gèrent leurs propres saisons).
    if (process.env.NODE_ENV === "test") return;
    await this.closeOverdueSeasons().catch((e) => this.logger.warn(`Clôture échues au boot KO : ${e}`));
    await this.openCurrentSeason().catch((e) => this.logger.warn(`Ouverture saison au boot KO : ${e}`));
  }

  /** Bascule mensuelle : le 1er du mois à 00:05 UTC, clôt la saison écoulée et ouvre la nouvelle. */
  @Cron("5 0 1 * *")
  async monthlyRollover(): Promise<void> {
    await this.closeOverdueSeasons();
    await this.openCurrentSeason();
  }

  /** Clôt toutes les saisons `active` dont la date de fin est passée (archivage + reset par mois suivant). */
  async closeOverdueSeasons(now = new Date()): Promise<void> {
    const overdue = await this.prisma.leagueSeason.findMany({
      where: { status: "active", closesAt: { lte: now } },
      select: { monthKey: true },
    });
    for (const s of overdue) await this.closeSeason(s.monthKey);
  }

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
    const { opensAt, closesAt } = monthBounds(monthKey);
    // Une semaine imposée par SEMAINE ISO du mois (4 à 6) → aucun jour du mois sans WOD imposé.
    const weekStarts = isoWeeksOfMonth(monthKey);
    const wodIds = pickMonthlyWods(pool, monthKey, weekStarts.length);

    const season = await this.prisma.leagueSeason.create({
      data: {
        monthKey,
        status: "active",
        divisionTier: 1, // lancement : ligue unique par sexe
        opensAt,
        closesAt,
        weeks: {
          create: weekStarts.map((wkStart, i) => ({
            weekIndex: i + 1,
            weekKey: isoWeekKey(wkStart),
            wodId: wodIds[i % wodIds.length],
            filiere: "bodyweight" as const,
            opensAt: wkStart,
            closesAt: addDaysUTC(wkStart, 7),
          })),
        },
      },
    });
    this.logger.log(`Saison de Ligue ouverte (${monthKey}) — ${weekStarts.length} semaines, WODs : ${wodIds.join(", ")}`);
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
      where: { requiresEquipment: false, isCustom: false, id: { notIn: LEAGUE_EXCLUDED_WODS } },
      select: { id: true },
      orderBy: { id: "asc" },
    });
    return wods.map((w) => w.id);
  }
}
