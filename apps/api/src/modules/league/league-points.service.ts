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
 * saison est active à la date de l'effort, (d) l'effort porte sur le WOD imposé de SA semaine/filière.
 * Sinon : no-op silencieux. Plus d'opt-in : l'athlète est inscrit AUTOMATIQUEMENT à sa première séance
 * comptée (tout le monde participe et est classé dès qu'il fait le WOD de la semaine).
 */
@Injectable()
export class LeaguePointsService {
  private readonly logger = new Logger(LeaguePointsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async awardForResult(userId: string, sex: "male" | "female", input: LeagueAwardInput): Promise<void> {
    // Effort invalide (hors bornes) ou suspect (anti-triche) : exclu de la Ligue — MÊME garde-fou que
    // l'Index. Et si une ligne existait déjà (relog d'un même résultat passé en `pending_review`), on
    // la retire du classement pour rester cohérent avec l'Index (sinon un tricheur resterait classé).
    if (input.subScore == null || input.review !== "ok") {
      await this.prisma.leaguePoints.deleteMany({ where: { wodResultId: input.wodResultId } });
      return;
    }

    const performedAt = input.performedAt;
    const season = await this.prisma.leagueSeason.findFirst({
      where: { status: "active", opensAt: { lte: performedAt }, closesAt: { gt: performedAt } },
      select: { id: true },
    });
    if (!season) return; // hors saison

    // Inscription AUTOMATIQUE (plus d'opt-in) : tout athlète qui fait le WOD de la semaine est inscrit
    // et classé à la volée. Filière/niveau de lancement : bodyweight / rx (cf. LeagueEnrollmentService).
    const entry = await this.prisma.leagueEntry.upsert({
      where: { seasonId_userId: { seasonId: season.id, userId } },
      create: { seasonId: season.id, userId, sex, filiere: "bodyweight", level: "rx" },
      update: {},
      select: { filiere: true, level: true },
    });

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
      // Rafraîchit aussi semaine/saison : au relog, `performedAt` est ré-horodaté côté serveur, donc la
      // semaine peut changer (M1). On garde la ligne cohérente avec le résultat courant.
      update: {
        seasonId: season.id,
        weekId: week.id,
        sex,
        filiere: entry.filiere,
        level: entry.level,
        points,
        subScore: input.subScore,
        review: "ok",
      },
    });
    this.logger.debug(`Points Ligue : user=${userId} +${points} (WOD ${input.wodId}, ${weekKey}).`);
  }
}
