import { Controller, Get, Param, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { OptionalJwtAuthGuard } from "../auth/optional-jwt-auth.guard";
import type { AuthenticatedUser } from "../auth/jwt-auth.guard";
import { ProfilesService } from "./profiles.service";

@Controller("v1/profiles")
export class ProfilesController {
  constructor(private readonly profiles: ProfilesService) {}

  /** Profil public d'un athlète (radar, Index, rang, position). Tout est public. */
  @Get(":userId")
  @UseGuards(OptionalJwtAuthGuard)
  get(@Param("userId") userId: string, @CurrentUser() viewer: AuthenticatedUser | undefined): Promise<unknown> {
    return this.profiles.publicProfile(userId, viewer?.userId);
  }
}
