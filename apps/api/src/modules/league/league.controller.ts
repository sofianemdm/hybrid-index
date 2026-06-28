import { BadRequestException, Controller, Get, Post, Query, UseGuards } from "@nestjs/common";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { OptionalJwtAuthGuard } from "../auth/optional-jwt-auth.guard";
import { CurrentUser } from "../auth/current-user.decorator";
import { LeagueService } from "./league.service";
import { LeagueEnrollmentService } from "./league-enrollment.service";
import type {
  EnrollResponse,
  LeagueLastResultView,
  LeagueMeView,
  LeagueSeasonView,
  LeagueStandingsView,
  LeagueWeekView,
} from "./league.dto";

function parseSex(sex: string | undefined): "male" | "female" {
  if (sex === "male" || sex === "female") return sex;
  throw new BadRequestException({ code: "BAD_SEX", message: "Paramètre `sex` requis (male|female)." });
}

@Controller("v1/league")
export class LeagueController {
  constructor(
    private readonly league: LeagueService,
    private readonly enrollment: LeagueEnrollmentService,
  ) {}

  /** Saison active + WOD de la semaine + si l'appelant est inscrit. */
  @Get("season/current")
  @UseGuards(OptionalJwtAuthGuard)
  async season(@CurrentUser() user: AuthenticatedUser | undefined): Promise<LeagueSeasonView | null> {
    return this.league.seasonView(user?.userId);
  }

  /** WOD imposé de la semaine en cours. */
  @Get("week/current")
  @UseGuards(OptionalJwtAuthGuard)
  async week(): Promise<LeagueWeekView | null> {
    return this.league.currentWeek();
  }

  /** Inscription OPT-IN à la saison active. */
  @Post("enroll")
  @UseGuards(JwtAuthGuard)
  async enroll(@CurrentUser() user: AuthenticatedUser): Promise<EnrollResponse> {
    return this.enrollment.enroll(user.userId);
  }

  /** Classement mensuel d'une ligue (par sexe) + ma position. */
  @Get("standings")
  @UseGuards(OptionalJwtAuthGuard)
  async standings(
    @Query("sex") sex: string | undefined,
    @CurrentUser() user: AuthenticatedUser | undefined,
  ): Promise<LeagueStandingsView> {
    return this.league.standings(parseSex(sex), user?.userId);
  }

  /**
   * Résultat de la DERNIÈRE saison close (reveal de fin de saison) : podium top 3 du sexe du viewer
   * + sa ligne s'il a participé. Renvoie `null` s'il n'existe aucune saison close.
   */
  @Get("last-result")
  @UseGuards(OptionalJwtAuthGuard)
  async lastResult(@CurrentUser() user: AuthenticatedUser | undefined): Promise<LeagueLastResultView | null> {
    return this.league.lastResult(user?.userId);
  }

  /** Mon résumé Ligue (points du mois, position, semaines jouées). */
  @Get("me")
  @UseGuards(JwtAuthGuard)
  async me(@CurrentUser() user: AuthenticatedUser): Promise<LeagueMeView> {
    return this.league.me(user.userId);
  }
}
