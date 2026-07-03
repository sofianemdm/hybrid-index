import { Module } from "@nestjs/common";
import { ScoreClientModule } from "../../infra/score-client/score-client.module";
import { ProfileModule } from "../profile/profile.module";
import { WodsController } from "./wods.controller";
import { MovementsController } from "./movements.controller";
import { WodsService } from "./wods.service";
import { WodCatalogService } from "./wod-catalog.service";
import { WodBuilderService } from "./wod-builder.service";

@Module({
  imports: [ScoreClientModule, ProfileModule],
  controllers: [WodsController, MovementsController],
  providers: [WodsService, WodCatalogService, WodBuilderService],
})
export class WodsModule {}
