import { Global, Module } from "@nestjs/common";
import { SocialController } from "./social.controller";
import { SocialService } from "./social.service";
import { FeedEventsService } from "./feed-events.service";

/** Global : FeedEventsService injectable partout (émission d'événements depuis n'importe quel module). */
@Global()
@Module({
  controllers: [SocialController],
  providers: [SocialService, FeedEventsService],
  exports: [FeedEventsService],
})
export class SocialModule {}
