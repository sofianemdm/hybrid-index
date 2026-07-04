import { Body, Controller, Delete, Param, Post } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser, type AuthenticatedUser } from "../../common/current-user.decorator";
import { ModerationService } from "./moderation.service";

const ReportRequest = z.object({
  targetType: z.enum(["post", "message", "club", "user", "comment"]),
  targetId: z.string().uuid(),
  reason: z.enum(["spam", "harassment", "inappropriate", "cheating", "other"]),
  note: z.string().max(500).optional(),
});

@Controller("v1")
export class ModerationController {
  constructor(private readonly moderation: ModerationService) {}

  @Post("users/:id/block")
  block(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.moderation.block(user.userId, id);
  }

  @Delete("users/:id/block")
  unblock(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.moderation.unblock(user.userId, id);
  }

  @Post("reports")
  report(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(ReportRequest)) body: z.infer<typeof ReportRequest>,
  ): Promise<unknown> {
    return this.moderation.report(user.userId, body);
  }
}
