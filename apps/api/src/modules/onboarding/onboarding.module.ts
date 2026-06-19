import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { OnboardingController } from "./onboarding.controller";
import { OnboardingService } from "./onboarding.service";

@Module({
  imports: [ScoreClientModule],
  controllers: [OnboardingController],
  providers: [OnboardingService],
})
export class OnboardingModule {}
