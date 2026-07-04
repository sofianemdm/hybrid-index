import { BadRequestException, Controller, Get, Query, UseGuards } from "@nestjs/common";
import { Sex } from "@hybrid-index/contracts";
import { CurrentUser } from "../auth/current-user.decorator";
import { type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { OptionalJwtAuthGuard } from "../auth/optional-jwt-auth.guard";
import { ClubsService } from "../clubs/clubs.service";
import { LeaderboardService, type LeaderboardResponse } from "./leaderboard.service";

@Controller("v1")
export class LeaderboardController {
  constructor(
    private readonly leaderboard: LeaderboardService,
    private readonly clubs: ClubsService,
  ) {}

  /** Classement d'une ligue (Hommes / Femmes), ou filtré « Mon club » via `clubId`. */
  @Get("leaderboard")
  @UseGuards(OptionalJwtAuthGuard)
  async leaderboardFor(
    @Query("sex") sexParam: string,
    @Query("limit") limitParam: string | undefined,
    @Query("clubId") clubId: string | undefined,
    @CurrentUser() user: AuthenticatedUser | undefined,
  ): Promise<LeaderboardResponse> {
    const sex = Sex.safeParse(sexParam);
    if (!sex.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Paramètre sex requis : male|female." });
    }
    const limit = Math.min(Math.max(Number(limitParam) || 50, 1), 100);
    const memberIds = clubId && user ? await this.clubs.memberIds(clubId, user.userId) : undefined;
    return this.leaderboard.leaderboard(sex.data, limit, user?.userId, memberIds);
  }
}
