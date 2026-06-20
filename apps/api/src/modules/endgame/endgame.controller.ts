import { Controller, Get, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { EndgameService } from "./endgame.service";

@Controller("v1/me")
@UseGuards(JwtAuthGuard)
export class EndgameController {
  constructor(private readonly endgame: EndgameService) {}

  /** Grand Chelem + classement mondial + statut ambassadeur. */
  @Get("endgame")
  get(@CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    return this.endgame.endgame(user.userId);
  }
}
