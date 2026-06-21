import { Global, Module } from "@nestjs/common";
import { ClubsService } from "./clubs.service";
import { ClubsController } from "./clubs.controller";

/** @Global : ClubsService.memberIds réutilisé par les classements (filtre clubId, C3). */
@Global()
@Module({
  controllers: [ClubsController],
  providers: [ClubsService],
  exports: [ClubsService],
})
export class ClubsModule {}
