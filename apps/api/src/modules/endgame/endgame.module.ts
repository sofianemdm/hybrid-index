import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { EndgameController } from "./endgame.controller";
import { EndgameService } from "./endgame.service";

@Module({
  imports: [ScoreClientModule],
  controllers: [EndgameController],
  providers: [EndgameService],
})
export class EndgameModule {}
