import { Module } from "@nestjs/common";
import { ScoreModule } from "./score/score.module";

@Module({
  imports: [ScoreModule],
})
export class AppModule {}
