import { Module } from "@nestjs/common";
import { LeaderboardModule } from "../leaderboard/leaderboard.module";
import { EngagementController } from "./engagement.controller";
import { EngagementService } from "./engagement.service";
import { StreakService } from "./streak.service";
import { BadgesService } from "./badges.service";
import { PushService } from "./push.service";
import { WeeklyEngagementService } from "./weekly-engagement.service";

@Module({
  imports: [LeaderboardModule],
  controllers: [EngagementController],
  providers: [StreakService, BadgesService, EngagementService, PushService, WeeklyEngagementService],
  exports: [StreakService, BadgesService, PushService],
})
export class EngagementModule {}
