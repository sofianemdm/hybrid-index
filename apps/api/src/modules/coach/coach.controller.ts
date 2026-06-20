import { BadRequestException, Controller, Get, Query, UseGuards } from "@nestjs/common";
import { AttributeKey } from "@hybrid-index/contracts";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { CoachService, type CoachResponse } from "./coach.service";

@Controller("v1/coach")
@UseGuards(JwtAuthGuard)
export class CoachController {
  constructor(private readonly coach: CoachService) {}

  /** Séances ciblées + Index projeté pour un attribut (défaut : ton point faible). */
  @Get()
  recommend(
    @CurrentUser() user: AuthenticatedUser,
    @Query("attribute") attribute?: string,
  ): Promise<CoachResponse> {
    if (attribute !== undefined && !AttributeKey.safeParse(attribute).success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Attribut invalide." });
    }
    return this.coach.coach(user.userId, attribute);
  }
}
