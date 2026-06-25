import { Module } from "@nestjs/common";
import { EngagementModule } from "../engagement/engagement.module";
import { MessagingController } from "./messaging.controller";
import { MessagingService } from "./messaging.service";

@Module({
  imports: [EngagementModule], // pour PushService (notif « nouveau message »)
  controllers: [MessagingController],
  providers: [MessagingService],
})
export class MessagingModule {}
