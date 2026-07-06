import { Injectable, NotFoundException } from "@nestjs/common";
import { RANK_BANDS } from "@hybrid-index/contracts";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
import { StreakService } from "./streak.service";
import { addWeeks, weekStart } from "./iso-week";
import { weeklyRecapDelta } from "./recap.logic";
import { NEXT_RANK_CLOSE_THRESHOLD, NOTIFICATION_TRIGGERS } from "./notifications.data";
import { prefEnabled } from "./notification-gating";

/** Récap hebdomadaire (non compétitif) : ce que tu as accompli cette semaine. */
export interface WeeklyRecap {
  weekStart: string;
  sessions: number;
  indexNow: number | null;
  deltaIndex: number; // points d'Index gagnés depuis lundi (>= 0, no-drop)
  streakCurrent: number;
  weekValidated: boolean;
}

/** Cible de navigation in-app d'une tuile (deep-link logique, résolu par l'app). */
export type FeedRoute = "league" | "leaderboard";

export interface FeedItem {
  /** Clé de message STABLE et localisée côté app (ex. "rank-overtaken"). */
  key: string;
  /** Paramètres d'interpolation du message localisé (ex. { points: 12, rank: "Or" }). */
  params: Record<string, string | number>;
  priority: "high" | "medium" | "low";
  /** Zone à ouvrir au tap (chevron côté app). Absent = tuile non cliquable. */
  route?: FeedRoute;
  /**
   * COMPAT héritée : anciens items rendaient des phrases FR en dur. On ne les remplit plus
   * (l'app résout key+params), mais le champ reste optionnel pour ne pas casser d'éventuels
   * consommateurs. Les nouveaux items s'appuient sur key+params.
   */
  title?: string;
  body?: string;
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
   * Récap de la semaine en cours (lundi → maintenant, UTC) : nb de séances, gain d'Index depuis
   * lundi (no-drop ⇒ ≥ 0), état de la série. Non compétitif, toujours valorisant.
   */
  async weeklyRecap(userId: string): Promise<WeeklyRecap> {
    const monday = weekStart(new Date());
    const nextMonday = addWeeks(monday, 1);
    const [sessions, idx, before, streak] = await Promise.all([
      // Séances RÉELLES de la semaine : on exclut les efforts d'onboarding (auto-évaluation à
      // l'inscription, clé `onboarding:*`) — ce ne sont pas des séances faites cette semaine. NB :
      // les vraies séances ont `idempotencyKey = null` ; un simple `NOT startsWith` les exclurait
      // (SQL `NOT(NULL LIKE …)` = NULL), d'où le `OR { null }` explicite pour les garder.
      this.prisma.wodResult.count({
        where: {
          userId,
          performedAt: { gte: monday, lt: nextMonday },
          OR: [{ idempotencyKey: null }, { idempotencyKey: { not: { startsWith: "onboarding:" } } }],
        },
      }),
      this.prisma.hybridIndex.findUnique({ where: { userId }, select: { value: true } }),
      // Dernier point d'historique AVANT lundi = Index de référence du début de semaine.
      this.prisma.hybridIndexHistory.findFirst({
        where: { userId, computedAt: { lt: monday } },
        orderBy: { computedAt: "desc" },
        select: { value: true },
      }),
      this.streak.evaluateAndGet(userId),
    ]);
    const indexNow = idx ? Math.round(ratingFromInternal(idx.value)) : null;
    const indexStart = before ? Math.round(ratingFromInternal(before.value)) : indexNow;
    const deltaIndex = weeklyRecapDelta(indexNow, indexStart);
    return {
      weekStart: monday.toISOString(),
      sessions,
      indexNow,
      deltaIndex,
      streakCurrent: streak.current,
      weekValidated: streak.weekValidated,
    };
  }

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
    const enabled = (key: string): boolean => prefEnabled(prefs, key);

    // Série hebdomadaire.
    const streak = await this.streak.evaluateAndGet(userId).catch(() => null);
    if (streak) {
      // Obsolète depuis l'objectif à 1 séance/semaine (weeklyGoal>1 requis pour un « presque fini »).
      if (enabled("week-almost-complete") && streak.weeklyGoal > 1 && streak.thisWeekCount === streak.weeklyGoal - 1) {
        items.push({
          key: "week-almost-complete",
          params: { count: streak.thisWeekCount, goal: streak.weeklyGoal },
          priority: "high",
        });
      } else if (enabled("rest-week-respected") && streak.weekValidated) {
        items.push({
          key: "week-validated",
          params: { streak: streak.current },
          priority: "low",
        });
      }
    }

    // Prochain rang. RANK_BANDS vit sur l'échelle d'AFFICHAGE /100 ; `idx.value` est l'Index INTERNE
    // /1000. On compare donc sur la MÊME échelle (/100) via ratingFromInternal, sinon `next.min - idx.value`
    // est toujours < 0 (bande /100 − valeur /1000) → déclencheur quasi mort.
    const ovr = ratingFromInternal(idx.value);
    const next = RANK_BANDS.find((b) => b.min > ovr);
    if (next && enabled("next-rank-close")) {
      const pts = Math.ceil(next.min - ovr); // points /100 restants jusqu'au rang suivant
      if (pts <= NEXT_RANK_CLOSE_THRESHOLD) {
        items.push({
          key: "next-rank-close",
          params: { rank: next.rank, points: pts },
          priority: "medium",
          route: "league",
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
          params: { count: passedBy },
          priority: "medium",
          route: "league",
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
              params: { count: overtaken.length },
              priority: "medium",
              route: "leaderboard",
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
    // L'historique d'Index vit dans le schéma `scoring` sans FK cascade → effacement explicite (RGPD).
    // Atomique : soit tout est effacé, soit rien (pas d'historique orphelin ni de compte fantôme).
    await this.prisma.$transaction([
      this.prisma.hybridIndexHistory.deleteMany({ where: { userId } }),
      this.prisma.progressWeekly.deleteMany({ where: { userId } }), // pas de cascade FK (agrégat)
      // ClubInvite porte inviterId/inviteeId en scalaire (pas de cascade) → effacement explicite (RGPD).
      this.prisma.clubInvite.deleteMany({ where: { OR: [{ inviterId: userId }, { inviteeId: userId }] } }),
      this.prisma.user.delete({ where: { id: userId } }),
    ]);
    if (profile) await this.redis.remove(profile.sex, userId);
    // Invalide le cache de statut du guard JWT → le token du compte supprimé est rejeté immédiatement.
    await this.redis.del(`usrok:${userId}`);
    return { deleted: true };
  }
}
