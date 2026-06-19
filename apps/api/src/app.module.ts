import { Module } from "@nestjs/common";
import { HealthController } from "./health/health.controller";
import { OnboardingModule } from "./modules/onboarding/onboarding.module";

@Module({
  imports: [OnboardingModule],
  controllers: [HealthController],
})
export class AppModule {}
