import { BadRequestException, Body, Controller, Delete, Get, Param, Post, Query } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser, type AuthenticatedUser } from "../../common/current-user.decorator";
import { ClubsService } from "./clubs.service";

const CreateClub = z.object({ name: z.string().min(3).max(40), description: z.string().max(280).optional() });
const InviteBody = z.object({ inviteeId: z.string().uuid() });

@Controller("v1")
export class ClubsController {
  constructor(private readonly clubs: ClubsService) {}

  @Post("clubs")
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(CreateClub)) body: z.infer<typeof CreateClub>,
  ): Promise<unknown> {
    return this.clubs.create(user.userId, body);
  }

  @Get("clubs")
  search(@Query("q") q: string | undefined): Promise<unknown[]> {
    return this.clubs.search(q);
  }

  @Get("me/clubs")
  myClubs(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.clubs.myClubs(user.userId);
  }

  @Get("me/club-invites")
  myInvites(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.clubs.myInvites(user.userId);
  }

  @Get("clubs/:id")
  detail(@Param("id") id: string, @CurrentUser() user: AuthenticatedUser | undefined): Promise<unknown> {
    return this.clubs.detail(id, user?.userId);
  }

  @Post("clubs/:id/join")
  join(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.clubs.join(user.userId, id);
  }

  @Delete("clubs/:id/members/me")
  leave(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.clubs.leave(user.userId, id);
  }

  @Post("clubs/:id/invites")
  invite(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(InviteBody)) body: z.infer<typeof InviteBody>,
  ): Promise<unknown> {
    return this.clubs.invite(user.userId, id, body.inviteeId);
  }

  @Post("club-invites/:id/decline")
  decline(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    if (!id) throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Invitation invalide." });
    return this.clubs.declineInvite(user.userId, id);
  }
}
