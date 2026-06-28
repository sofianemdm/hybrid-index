import { Body, Controller, Delete, Param, Post, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { ModerationService } from "../moderation/moderation.service";
import { PostsService } from "./posts.service";

const CreatePost = z
  .object({
    kind: z.enum(["text", "perf_share"]),
    body: z.string().max(500).optional(),
    wodResultId: z.string().uuid().optional(),
  })
  .refine((d) => d.kind !== "perf_share" || !!d.wodResultId, { message: "wodResultId requis pour perf_share." });

const ReportBody = z.object({
  reason: z.enum(["spam", "harassment", "inappropriate", "cheating", "other"]),
  note: z.string().max(300).optional(),
});

@Controller("v1/posts")
@UseGuards(JwtAuthGuard)
export class PostsController {
  constructor(
    private readonly posts: PostsService,
    private readonly moderation: ModerationService,
  ) {}

  @Post()
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(CreatePost)) body: z.infer<typeof CreatePost>,
  ): Promise<unknown> {
    return this.posts.create(user.userId, body);
  }

  @Delete(":id")
  remove(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.posts.delete(user.userId, id);
  }

  /** Applaudir (kudos unifié 👏). L'emoji éventuellement envoyé par d'anciens clients est ignoré. */
  @Post(":id/reactions")
  react(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.posts.react(user.userId, id);
  }

  @Delete(":id/reactions")
  unreact(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.posts.unreact(user.userId, id);
  }

  @Post(":id/report")
  report(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(ReportBody)) body: z.infer<typeof ReportBody>,
  ): Promise<unknown> {
    return this.moderation.report(user.userId, { targetType: "post", targetId: id, reason: body.reason, note: body.note });
  }
}
