import { BadRequestException, Controller, Get, Query, UseGuards } from "@nestjs/common";
import { AttributeKey } from "@hybrid-index/contracts";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import type { Session } from "./sessions.data";
import { CoachService, type CoachResponse, type LibraryResponse } from "./coach.service";

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

  /** Bibliothèque de séances pour un attribut, triée par poids (écran « Séances de [attribut] »). */
  @Get("library")
  library(
    @CurrentUser() user: AuthenticatedUser,
    @Query("attribute") attribute?: string,
  ): Promise<LibraryResponse> {
    const parsed = AttributeKey.safeParse(attribute);
    if (!parsed.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Attribut invalide." });
    }
    return this.coach.library(user.userId, parsed.data);
  }

  /** Séance de la semaine (signature « Le Forgeron »). */
  @Get("weekly")
  weekly(): { session: Session } {
    return this.coach.weekly();
  }
}
