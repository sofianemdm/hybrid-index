import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
import { NOTIFICATION_TRIGGERS } from "./notifications.data";

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
  ) {}

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
