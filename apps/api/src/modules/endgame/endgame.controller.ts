import { Controller, Get } from "@nestjs/common";
import { CurrentUser, type AuthenticatedUser } from "../../common/current-user.decorator";
import { EndgameService } from "./endgame.service";

@Controller("v1/me")
export class EndgameController {
  constructor(private readonly endgame: EndgameService) {}

  /** Grand Chelem + classement mondial + statut ambassadeur. */
  @Get("endgame")
  get(@CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    return this.endgame.endgame(user.userId);
  }
}
