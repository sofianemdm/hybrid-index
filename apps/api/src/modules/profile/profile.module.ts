import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { EngagementModule } from "../engagement/engagement.module";
import { LeaderboardModule } from "../leaderboard/leaderboard.module";
import { ProfileScoringService } from "./profile-scoring.service";
import { ProfileViewService } from "./profile-view.service";
import { PublicProfileController } from "./public-profile.controller";
import { PublicProfileService } from "./public-profile.service";

/** TOUT le profil vit ici : scoring/recalcul (ProfileScoringService) ET profil public
 *  (PublicProfile*). L'ancien module doublon `profiles/` a été fusionné (dette 03/07). */
@Module({
  imports: [ScoreClientModule, EngagementModule, LeaderboardModule], // EngagementModule → PushService
  controllers: [PublicProfileController],
  providers: [ProfileScoringService, ProfileViewService, PublicProfileService],
  exports: [ProfileScoringService, ProfileViewService],
})
export class ProfileModule {}
