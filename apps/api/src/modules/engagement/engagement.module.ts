import { Module } from "@nestjs/common";
import { LeaderboardModule } from "../leaderboard/leaderboard.module";
import { EngagementController } from "./engagement.controller";
import { EngagementService } from "./engagement.service";
import { StreakService } from "./streak.service";
import { BadgesService } from "./badges.service";

@Module({
  imports: [LeaderboardModule],
  controllers: [EngagementController],
  providers: [StreakService, BadgesService, EngagementService],
  exports: [StreakService, BadgesService],
})
export class EngagementModule {}
