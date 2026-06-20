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

    // « Quelqu'un t'a dépassé au classement » depuis ton dernier recalcul (regroupé, 1 item max).
    if (enabled("rank-overtaken") && idx.leaguePosition != null) {
      const above = await this.prisma.hybridIndex.count({
        where: { value: { gt: idx.value }, user: { profile: { sex: profile.sex } } },
      });
      const current = above + 1;
      const passedBy = current - idx.leaguePosition;
      const appPercentile = Number(idx.percentile);
      // Enjeu réel uniquement : top 30% OU faible écart (jamais anxiogène en milieu de tableau).
      if (passedBy > 0 && (appPercentile >= 0.7 || passedBy <= 2)) {
        items.push({
          key: "rank-overtaken",
          title: passedBy === 1 ? "Un athlète t'a dépassé" : `${passedBy} athlètes t'ont dépassé`,
          body: "Reprends ta place au classement 💪",
          priority: "medium",
        });
        // Auto-acquittement : on aligne le snapshot sur la position courante pour ne pas
        // re-notifier les MÊMES dépassements à chaque ouverture (anti-spam, cf. revue M1).
        await this.prisma.hybridIndex
          .update({ where: { userId }, data: { leaguePosition: current } })
          .catch(() => undefined);
      }
    }

    // « Quelqu'un a fait mieux que toi sur un WOD » — limité au cercle suivi (regroupé, 1 item max).
    if (enabled("wod-overtaken")) {
      const follows = await this.prisma.follow.findMany({
        where: { followerId: userId },
        select: { followeeId: true },
      });
      const followeeIds = follows.map((f) => f.followeeId);
      if (followeeIds.length > 0) {
        const mine = await this.prisma.wodResult.groupBy({
          by: ["wodId"],
          where: { userId, review: "ok", subScore: { not: null } },
          _max: { subScore: true },
        });
        const myWodIds = mine.map((m) => m.wodId);
        if (myWodIds.length > 0) {
          // Anti-spam (cf. revue M2) : on ne compte que les efforts d'athlètes suivis postérieurs à
          // MON dernier recalcul (= depuis ma dernière séance). La fenêtre se réinitialise dès que je
          // relogue un WOD → pas de notif « fossile » répétée indéfiniment.
          const theirs = await this.prisma.wodResult.groupBy({
            by: ["wodId"],
            where: {
              userId: { in: followeeIds },
              wodId: { in: myWodIds },
              review: "ok",
              subScore: { not: null },
              performedAt: { gt: idx.computedAt },
            },
            _max: { subScore: true },
          });
          const theirBest = new Map(theirs.map((t) => [t.wodId, t._max.subScore ?? 0]));
          const overtaken = mine.filter((m) => (theirBest.get(m.wodId) ?? 0) > (m._max.subScore ?? 0));
          if (overtaken.length > 0) {
            items.push({
              key: "wod-overtaken",
              title: overtaken.length === 1 ? "Un athlète a battu ton temps" : `Battu sur ${overtaken.length} WODs`,
              body: "Va défendre tes scores 🔥",
              priority: "medium",
            });
          }
        }
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
