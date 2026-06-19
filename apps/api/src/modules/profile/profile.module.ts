import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { ProfileScoringService } from "./profile-scoring.service";

@Module({
  imports: [ScoreClientModule],
  providers: [ProfileScoringService],
  exports: [ProfileScoringService],
})
export class ProfileModule {}
