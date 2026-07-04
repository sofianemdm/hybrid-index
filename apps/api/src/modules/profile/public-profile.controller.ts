import { Controller, Get, Param } from "@nestjs/common";
import { CurrentUser, type AuthenticatedUser } from "../../common/current-user.decorator";
import { PublicProfileService } from "./public-profile.service";

@Controller("v1/profiles")
export class PublicProfileController {
  constructor(private readonly profiles: PublicProfileService) {}

  /** Profil public d'un athlète (radar, Index, rang, position). Tout est public. */
  @Get(":userId")
  get(@Param("userId") userId: string, @CurrentUser() viewer: AuthenticatedUser | undefined): Promise<unknown> {
    return this.profiles.publicProfile(userId, viewer?.userId);
  }

  /** Historique de séances public de l'athlète (50 derniers résultats). Tout est public. */
  @Get(":userId/results")
  results(@Param("userId") userId: string): Promise<unknown[]> {
    return this.profiles.publicResults(userId);
  }
}
