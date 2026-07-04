import { Body, Controller, Delete, Get, Param, Post, UseGuards } from "@nestjs/common";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { LogResultRequest } from "./results.dto";
import { ResultsService, type LogResultResponse } from "./results.service";

@Controller("v1/results")
@UseGuards(JwtAuthGuard)
export class ResultsController {
  constructor(private readonly results: ResultsService) {}

  /** Logue un WOD → note l'effort, persiste, recalcule l'Index/radar. */
  @Post()
  log(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(LogResultRequest)) body: LogResultRequest,
  ): Promise<LogResultResponse> {
    return this.results.log(user.userId, body);
  }

  /** Historique des résultats de l'utilisateur connecté. */
  @Get()
  list(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.results.list(user.userId);
  }

  /** Mes records personnels : le meilleur effort par WOD (A8 — PR Wall). */
  @Get("prs")
  prs(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.results.personalRecords(user.userId);
  }

  /** Supprime un de mes résultats → recalcule l'Index. */
  @Delete(":id")
  remove(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.results.remove(user.userId, id);
  }
}
