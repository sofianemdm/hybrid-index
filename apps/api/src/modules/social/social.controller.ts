import { Body, Controller, Delete, Get, Param, Post, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { SocialService } from "./social.service";

const ReactionRequest = z.object({ feedEventId: z.string().uuid(), emoji: z.string() });

@Controller("v1")
@UseGuards(JwtAuthGuard)
export class SocialController {
  constructor(private readonly social: SocialService) {}

  @Post("follow/:userId")
  follow(@CurrentUser() user: AuthenticatedUser, @Param("userId") target: string): Promise<unknown> {
    return this.social.follow(user.userId, target);
  }

  @Delete("follow/:userId")
  unfollow(@CurrentUser() user: AuthenticatedUser, @Param("userId") target: string): Promise<unknown> {
    return this.social.unfollow(user.userId, target);
  }

  @Get("me/following")
  following(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.social.listFollowing(user.userId);
  }

  @Get("me/followers")
  followers(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.social.listFollowers(user.userId);
  }

  @Get("feed")
  feed(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.social.feed(user.userId);
  }

  @Post("reactions")
  react(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(ReactionRequest)) body: z.infer<typeof ReactionRequest>,
  ): Promise<unknown> {
    return this.social.react(user.userId, body.feedEventId, body.emoji);
  }

  @Delete("reactions/:feedEventId")
  unreact(@CurrentUser() user: AuthenticatedUser, @Param("feedEventId") feedEventId: string): Promise<unknown> {
    return this.social.unreact(user.userId, feedEventId);
  }
}
