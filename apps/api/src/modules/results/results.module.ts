import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { ProfileModule } from "../profile/profile.module";
import { EngagementModule } from "../engagement/engagement.module";
import { ResultsController } from "./results.controller";
import { ResultsService } from "./results.service";

@Module({
  imports: [ScoreClientModule, ProfileModule, EngagementModule],
  controllers: [ResultsController],
  providers: [ResultsService],
})
export class ResultsModule {}
