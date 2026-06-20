import { Body, Controller, Get, Param, Post, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { ChallengesService } from "./challenges.service";

const CreateChallengeRequest = z.object({
  wodId: z.string(),
  toUserId: z.string().uuid().optional(),
  expiresInDays: z.number().int().min(3).max(14).optional(),
  rxCompliant: z.boolean().optional(),
});

@Controller("v1/challenges")
@UseGuards(JwtAuthGuard)
export class ChallengesController {
  constructor(private readonly challenges: ChallengesService) {}

  @Post()
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(CreateChallengeRequest)) body: z.infer<typeof CreateChallengeRequest>,
  ): Promise<unknown> {
    return this.challenges.create(user.userId, body);
  }

  @Get()
  list(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.challenges.list(user.userId);
  }

  @Post(":id/accept")
  accept(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.challenges.accept(user.userId, id);
  }

  @Post(":id/decline")
  decline(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.challenges.decline(user.userId, id);
  }

  @Post(":id/resolve")
  resolve(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.challenges.resolve(user.userId, id);
  }
}
