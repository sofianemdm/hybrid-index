import { Global, Module } from "@nestjs/common";
import { ModerationService } from "./moderation.service";
import { ModerationController } from "./moderation.controller";

/** @Global : Block/Report/filtre de noms réutilisés par clubs, posts et messagerie. */
@Global()
@Module({
  controllers: [ModerationController],
  providers: [ModerationService],
  exports: [ModerationService],
})
export class ModerationModule {}
