import { BadRequestException, Controller, Get, Query, UseGuards } from "@nestjs/common";
import { Sex } from "@hybrid-index/contracts";
import { CurrentUser } from "../auth/current-user.decorator";
import { type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { OptionalJwtAuthGuard } from "../auth/optional-jwt-auth.guard";
import { ProgressService } from "./progress.service";

@Controller("v1/leaderboard")
export class ProgressController {
  constructor(private readonly progress: ProgressService) {}

  /** Classement de progression de la semaine (par effort). Surligne l'utilisateur s'il est connecté. */
  @Get("progress")
  @UseGuards(OptionalJwtAuthGuard)
  board(@Query("sex") sexParam: string, @CurrentUser() user: AuthenticatedUser | undefined): Promise<unknown> {
    const sex = Sex.safeParse(sexParam);
    if (!sex.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Paramètre sex requis : male|female." });
    }
    return this.progress.board(sex.data, user?.userId);
  }
}
