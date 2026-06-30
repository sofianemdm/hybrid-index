import { Global, Module } from "@nestjs/common";
import { EngagementModule } from "../engagement/engagement.module";
import { PostsController } from "./posts.controller";
import { PostsService } from "./posts.service";
import { CommentsController } from "./comments.controller";
import { CommentsService } from "./comments.service";
import { MentionsService } from "./mentions.service";

/** Global : PostsService.forFeed() consommé par le feed unifié (SocialService). */
@Global()
@Module({
  imports: [EngagementModule], // PushService (notif « on a commenté ton post »)
  controllers: [PostsController, CommentsController],
  providers: [PostsService, CommentsService, MentionsService],
  exports: [PostsService, CommentsService],
})
export class PostsModule {}
