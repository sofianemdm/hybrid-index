import { Injectable, NotFoundException } from "@nestjs/common";
import { RANK_BANDS } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
import { StreakService } from "./streak.service";
import { NOTIFICATION_TRIGGERS } from "./notifications.data";

export interface FeedItem {
  key: string;
  title: string;
  body: string;
  priority: "high" | "medium" | "low";
}

const DEFAULT_PREFS = {
  prefs: {} as Record<string, boolean>,
  quietHours: { start: "22:00", end: "07:00" },
  dailyCap: 2,
};

/** Préférences de notification + RGPD (export / suppression de compte). */
@Injectable()
export class EngagementService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly streak: StreakService,
  ) {}

  /**
   * Flux de notifications IN-APP : évalue les déclencheurs pertinents contre l'état courant
   * (série, prochain rang), en respectant l'opt-out par clé. L'envoi push (FCM) reste
   * différé ; ce flux rend les déclencheurs immédiatement utiles dans l'app.
   */
  async feed(userId: string): Promise<FeedItem[]> {
    const items: FeedItem[] = [];
    const [profile, idx, prefsRow] = await Promise.all([
      this.prisma.profile.findUnique({ where: { userId } }),
      this.prisma.hybridIndex.findUnique({ where: { userId } }),
      this.prisma.notificationPrefs.findUnique({ where: { userId } }),
    ]);
    if (!profile || !idx) return items;

    const prefs = (prefsRow?.prefs as Record<string, boolean> | undefined) ?? {};
    const enabled = (key: string): boolean => prefs[key] !== false;

    // Série hebdomadaire.
    const streak = await this.streak.evaluateAndGet(userId).catch(() => null);
    if (streak) {
      if (enabled("week-almost-complete") && streak.thisWeekCount === streak.weeklyGoal - 1) {
        items.push({
          key: "week-almost-complete",
          title: "Plus qu'un WOD",
          body: `Un entraînement et ta semaine est validée (${streak.thisWeekCount}/${streak.weeklyGoal}).`,
          priority: "high",
        });
      } else if (enabled("rest-week-respected") && streak.weekValidated) {
        items.push({
          key: "week-validated",
          title: "Semaine validée ✓",
          body: `Série en cours : ${streak.current} semaine(s). Continue !`,
          priority: "low",
        });
      }
    }

    // Prochain rang.
    const next = RANK_BANDS.find((b) => b.min > idx.value);
    if (next && enabled("next-rank-close")) {
      const pts = next.min - idx.value;
      if (pts <= 40) {
        items.push({
          key: "next-rank-close",
          title: `Le rang ${next.rank} est proche`,
          body: `Encore ${pts} points. Un bon WOD et tu y es.`,
          priority: "medium",
        });
      }
    }

    return items;
  }

  async getNotifications(userId: string): Promise<unknown> {
    const row = await this.prisma.notificationPrefs.findUnique({ where: { userId } });
    return {
      prefs: row?.prefs ?? DEFAULT_PREFS.prefs,
      quietHours: row?.quietHours ?? DEFAULT_PREFS.quietHours,
      dailyCap: row?.dailyCap ?? DEFAULT_PREFS.dailyCap,
      // Catalogue des déclencheurs (l'envoi push réel via FCM est différé).
      triggers: NOTIFICATION_TRIGGERS,
    };
  }

  async updateNotifications(
    userId: string,
    body: { prefs?: Record<string, boolean>; quietHours?: { start: string; end: string }; dailyCap?: number },
  ): Promise<unknown> {
    const current = await this.prisma.notificationPrefs.findUnique({ where: { userId } });
    const prefs = body.prefs ?? (current?.prefs as Record<string, boolean> | undefined) ?? DEFAULT_PREFS.prefs;
    const quietHours = body.quietHours ?? (current?.quietHours as object | undefined) ?? DEFAULT_PREFS.quietHours;
    const dailyCap = body.dailyCap ?? current?.dailyCap ?? DEFAULT_PREFS.dailyCap;
    await this.prisma.notificationPrefs.upsert({
      where: { userId },
      create: { userId, prefs, quietHours, dailyCap },
      update: { prefs, quietHours, dailyCap },
    });
    return { prefs, quietHours, dailyCap };
  }

  /** Export RGPD : toutes les données de l'utilisateur (droit à la portabilité). */
  async exportData(userId: string): Promise<unknown> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        profile: true,
        hybridIndex: true,
        attributeScores: true,
        wodResults: true,
        streak: true,
        userBadges: true,
        notificationPrefs: true,
      },
    });
    if (!user) throw new NotFoundException({ code: "NOT_FOUND", message: "Utilisateur introuvable." });
    // On n'exporte jamais le hash de mot de passe.
    const { passwordHash, ...safe } = user;
    void passwordHash;
    return safe;
  }

  /** Suppression de compte (RGPD droit à l'effacement) : cascade Postgres + retrait Redis. */
  async deleteAccount(userId: string): Promise<{ deleted: true }> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    await this.prisma.user.delete({ where: { id: userId } });
    if (profile) await this.redis.remove(profile.sex, userId);
    return { deleted: true };
  }
}
