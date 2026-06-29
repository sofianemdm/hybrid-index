import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { EngagementModule } from "../engagement/engagement.module";
import { CoachController } from "./coach.controller";
import { CoachService } from "./coach.service";

@Module({
  imports: [ScoreClientModule, EngagementModule],
  controllers: [CoachController],
  providers: [CoachService],
})
export class CoachModule {}
