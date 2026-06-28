import { Global, Module } from "@nestjs/common";
import { EngagementModule } from "../engagement/engagement.module";
import { SocialController } from "./social.controller";
import { SocialService } from "./social.service";
import { FeedEventsService } from "./feed-events.service";

/** Global : FeedEventsService injectable partout (émission d'événements depuis n'importe quel module). */
@Global()
@Module({
  imports: [EngagementModule], // PushService (notif kudos « on a réagi à ta perf »)
  controllers: [SocialController],
  providers: [SocialService, FeedEventsService],
  exports: [FeedEventsService],
})
export class SocialModule {}
