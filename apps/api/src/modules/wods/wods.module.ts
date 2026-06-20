import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { WodsController } from "./wods.controller";
import { MovementsController } from "./movements.controller";
import { WodsService } from "./wods.service";

@Module({
  imports: [ScoreClientModule],
  controllers: [WodsController, MovementsController],
  providers: [WodsService],
})
export class WodsModule {}
