import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { Cron } from "@nestjs/schedule";
import { Prisma } from "@prisma/client";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";

/** Valeur interne /1000 → OVR /100 affiché (règle : conversion au bord, jamais de .value brut). */
const ovr = (internal: number): number => Math.round(ratingFromInternal(internal));

const DAY_MS = 86_400_000;
/** Rétention du journal de visites (RGPD) : purge au-delà. */
const VISIT_RETENTION_DAYS = 90;

function daysAgo(n: number): Date {
  return new Date(Date.now() - n * DAY_MS);
}

/** Clé jour AAAA-MM-JJ (UTC) d'une date — bucket des séries temporelles. */
function dayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Vue d'ensemble : totaux + fenêtres 24h / 7j / 30j. */
  async overview(): Promise<Record<string, unknown>> {
    const [d1, d7, d30] = [daysAgo(1), daysAgo(7), daysAgo(30)];
    const [
      usersTotal,
      usersActive,
      users24h,
      users7d,
      users30d,
      sessionsWodTotal,
      sessionsWod7d,
      sessionsCoachTotal,
      sessionsCoach7d,
      postsTotal,
      posts7d,
      clubsTotal,
      pushByPlatform,
      feedbacksTotal,
      notifications7d,
      visitAgg,
      lastSignups,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { status: "active" } }),
      this.prisma.user.count({ where: { createdAt: { gte: d1 } } }),
      this.prisma.user.count({ where: { createdAt: { gte: d7 } } }),
      this.prisma.user.count({ where: { createdAt: { gte: d30 } } }),
      this.prisma.wodResult.count(),
      this.prisma.wodResult.count({ where: { createdAt: { gte: d7 } } }),
      this.prisma.coachSessionCompletion.count(),
      this.prisma.coachSessionCompletion.count({ where: { completedAt: { gte: d7 } } }),
      this.prisma.post.count(),
      this.prisma.post.count({ where: { createdAt: { gte: d7 } } }),
      this.prisma.club.count(),
      this.prisma.pushToken.groupBy({ by: ["platform"], _count: { _all: true } }),
      this.prisma.feedback.count(),
      this.prisma.notificationLog.count({ where: { sentAt: { gte: d7 } } }),
      // Hits + IP uniques + users connectés uniques par fenêtre, en un seul passage SQL.
      this.prisma.$queryRaw<Array<{ win: string; hits: bigint; ips: bigint; users: bigint }>>(Prisma.sql`
        SELECT w.win,
               COUNT(v.id)              AS hits,
               COUNT(DISTINCT v.ip)     AS ips,
               COUNT(DISTINCT v.user_id) AS users
        FROM (VALUES ('24h', ${d1}::timestamptz), ('7d', ${d7}::timestamptz), ('30d', ${d30}::timestamptz)) AS w(win, since)
        LEFT JOIN app.visit_log v ON v.created_at >= w.since
        GROUP BY w.win
      `),
      this.prisma.user.findMany({
        orderBy: { createdAt: "desc" },
        take: 5,
        select: { id: true, email: true, createdAt: true, profile: { select: { displayName: true, sex: true } } },
      }),
    ]);

    const visits: Record<string, { hits: number; uniqueIps: number; uniqueUsers: number }> = {};
    for (const row of visitAgg) {
      visits[row.win] = { hits: Number(row.hits), uniqueIps: Number(row.ips), uniqueUsers: Number(row.users) };
    }

    return {
      users: { total: usersTotal, active: usersActive, new24h: users24h, new7d: users7d, new30d: users30d },
      visits,
      sessions: {
        wodTotal: sessionsWodTotal,
        wod7d: sessionsWod7d,
        coachTotal: sessionsCoachTotal,
        coach7d: sessionsCoach7d,
      },
      posts: { total: postsTotal, new7d: posts7d },
      clubs: { total: clubsTotal },
      push: Object.fromEntries(pushByPlatform.map((p) => [p.platform, p._count._all])),
      feedbacks: { total: feedbacksTotal },
      notifications: { sent7d: notifications7d },
      lastSignups: lastSignups.map((u) => ({
        userId: u.id,
        email: u.email,
        displayName: u.profile?.displayName ?? null,
        sex: u.profile?.sex ?? null,
        createdAt: u.createdAt,
      })),
    };
  }

  /** Séries par jour (UTC) sur `days` jours : inscriptions, visites (hits/IP uniques), séances, posts. */
  async timeseries(days: number): Promise<Record<string, unknown>> {
    const clamped = Math.min(90, Math.max(1, days));
    const since = new Date(Date.parse(dayKey(daysAgo(clamped - 1)))); // minuit UTC du 1er jour

    const [signups, wodResults, coachDone, posts, visitRows] = await Promise.all([
      this.prisma.user.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
      this.prisma.wodResult.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
      this.prisma.coachSessionCompletion.findMany({ where: { completedAt: { gte: since } }, select: { completedAt: true } }),
      this.prisma.post.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
      // Le journal de visites peut être volumineux → agrégation côté SQL. Jour renvoyé en TEXTE
      // (AAAA-MM-JJ, UTC) : un timestamp sans TZ serait reparsé dans le fuseau du process Node
      // et décalerait les buckets d'un jour sur un serveur non-UTC (revue 07/07).
      this.prisma.$queryRaw<Array<{ day: string; hits: bigint; ips: bigint }>>(Prisma.sql`
        SELECT to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS day,
               COUNT(*) AS hits, COUNT(DISTINCT ip) AS ips
        FROM app.visit_log
        WHERE created_at >= ${since}
        GROUP BY 1
      `),
    ]);

    const bucket = (dates: Date[]): Map<string, number> => {
      const m = new Map<string, number>();
      for (const d of dates) m.set(dayKey(d), (m.get(dayKey(d)) ?? 0) + 1);
      return m;
    };
    const bSignups = bucket(signups.map((r) => r.createdAt));
    const bSessions = bucket([...wodResults.map((r) => r.createdAt), ...coachDone.map((r) => r.completedAt)]);
    const bPosts = bucket(posts.map((r) => r.createdAt));
    const bHits = new Map(visitRows.map((r) => [r.day, Number(r.hits)]));
    const bIps = new Map(visitRows.map((r) => [r.day, Number(r.ips)]));

    const series: Array<Record<string, unknown>> = [];
    for (let i = clamped - 1; i >= 0; i--) {
      const key = dayKey(daysAgo(i));
      series.push({
        day: key,
        signups: bSignups.get(key) ?? 0,
        visitors: bIps.get(key) ?? 0,
        hits: bHits.get(key) ?? 0,
        sessions: bSessions.get(key) ?? 0,
        posts: bPosts.get(key) ?? 0,
      });
    }
    return { days: clamped, series };
  }

  /** Visiteurs uniques par IP sur `days` jours : nb de visites, 1re/dernière visite, dernier user vu.
   *  Répond à « combien de visiteurs différents aujourd'hui, et qui ? ». Tri : dernière visite desc. */
  async visitors(days: number, limit: number): Promise<Record<string, unknown>> {
    const clampedDays = Math.min(90, Math.max(1, days));
    const take = Math.min(500, Math.max(1, limit));
    const since = daysAgo(clampedDays);
    const rows = await this.prisma.$queryRaw<
      Array<{ ip: string; hits: bigint; first_seen: Date; last_seen: Date; last_user_id: string | null; users: bigint }>
    >(Prisma.sql`
      SELECT v.ip,
             COUNT(*)                                                        AS hits,
             MIN(v.created_at)                                               AS first_seen,
             MAX(v.created_at)                                               AS last_seen,
             (ARRAY_REMOVE(ARRAY_AGG(v.user_id ORDER BY v.created_at DESC), NULL))[1] AS last_user_id,
             COUNT(DISTINCT v.user_id)                                       AS users
      FROM app.visit_log v
      WHERE v.created_at >= ${since}
      GROUP BY v.ip
      ORDER BY MAX(v.created_at) DESC
      LIMIT ${take}
    `);

    const total = await this.prisma.$queryRaw<Array<{ n: bigint }>>(
      Prisma.sql`SELECT COUNT(DISTINCT ip) AS n FROM app.visit_log WHERE created_at >= ${since}`,
    );

    // Résolution du dernier user connu par IP (sans FK dure → lookup séparé).
    const userIds = [...new Set(rows.map((r) => r.last_user_id).filter((x): x is string => Boolean(x)))];
    const users = userIds.length
      ? await this.prisma.user.findMany({
          where: { id: { in: userIds } },
          select: { id: true, email: true, profile: { select: { displayName: true } } },
        })
      : [];
    const byId = new Map(users.map((u) => [u.id, u]));

    return {
      days: clampedDays,
      totalUniqueIps: Number(total[0]?.n ?? 0),
      entries: rows.map((r) => ({
        ip: r.ip,
        hits: Number(r.hits),
        firstSeen: r.first_seen,
        lastSeen: r.last_seen,
        knownUsers: Number(r.users),
        lastUserId: r.last_user_id,
        lastUserName: r.last_user_id ? (byId.get(r.last_user_id)?.profile?.displayName ?? null) : null,
        lastUserEmail: r.last_user_id ? (byId.get(r.last_user_id)?.email ?? null) : null,
      })),
    };
  }

  /** Journal des visites, paginé (cursor = id), filtrable par IP exacte ou userId. */
  async visits(opts: { limit: number; cursor?: string; ip?: string; userId?: string }): Promise<Record<string, unknown>> {
    const take = Math.min(200, Math.max(1, opts.limit));
    const rows = await this.prisma.visitLog.findMany({
      where: { ...(opts.ip ? { ip: opts.ip } : {}), ...(opts.userId ? { userId: opts.userId } : {}) },
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take: take + 1,
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
    });
    const hasMore = rows.length > take;
    const page = hasMore ? rows.slice(0, take) : rows;

    // Résolution des users (userId sans FK dure → lookup séparé, les supprimés restent null).
    const userIds = [...new Set(page.map((v) => v.userId).filter((x): x is string => Boolean(x)))];
    const users = userIds.length
      ? await this.prisma.user.findMany({
          where: { id: { in: userIds } },
          select: { id: true, email: true, profile: { select: { displayName: true } } },
        })
      : [];
    const byId = new Map(users.map((u) => [u.id, u]));

    return {
      entries: page.map((v) => ({
        id: v.id,
        ip: v.ip,
        path: v.path,
        method: v.method,
        userAgent: v.userAgent,
        createdAt: v.createdAt,
        userId: v.userId,
        userEmail: v.userId ? (byId.get(v.userId)?.email ?? null) : null,
        userName: v.userId ? (byId.get(v.userId)?.profile?.displayName ?? null) : null,
      })),
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  }

  /** Liste des utilisateurs (récents d'abord), recherche par email/pseudo, paginé par cursor. */
  async users(opts: { limit: number; cursor?: string; q?: string }): Promise<Record<string, unknown>> {
    const take = Math.min(100, Math.max(1, opts.limit));
    const q = opts.q?.trim();
    const rows = await this.prisma.user.findMany({
      where: q
        ? {
            OR: [
              { email: { contains: q, mode: "insensitive" } },
              { profile: { displayName: { contains: q, mode: "insensitive" } } },
            ],
          }
        : undefined,
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take: take + 1,
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      select: {
        id: true,
        email: true,
        status: true,
        createdAt: true,
        lastLoginAt: true,
        profile: { select: { displayName: true, sex: true, locale: true, city: true } },
        hybridIndex: { select: { value: true } },
        _count: { select: { wodResults: true, posts: true } },
      },
    });
    const hasMore = rows.length > take;
    const page = hasMore ? rows.slice(0, take) : rows;
    return {
      entries: page.map((u) => ({
        userId: u.id,
        email: u.email,
        status: u.status,
        createdAt: u.createdAt,
        lastLoginAt: u.lastLoginAt,
        displayName: u.profile?.displayName ?? null,
        sex: u.profile?.sex ?? null,
        locale: u.profile?.locale ?? null,
        city: u.profile?.city ?? null,
        index: u.hybridIndex ? ovr(u.hybridIndex.value) : null,
        sessions: u._count.wodResults,
        posts: u._count.posts,
      })),
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  }

  /** Fiche détaillée d'un utilisateur : profil, Index, attributs, séances/visites récentes… */
  async userDetail(userId: string): Promise<Record<string, unknown>> {
    const u = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        status: true,
        createdAt: true,
        lastLoginAt: true,
        deletionRequestedAt: true,
        profile: true,
        hybridIndex: { select: { value: true, computedAt: true, radarCoverage: true } },
        attributeScores: { select: { attribute: true, score: true, unlocked: true } },
        streak: { select: { current: true, best: true, validatedActiveWeeks: true } },
        clubMemberships: { select: { role: true, club: { select: { name: true } } } },
        pushTokens: { select: { platform: true, createdAt: true } },
        _count: { select: { wodResults: true, posts: true, followers: true, following: true } },
        wodResults: {
          orderBy: { performedAt: "desc" },
          take: 15,
          select: { wodId: true, rawResult: true, subScore: true, performedAt: true, rxCompliant: true, wod: { select: { name: true } } },
        },
      },
    });
    if (!u) throw new NotFoundException({ code: "NOT_FOUND", message: "Utilisateur introuvable." });

    const lastVisits = await this.prisma.visitLog.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      take: 20,
      select: { ip: true, path: true, method: true, createdAt: true, userAgent: true },
    });

    return {
      userId: u.id,
      email: u.email,
      status: u.status,
      createdAt: u.createdAt,
      lastLoginAt: u.lastLoginAt,
      deletionRequestedAt: u.deletionRequestedAt,
      profile: u.profile
        ? { displayName: u.profile.displayName, sex: u.profile.sex, goal: u.profile.goal, rank: u.profile.rank, city: u.profile.city, locale: u.profile.locale }
        : null,
      index: u.hybridIndex
        ? { value: ovr(u.hybridIndex.value), computedAt: u.hybridIndex.computedAt, radarCoverage: u.hybridIndex.radarCoverage }
        : null,
      attributes: u.attributeScores.map((a) => ({ attribute: a.attribute, score: ovr(a.score), unlocked: a.unlocked })),
      streak: u.streak,
      clubs: u.clubMemberships.map((m) => ({ name: m.club.name, role: m.role })),
      devices: u.pushTokens,
      counts: { sessions: u._count.wodResults, posts: u._count.posts, followers: u._count.followers, following: u._count.following },
      recentSessions: u.wodResults.map((r) => ({
        wodId: r.wodId,
        wodName: r.wod?.name ?? r.wodId,
        rawResult: Number(r.rawResult),
        subScore: r.subScore !== null ? ovr(r.subScore) : null,
        rxCompliant: r.rxCompliant,
        performedAt: r.performedAt,
      })),
      recentVisits: lastVisits,
    };
  }

  /** Feedbacks (bugs signalés) — table sans relation Prisma vers User (FK logique) → lookup séparé. */
  async feedbacks(limit: number): Promise<Record<string, unknown>> {
    const take = Math.min(200, Math.max(1, limit));
    const rows = await this.prisma.feedback.findMany({ orderBy: { createdAt: "desc" }, take });
    const userIds = [...new Set(rows.map((f) => f.userId))];
    const users = userIds.length
      ? await this.prisma.user.findMany({
          where: { id: { in: userIds } },
          select: { id: true, email: true, profile: { select: { displayName: true } } },
        })
      : [];
    const byId = new Map(users.map((u) => [u.id, u]));
    return {
      entries: rows.map((f) => ({
        id: f.id,
        message: f.message,
        context: f.context,
        createdAt: f.createdAt,
        userId: f.userId,
        userEmail: byId.get(f.userId)?.email ?? null,
        userName: byId.get(f.userId)?.profile?.displayName ?? null,
      })),
    };
  }

  /** Purge quotidienne du journal de visites au-delà de la rétention (RGPD, 04:10 UTC). */
  @Cron("10 4 * * *")
  async purgeOldVisits(): Promise<void> {
    try {
      const res = await this.prisma.visitLog.deleteMany({
        where: { createdAt: { lt: daysAgo(VISIT_RETENTION_DAYS) } },
      });
      if (res.count > 0) this.logger.log(`visit_log : ${res.count} entrées purgées (> ${VISIT_RETENTION_DAYS} j).`);
    } catch (e) {
      this.logger.warn(`Purge visit_log échouée : ${(e as Error).message}`);
    }
  }
}
