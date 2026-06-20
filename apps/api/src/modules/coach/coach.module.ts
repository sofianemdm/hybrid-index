import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { CoachController } from "./coach.controller";
import { CoachService } from "./coach.service";

@Module({
  imports: [ScoreClientModule],
  controllers: [CoachController],
  providers: [CoachService],
})
export class CoachModule {}
