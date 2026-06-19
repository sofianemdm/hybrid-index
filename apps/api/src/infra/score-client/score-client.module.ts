import { Module } from "@nestjs/common";
import { SCORE_SERVICE_URL, ScoreClient } from "./score-client.service";

@Module({
  providers: [
    {
      provide: SCORE_SERVICE_URL,
      useFactory: (): string => process.env.SCORE_SERVICE_URL ?? "http://localhost:3001",
    },
    ScoreClient,
  ],
  exports: [ScoreClient],
})
export class ScoreClientModule {}
