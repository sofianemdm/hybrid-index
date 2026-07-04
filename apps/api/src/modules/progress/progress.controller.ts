import { BadRequestException, Controller, Get, Query } from "@nestjs/common";
import { Sex } from "@hybrid-index/contracts";
import { CurrentUser, type AuthenticatedUser } from "../../common/current-user.decorator";
import { ClubsService } from "../clubs/clubs.service";
import { ProgressService } from "./progress.service";

@Controller("v1/leaderboard")
export class ProgressController {
  constructor(
    private readonly progress: ProgressService,
    private readonly clubs: ClubsService,
  ) {}

  /** Classement de progression de la semaine (par effort), ou filtré « Mon club » via `clubId`. */
  @Get("progress")
  async board(
    @Query("sex") sexParam: string,
    @Query("clubId") clubId: string | undefined,
    @CurrentUser() user: AuthenticatedUser | undefined,
  ): Promise<unknown> {
    const sex = Sex.safeParse(sexParam);
    if (!sex.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Paramètre sex requis : male|female." });
    }
    const memberIds = clubId && user ? await this.clubs.memberIds(clubId, user.userId) : undefined;
    return this.progress.board(sex.data, user?.userId, memberIds);
  }
}
