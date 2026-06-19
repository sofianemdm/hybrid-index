import { Body, Controller, Post } from "@nestjs/common";
import { onboardingDto } from "@hybrid-index/contracts";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { OnboardingService } from "./onboarding.service";

@Controller("v1/onboarding")
export class OnboardingController {
  constructor(private readonly onboarding: OnboardingService) {}

  /** Le « reveal » : Index provisoire à partir d'un temps de course / auto-évaluation. */
  @Post("estimate")
  estimate(
    @Body(new ZodValidationPipe(onboardingDto.OnboardingEstimateRequest))
    body: onboardingDto.OnboardingEstimateRequest,
  ): Promise<onboardingDto.RevealResponse> {
    return this.onboarding.estimate(body);
  }
}
