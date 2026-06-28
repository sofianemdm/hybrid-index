import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { EngagementModule } from "../engagement/engagement.module";
import { ProfileScoringService } from "./profile-scoring.service";

@Module({
  imports: [ScoreClientModule, EngagementModule], // EngagementModule → PushService (ré-engagement)
  providers: [ProfileScoringService],
  exports: [ProfileScoringService],
})
export class ProfileModule {}
