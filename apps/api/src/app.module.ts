import { Module } from "@nestjs/common";
import { HealthController } from "./health/health.controller";
import { PrismaModule } from "./infra/prisma/prisma.module";
import { RedisModule } from "./infra/redis/redis.module";
import { AuthModule } from "./modules/auth/auth.module";
import { ProfileModule } from "./modules/profile/profile.module";
import { MeModule } from "./modules/me/me.module";
import { OnboardingModule } from "./modules/onboarding/onboarding.module";
import { ResultsModule } from "./modules/results/results.module";
import { LeaderboardModule } from "./modules/leaderboard/leaderboard.module";
import { ProfilesModule } from "./modules/profiles/profiles.module";
import { CoachModule } from "./modules/coach/coach.module";
import { EngagementModule } from "./modules/engagement/engagement.module";
import { EndgameModule } from "./modules/endgame/endgame.module";
import { WodsModule } from "./modules/wods/wods.module";
import { SocialModule } from "./modules/social/social.module";
import { ChallengesModule } from "./modules/challenges/challenges.module";

@Module({
  imports: [
    PrismaModule,
    RedisModule,
    SocialModule,
    AuthModule,
    ProfileModule,
    MeModule,
    OnboardingModule,
    ResultsModule,
    LeaderboardModule,
    ProfilesModule,
    CoachModule,
    EngagementModule,
    EndgameModule,
    WodsModule,
    ChallengesModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
