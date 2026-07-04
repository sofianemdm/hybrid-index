import { Body, Controller, Post } from "@nestjs/common";
import { CurrentUser, type AuthenticatedUser } from "../../common/current-user.decorator";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CreateFeedbackRequest } from "./feedback.dto";
import { FeedbackService } from "./feedback.service";

@Controller("v1/feedback")
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
