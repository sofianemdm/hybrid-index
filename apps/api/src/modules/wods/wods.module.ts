import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { WodsController } from "./wods.controller";
import { WodsService } from "./wods.service";

@Module({
  imports: [ScoreClientModule],
  controllers: [WodsController],
  providers: [WodsService],
})
export class WodsModule {}
