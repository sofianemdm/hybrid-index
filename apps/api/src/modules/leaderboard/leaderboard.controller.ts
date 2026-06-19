import { BadRequestException, Controller, Get, Query, UseGuards } from "@nestjs/common";
import { Sex } from "@hybrid-index/contracts";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { OptionalJwtAuthGuard } from "../auth/optional-jwt-auth.guard";
import { LeaderboardService, type LeaderboardResponse, type RivalResponse } from "./leaderboard.service";

@Controller("v1")
export class LeaderboardController {
  constructor(private readonly leaderboard: LeaderboardService) {}

  /** Classement public d'une ligue (Hommes / Femmes). Surligne l'utilisateur s'il est connecté. */
  @Get("leaderboard")
  @UseGuards(OptionalJwtAuthGuard)
  leaderboardFor(
    @Query("sex") sexParam: string,
    @Query("limit") limitParam: string | undefined,
    @CurrentUser() user: AuthenticatedUser | undefined,
  ): Promise<LeaderboardResponse> {
    const sex = Sex.safeParse(sexParam);
    if (!sex.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Paramètre sex requis : male|female." });
    }
    const limit = Math.min(Math.max(Number(limitParam) || 50, 1), 100);
    return this.leaderboard.leaderboard(sex.data, limit, user?.userId);
  }

  /** Le rival : l'athlète juste au-dessus de moi dans ma ligue. */
  @Get("me/rival")
  @UseGuards(JwtAuthGuard)
  rival(@CurrentUser() user: AuthenticatedUser): Promise<RivalResponse> {
    return this.leaderboard.rival(user.userId);
  }
}
