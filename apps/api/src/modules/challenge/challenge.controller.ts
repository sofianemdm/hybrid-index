import { BadRequestException, Controller, Get, Query, UseGuards } from "@nestjs/common";
import { Sex } from "@hybrid-index/contracts";
import { CurrentUser } from "../auth/current-user.decorator";
import { type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { OptionalJwtAuthGuard } from "../auth/optional-jwt-auth.guard";
import { ChallengeService } from "./challenge.service";

@Controller("v1/challenge")
export class ChallengeController {
  constructor(private readonly challenge: ChallengeService) {}

  /** Le défi de la semaine en cours (WOD imposé + énoncé + fin de semaine). */
  @Get()
  current(): Promise<unknown> {
    return this.challenge.current();
  }

  /** Classement du défi de la semaine (par sexe), résultats loggés cette semaine uniquement. */
  @Get("leaderboard")
  @UseGuards(OptionalJwtAuthGuard)
  leaderboard(@Query("sex") sexParam: string, @CurrentUser() user: AuthenticatedUser | undefined): Promise<unknown> {
    const sex = Sex.safeParse(sexParam);
    if (!sex.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Paramètre sex requis : male|female." });
    }
    return this.challenge.leaderboard(sex.data, user?.userId);
  }
}
