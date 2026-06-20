import { Module } from "@nestjs/common";
import { ProfilesController } from "./profiles.controller";
import { ProfilesService } from "./profiles.service";
import { ProfileModule } from "../profile/profile.module";
import { LeaderboardModule } from "../leaderboard/leaderboard.module";

@Module({
  imports: [ProfileModule, LeaderboardModule],
  controllers: [ProfilesController],
  providers: [ProfilesService],
})
export class ProfilesModule {}
