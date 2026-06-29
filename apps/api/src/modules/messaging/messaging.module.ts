import { Module } from "@nestjs/common";
import { EngagementModule } from "../engagement/engagement.module";
import { RealtimeModule } from "../realtime/realtime.module";
import { MessagingController } from "./messaging.controller";
import { MessagingService } from "./messaging.service";

@Module({
  imports: [EngagementModule, RealtimeModule], // PushService (notif) + RealtimeService (signal temps réel)
  controllers: [MessagingController],
  providers: [MessagingService],
})
export class MessagingModule {}
