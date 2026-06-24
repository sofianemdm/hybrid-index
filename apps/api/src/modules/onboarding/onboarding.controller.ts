import { Body, Controller, Post, UseGuards } from "@nestjs/common";
import { onboardingDto } from "@hybrid-index/contracts";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { RateLimit } from "../../common/rate-limit.guard";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { OnboardingService } from "./onboarding.service";
import { OnboardingCompleteRequest } from "./onboarding-complete.dto";
import type { PersistedProfile } from "../profile/profile-scoring.service";

@Controller("v1/onboarding")
export class OnboardingController {
  constructor(private readonly onboarding: OnboardingService) {}

  /** Le « reveal » provisoire : Index à partir d'un temps de course / auto-évaluation (sans compte). */
  // Endpoint PUBLIC (non authentifié) appelant le score-service → limité par IP (anti-DoS).
  @RateLimit({ limit: 60, windowSec: 60 })
  @Post("estimate")
  estimate(
    @Body(new ZodValidationPipe(onboardingDto.OnboardingEstimateRequest))
    body: onboardingDto.OnboardingEstimateRequest,
  ): Promise<onboardingDto.RevealResponse> {
    return this.onboarding.estimate(body);
  }

  /** Finalise l'onboarding (authentifié) : persiste les efforts + l'Index révélé. */
  @Post("complete")
  @UseGuards(JwtAuthGuard)
  complete(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(OnboardingCompleteRequest)) body: OnboardingCompleteRequest,
  ): Promise<PersistedProfile> {
    return this.onboarding.complete(user.userId, body);
  }
}
