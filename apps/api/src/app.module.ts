import { Module } from "@nestjs/common";
import { APP_GUARD } from "@nestjs/core";
import { ScheduleModule } from "@nestjs/schedule";
import { RateLimitGuard } from "./common/rate-limit.guard";
import { HealthController } from "./health/health.controller";
import { PrismaModule } from "./infra/prisma/prisma.module";
import { RedisModule } from "./infra/redis/redis.module";
import { AuthModule } from "./modules/auth/auth.module";
import { ProfileModule } from "./modules/profile/profile.module";
import { MeModule } from "./modules/me/me.module";
import { OnboardingModule } from "./modules/onboarding/onboarding.module";
import { ResultsModule } from "./modules/results/results.module";
import { LeaderboardModule } from "./modules/leaderboard/leaderboard.module";
import { CoachModule } from "./modules/coach/coach.module";
import { EngagementModule } from "./modules/engagement/engagement.module";
import { EndgameModule } from "./modules/endgame/endgame.module";
import { WodsModule } from "./modules/wods/wods.module";
import { MetaModule } from "./modules/meta/meta.module";
import { SocialModule } from "./modules/social/social.module";
import { ProgressModule } from "./modules/progress/progress.module";
import { ModerationModule } from "./modules/moderation/moderation.module";
import { ClubsModule } from "./modules/clubs/clubs.module";
import { PostsModule } from "./modules/posts/posts.module";
import { MessagingModule } from "./modules/messaging/messaging.module";
import { ChallengeModule } from "./modules/challenge/challenge.module";
import { LeagueModule } from "./modules/league/league.module";
import { FeedbackModule } from "./modules/feedback/feedback.module";
import { RealtimeModule } from "./modules/realtime/realtime.module";

@Module({
  imports: [
    PrismaModule,
    RedisModule,
    ScheduleModule.forRoot(),
    ModerationModule,
    PostsModule,
    SocialModule,
    ProgressModule,
    ClubsModule,
    MessagingModule,
    ChallengeModule,
    LeagueModule,
    AuthModule,
    ProfileModule,
    MeModule,
    OnboardingModule,
    ResultsModule,
    LeaderboardModule,
    CoachModule,
    EngagementModule,
    EndgameModule,
    WodsModule,
    FeedbackModule,
    RealtimeModule,
    MetaModule,
  ],
  controllers: [HealthController],
  providers: [{ provide: APP_GUARD, useClass: RateLimitGuard }],
})
export class AppModule {}
