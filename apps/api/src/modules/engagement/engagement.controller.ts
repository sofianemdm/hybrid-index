import { Body, Controller, Delete, Get, Patch, Post, UseGuards } from "@nestjs/common";
import { z } from "zod";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import { StreakService, type StreakState } from "./streak.service";
import { BadgesService, type BadgeView } from "./badges.service";
import { EngagementService, type FeedItem, type WeeklyRecap } from "./engagement.service";
import { PushService } from "./push.service";

const RegisterPushTokenRequest = z.object({ token: z.string().min(8).max(4096) });

const UpdateStreakRequest = z
  .object({
    weeklyGoal: z.number().int().min(2).max(5).optional(),
    plannedRest: z.boolean().optional(),
  })
  .refine((v) => v.weeklyGoal !== undefined || v.plannedRest !== undefined, { message: "Aucun champ." });

const UpdateNotificationsRequest = z.object({
  prefs: z.record(z.boolean()).optional(),
  quietHours: z.object({ start: z.string(), end: z.string() }).optional(),
  dailyCap: z.number().int().min(0).max(10).optional(),
});

@Controller("v1/me")
@UseGuards(JwtAuthGuard)
export class EngagementController {
  constructor(
    private readonly streak: StreakService,
    private readonly badges: BadgesService,
    private readonly engagement: EngagementService,
    private readonly push: PushService,
  ) {}

  /** Enregistre le device token push (FCM). « Prêt mais inactif » : stocké, envoyé seulement
   *  quand FCM_SERVER_KEY est configuré. */
  @Post("push-token")
  async registerPushToken(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(RegisterPushTokenRequest)) body: z.infer<typeof RegisterPushTokenRequest>,
  ): Promise<{ enabled: boolean }> {
    await this.push.registerToken(user.userId, body.token);
    return { enabled: this.push.enabled };
  }

  /** Série hebdomadaire (current/best, jetons de gel, progression de la semaine). */
  @Get("streak")
  getStreak(@CurrentUser() user: AuthenticatedUser): Promise<StreakState> {
    return this.streak.evaluateAndGet(user.userId);
  }

  /** Réglages de la série : objectif hebdo (2–5), repos planifié de la semaine. */
  @Patch("streak")
  updateStreak(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(UpdateStreakRequest)) body: z.infer<typeof UpdateStreakRequest>,
  ): Promise<StreakState> {
    return this.streak.updateSettings(user.userId, body);
  }

  /** Badges (débloqués + verrouillés). */
  @Get("badges")
  getBadges(@CurrentUser() user: AuthenticatedUser): Promise<BadgeView[]> {
    return this.badges.listForUser(user.userId);
  }

  /** Préférences de notification + catalogue des déclencheurs. */
  @Get("notifications")
  getNotifications(@CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    return this.engagement.getNotifications(user.userId);
  }

  /** Flux de notifications in-app (déclencheurs évalués sur l'état courant). */
  @Get("notifications/feed")
  getFeed(@CurrentUser() user: AuthenticatedUser): Promise<FeedItem[]> {
    return this.engagement.feed(user.userId);
  }

  /** Récap de la semaine en cours (séances, gain d'Index, série). */
  @Get("weekly-recap")
  getWeeklyRecap(@CurrentUser() user: AuthenticatedUser): Promise<WeeklyRecap> {
    return this.engagement.weeklyRecap(user.userId);
  }

  @Patch("notifications")
  updateNotifications(
    @CurrentUser() user: AuthenticatedUser,
    @Body(new ZodValidationPipe(UpdateNotificationsRequest)) body: z.infer<typeof UpdateNotificationsRequest>,
  ): Promise<unknown> {
    return this.engagement.updateNotifications(user.userId, body);
  }

  /** RGPD — export de toutes mes données (portabilité). */
  @Get("export")
  exportData(@CurrentUser() user: AuthenticatedUser): Promise<unknown> {
    return this.engagement.exportData(user.userId);
  }

  /** RGPD — suppression définitive du compte (effacement). */
  @Delete()
  deleteAccount(@CurrentUser() user: AuthenticatedUser): Promise<{ deleted: true }> {
    return this.engagement.deleteAccount(user.userId);
  }
}
