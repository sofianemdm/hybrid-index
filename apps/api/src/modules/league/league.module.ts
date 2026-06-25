import { Global, Module } from "@nestjs/common";
import { LeagueController } from "./league.controller";
import { LeagueService } from "./league.service";
import { LeagueEnrollmentService } from "./league-enrollment.service";
import { LeaguePointsService } from "./league-points.service";
import { LeagueLifecycleService } from "./league-lifecycle.service";

/**
 * Mode Ligue (saison mensuelle opt-in). @Global : `LeaguePointsService` est injecté par
 * `ResultsService` pour la synergie « 1 log → 2 usages » (sans import croisé entre modules).
 * Prisma/Redis sont déjà globaux. Cron (@nestjs/schedule) à brancher sur LeagueLifecycleService.
 */
@Global()
@Module({
  controllers: [LeagueController],
  providers: [LeagueService, LeagueEnrollmentService, LeaguePointsService, LeagueLifecycleService],
  exports: [LeaguePointsService, LeagueLifecycleService],
})
export class LeagueModule {}
