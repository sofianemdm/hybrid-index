import { BadRequestException, Controller, Get, Param, Query, UseGuards } from "@nestjs/common";
import { Sex } from "@hybrid-index/contracts";
import { CurrentUser } from "../auth/current-user.decorator";
import { OptionalJwtAuthGuard } from "../auth/optional-jwt-auth.guard";
import type { AuthenticatedUser } from "../auth/jwt-auth.guard";
import { WodsService } from "./wods.service";

@Controller("v1/wods")
@UseGuards(OptionalJwtAuthGuard)
export class WodsController {
  constructor(private readonly wods: WodsService) {}

  /** Catalogue des WODs. Public. */
  @Get()
  catalog(): Promise<unknown[]> {
    return this.wods.catalog();
  }

  /** Fiche d'un WOD (paliers de référence + ton meilleur effort si connecté). */
  @Get(":id")
  detail(@Param("id") id: string, @CurrentUser() user: AuthenticatedUser | undefined): Promise<unknown> {
    return this.wods.detail(id, user?.userId);
  }

  /** Classement d'un WOD par sexe. */
  @Get(":id/leaderboard")
  leaderboard(
    @Param("id") id: string,
    @Query("sex") sexParam: string,
    @CurrentUser() user: AuthenticatedUser | undefined,
  ): Promise<unknown> {
    const sex = Sex.safeParse(sexParam);
    if (!sex.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Paramètre sex requis : male|female." });
    }
    return this.wods.leaderboard(id, sex.data, user?.userId);
  }
}
