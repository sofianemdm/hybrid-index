import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { RateLimit } from "../../common/rate-limit.guard";
import { CurrentUser, type AuthenticatedUser } from "../../common/current-user.decorator";
import { MessagingService } from "./messaging.service";

const SendBody = z.object({ toUserId: z.string().uuid(), body: z.string().min(1).max(2000) });

@Controller("v1")
export class MessagingController {
  constructor(private readonly messaging: MessagingService) {}

  /** Puis-je écrire à cet utilisateur ? (pour afficher/masquer le bouton DM). */
  @Get("users/:id/can-dm")
  canDm(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string): Promise<unknown> {
    return this.messaging.eligibility(user.userId, id);
  }

  @Get("conversations")
  conversations(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.messaging.conversations(user.userId);
  }

  @Get("conversations/:id/messages")
  messages(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    // Pagination par curseur : `before` = id d'un message → charge la page antérieure (scroll haut).
    @Query("before") before?: string,
    @Query("limit") limit?: string,
  ): Promise<unknown> {
    const parsedLimit = limit !== undefined ? Number.parseInt(limit, 10) : undefined;
    return this.messaging.messages(user.userId, id, {
      before,
      limit: parsedLimit !== undefined && Number.isFinite(parsedLimit) ? parsedLimit : undefined,
    });
  }

  // Anti-spam DM : 20 messages / min / utilisateur.
  @RateLimit({ limit: 20, windowSec: 60, by: "user" })
  @Post("messages")
  send(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(SendBody)) body: z.infer<typeof SendBody>,
  ): Promise<unknown> {
    return this.messaging.send(user.userId, body.toUserId, body.body);
  }
}
