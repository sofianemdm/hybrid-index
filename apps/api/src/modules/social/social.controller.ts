import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { SocialService, type FeedScope } from "./social.service";

// L'emoji est optionnel et ignoré : le kudos est toujours 👏 (compat anciens clients).
const ReactionRequest = z.object({ feedEventId: z.string().uuid(), emoji: z.string().optional() });

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

  /**
   * Fil d'actualité. `?scope=all` (défaut) = fil GLOBAL (toute la communauté active) ;
   * `?scope=following` = restreint aux personnes suivies + moi.
   */
  @Get("feed")
  feed(@CurrentUser() user: AuthenticatedUser, @Query("scope") scope?: string): Promise<unknown[]> {
    const safeScope: FeedScope = scope === "following" ? "following" : "all";
    return this.social.feed(user.userId, safeScope);
  }

  /** Fil « Découvrir » : top de la ligue (même sexe) à suivre — repli quand on ne suit personne. */
  @Get("social/discover")
  discover(@CurrentUser() user: AuthenticatedUser): Promise<unknown[]> {
    return this.social.discover(user.userId);
  }

  /**
   * « Mur » d'un athlète (LOT 3) : ses posts PUBLICS, paginés par curseur. Respecte le blocage
   * bidirectionnel + la visibilité. `?cursor=<id>` pour la page suivante. Réponse `{ items, nextCursor }`.
   */
  @Get("users/:id/posts")
  userPosts(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") authorId: string,
    @Query("cursor") cursor?: string,
  ): Promise<unknown> {
    return this.social.userPosts(user.userId, authorId, cursor);
  }

  /** Recherche d'athlètes (filtres sexe / rang / nom). */
  @Get("explore")
  explore(
    @CurrentUser() user: AuthenticatedUser,
    @Query("sex") sex?: string,
    @Query("rank") rank?: string,
    @Query("q") q?: string,
  ): Promise<unknown[]> {
    return this.social.explore(user.userId, { sex, rank, q });
  }

  @Post("reactions")
  react(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(ReactionRequest)) body: z.infer<typeof ReactionRequest>,
  ): Promise<unknown> {
    return this.social.react(user.userId, body.feedEventId);
  }

  @Delete("reactions/:feedEventId")
  unreact(@CurrentUser() user: AuthenticatedUser, @Param("feedEventId") feedEventId: string): Promise<unknown> {
    return this.social.unreact(user.userId, feedEventId);
  }
}
