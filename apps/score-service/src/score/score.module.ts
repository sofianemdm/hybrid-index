import { Module } from "@nestjs/common";
import { ScoreController } from "./score.controller";
import { ScoringVersionService } from "./scoring-version.service";

@Module({
  controllers: [ScoreController],
  providers: [ScoringVersionService],
  exports: [ScoringVersionService],
})
export class ScoreModule {}
