import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { ModerationService } from "../moderation/moderation.service";
import { CommentsService } from "./comments.service";

const CreateComment = z.object({ body: z.string().min(1).max(500) });

const ReportBody = z.object({
  reason: z.enum(["spam", "harassment", "inappropriate", "cheating", "other"]),
  note: z.string().max(300).optional(),
});

@Controller("v1")
@UseGuards(JwtAuthGuard)
export class CommentsController {
  constructor(
    private readonly comments: CommentsService,
    private readonly moderation: ModerationService,
  ) {}

  /** Créer un commentaire sous un post. */
  @Post("posts/:id/comments")
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") postId: string,
    @Body(new ZodValidationPipe(CreateComment)) body: z.infer<typeof CreateComment>,
  ): Promise<unknown> {
    return this.comments.create(user.userId, postId, body.body);
  }

  /** Lister les commentaires d'un post (paginé par curseur, hors masqués/bloqués). */
  @Get("posts/:id/comments")
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") postId: string,
    @Query("cursor") cursor?: string,
  ): Promise<unknown> {
    return this.comments.list(user.userId, postId, cursor);
  }

  /** Supprimer un commentaire (auteur du commentaire OU auteur du post). */
  @Delete("comments/:id")
  remove(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.comments.delete(user.userId, id);
  }

  /** Signaler un commentaire (réutilise la modération générique + auto-masquage). */
  @Post("comments/:id/report")
  report(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(ReportBody)) body: z.infer<typeof ReportBody>,
  ): Promise<unknown> {
    return this.moderation.report(user.userId, { targetType: "comment", targetId: id, reason: body.reason, note: body.note });
  }
}
