import { Module } from "@nestjs/common";
import { WodsService } from "../wods/wods.service";
import { ScoreController } from "./score.controller";
import { ScoringService } from "./scoring.service";
import { ScoringVersionService } from "./scoring-version.service";

@Module({
  controllers: [ScoreController],
  providers: [ScoringVersionService, WodsService, ScoringService],
  exports: [ScoringVersionService, WodsService, ScoringService],
})
export class ScoreModule {}
