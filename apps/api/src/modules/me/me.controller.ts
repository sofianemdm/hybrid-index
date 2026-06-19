import { Controller, Get, NotFoundException, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService, type PersistedProfile } from "../profile/profile-scoring.service";

@Controller("v1/me")
@UseGuards(JwtAuthGuard)
export class MeController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly profileScoring: ProfileScoringService,
  ) {}

  /** Identité + profil de base de l'utilisateur connecté. */
  @Get()
  async me(@CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    const profile = await this.prisma.profile.findUnique({ where: { userId: user.userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });
    return {
      id: user.userId,
      email: user.email,
      displayName: profile.displayName,
      sex: profile.sex,
      goal: profile.goal,
      equipmentPref: profile.equipmentPref,
      rank: profile.rank,
    };
  }

  /** HYBRID INDEX + radar persistés (état vide tant qu'aucun effort loggé). */
  @Get("profile")
  async profile(@CurrentUser() user: AuthenticatedUser): Promise<PersistedProfile> {
    const p = await this.profileScoring.getMyProfile(user.userId);
    if (!p) {
      throw new NotFoundException({
        code: "NOT_FOUND",
        message: "Aucun Index calculé. Termine l'onboarding ou logue un WOD.",
      });
    }
    return p;
  }
}
