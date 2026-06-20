import { Body, Controller, Get, NotFoundException, Patch, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService, type PersistedProfile } from "../profile/profile-scoring.service";
import { MeService } from "./me.service";
import { UpdateAvatarRequest, UpdateMeRequest } from "./me.dto";

@Controller("v1/me")
@UseGuards(JwtAuthGuard)
export class MeController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly profileScoring: ProfileScoringService,
    private readonly meService: MeService,
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

  /** Met à jour le profil (pseudo / objectif / matériel). Objectif modifié → Index recalculé. */
  @Patch()
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(UpdateMeRequest)) body: UpdateMeRequest,
  ): Promise<unknown> {
    return this.meService.update(user.userId, body);
  }

  /** Avatar (peau / cheveux / barbe). Valeurs par défaut si jamais personnalisé. */
  @Get("avatar")
  getAvatar(@CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    return this.meService.getAvatar(user.userId);
  }

  @Patch("avatar")
  updateAvatar(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(UpdateAvatarRequest)) body: UpdateAvatarRequest,
  ): Promise<unknown> {
    return this.meService.updateAvatar(user.userId, body);
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

  /** Courbe de progression personnelle : série temporelle du HYBRID INDEX (H3). */
  @Get("history")
  history(@CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    return this.profileScoring.getHistory(user.userId);
  }
}
