import { Injectable, Logger } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { isoWeekKey } from "../engagement/iso-week";
import { leagueWeekPoints } from "./league-points.logic";

export interface LeagueAwardInput {
  wodResultId: string;
  wodId: string;
  subScore: number | null;
  performedAt: Date;
  review: string;
}

/**
 * Attribue les points de Ligue d'un résultat de WOD — appelé par `ResultsService.log()` (best-effort).
 *
 * C'est la SYNERGIE « 1 log → 2 usages » : le même résultat alimente l'Index (no-drop, ailleurs) ET
 * la Ligue (ici). Anti-double-comptage garanti par `league_points.wodResultId UNIQUE`.
 *
 * Ne compte QUE si : (a) sous-score valide, (b) résultat non suspect (`review === "ok"`), (c) une
 * saison est active à la date de l'effort, (d) l'athlète est inscrit, (e) l'effort porte sur le WOD
 * imposé de SA semaine/filière. Sinon : no-op silencieux.
 */
@Injectable()
export class LeaguePointsService {
  private readonly logger = new Logger(LeaguePointsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async awardForResult(userId: string, sex: "male" | "female", input: LeagueAwardInput): Promise<void> {
    if (input.subScore == null) return; // effort invalide / hors bornes
    if (input.review !== "ok") return; // suspect → exclu (même garde-fou que l'Index)

    const performedAt = input.performedAt;
    const season = await this.prisma.leagueSeason.findFirst({
      where: { status: "active", opensAt: { lte: performedAt }, closesAt: { gt: performedAt } },
      select: { id: true },
    });
    if (!season) return; // hors saison

    const entry = await this.prisma.leagueEntry.findUnique({
      where: { seasonId_userId: { seasonId: season.id, userId } },
      select: { filiere: true, level: true },
    });
    if (!entry) return; // pas inscrit (opt-in)

    const weekKey = isoWeekKey(performedAt);
    const week = await this.prisma.leagueWeek.findFirst({
      where: { seasonId: season.id, weekKey, filiere: entry.filiere },
      select: { id: true, wodId: true },
    });
    if (!week) return; // pas de WOD imposé cette semaine
    if (week.wodId !== input.wodId) return; // ce n'est pas le WOD imposé de la semaine

    const points = leagueWeekPoints(input.subScore);
    // Idempotent sur wodResultId : un résultat = une ligne (re-log via idempotencyKey ne double rien).
    await this.prisma.leaguePoints.upsert({
      where: { wodResultId: input.wodResultId },
      create: {
        seasonId: season.id,
        weekId: week.id,
        userId,
        sex,
        filiere: entry.filiere,
        level: entry.level,
        wodResultId: input.wodResultId,
        points,
        subScore: input.subScore,
        review: "ok",
      },
      update: { points, subScore: input.subScore },
    });
    this.logger.debug(`Points Ligue : user=${userId} +${points} (WOD ${input.wodId}, ${weekKey}).`);
  }
}
