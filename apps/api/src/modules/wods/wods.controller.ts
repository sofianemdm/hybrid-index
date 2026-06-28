import { BadRequestException, Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from "@nestjs/common";
import { Sex } from "@hybrid-index/contracts";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser } from "../auth/current-user.decorator";
import { OptionalJwtAuthGuard } from "../auth/optional-jwt-auth.guard";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { ClubsService } from "../clubs/clubs.service";
import { WodsService } from "./wods.service";
import { EstimateWodRequest } from "./wod-estimate.dto";
import { CreateWodRequest, LogWodResultRequest } from "./create-wod.dto";

@Controller("v1/wods")
@UseGuards(OptionalJwtAuthGuard)
export class WodsController {
  constructor(
    private readonly wods: WodsService,
    private readonly clubs: ClubsService,
  ) {}

  /** Catalogue des WODs. Public. */
  @Get()
  catalog(): Promise<unknown[]> {
    return this.wods.catalog();
  }

  /** Plan pour compléter l'Index : séances minimales couvrant les attributs encore non débloqués. */
  @Get("completion-plan")
  @UseGuards(JwtAuthGuard)
  completionPlan(@CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    return this.wods.completionPlan(user.userId);
  }

  /** Estimation ad-hoc d'un WOD décomposé (aperçu du builder). */
  @Post("estimate")
  estimate(@Body(new ZodValidationPipe(EstimateWodRequest)) body: EstimateWodRequest): Promise<unknown> {
    return this.wods.estimate(body);
  }

  /** Crée un WOD personnalisé (communautaire). */
  @Post()
  @UseGuards(JwtAuthGuard)
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(CreateWodRequest)) body: CreateWodRequest,
  ): Promise<unknown> {
    return this.wods.create(user.userId, body);
  }

  /** Édite un WOD personnalisé. Réservé au créateur d'un WOD `isCustom` (403 sinon). */
  @Patch(":id")
  @UseGuards(JwtAuthGuard)
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(CreateWodRequest)) body: CreateWodRequest,
  ): Promise<unknown> {
    return this.wods.update(user.userId, id, body);
  }

  /** Supprime un WOD personnalisé. Réservé au créateur d'un WOD `isCustom` (403 sinon) ; refusé si
   *  des résultats existent déjà (409). */
  @Delete(":id")
  @UseGuards(JwtAuthGuard)
  remove(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.wods.remove(user.userId, id);
  }

  /** Logue un résultat sur un WOD (officiel ou custom) → recalcule l'Index. */
  @Post(":id/results")
  @UseGuards(JwtAuthGuard)
  logResult(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(LogWodResultRequest)) body: LogWodResultRequest,
  ): Promise<unknown> {
    return this.wods.logResult(user.userId, id, body);
  }

  /** Fiche d'un WOD (paliers de référence + ton meilleur effort si connecté). */
  @Get(":id")
  detail(@Param("id") id: string, @CurrentUser() user: AuthenticatedUser | undefined): Promise<unknown> {
    return this.wods.detail(id, user?.userId);
  }

  /** Prédiction « d'après ton niveau, tu ferais ~X » sur cette séance (réservé aux connectés). */
  @Get(":id/prediction")
  @UseGuards(JwtAuthGuard)
  prediction(@Param("id") id: string, @CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    return this.wods.prediction(id, user.userId);
  }

  /** Classement d'un WOD par sexe et variante (Rx par défaut, ou Scaled). */
  @Get(":id/leaderboard")
  async leaderboard(
    @Param("id") id: string,
    @Query("sex") sexParam: string,
    @Query("variant") variant: string | undefined,
    @Query("clubId") clubId: string | undefined,
    @CurrentUser() user: AuthenticatedUser | undefined,
  ): Promise<unknown> {
    const sex = Sex.safeParse(sexParam);
    if (!sex.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Paramètre sex requis : male|female." });
    }
    const memberIds = clubId && user ? await this.clubs.memberIds(clubId, user.userId) : undefined;
    return this.wods.leaderboard(id, sex.data, variant !== "scaled", user?.userId, memberIds);
  }
}
