import { Body, Controller, Post, UseGuards } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CreateFeedbackRequest } from "./feedback.dto";
import { FeedbackService } from "./feedback.service";

@Controller("v1/feedback")
@UseGuards(JwtAuthGuard)
export class FeedbackController {
  constructor(private readonly feedback: FeedbackService) {}

  /** Reçoit un signalement de bug de l'app authentifiée et le stocke. */
  @Post()
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(CreateFeedbackRequest)) body: CreateFeedbackRequest,
  ): Promise<{ ok: true; id: string }> {
    return this.feedback.create(user.userId, body);
  }
}
