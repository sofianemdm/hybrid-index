import { Injectable } from "@nestjs/common";
import type { Sex } from "@prisma/client";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { isoWeekKey } from "../engagement/iso-week";

/** Barème de points d'effort (EP) — cf. docs/gamification/classement-progression-hebdo.md. */
const EP = { log: 10, activeDay: 15, pr: 40, newWod: 25 };
const CAP = { logPerDay: 3, logPerWeek: 12, prPerDay: 2, prPerWeek: 5 };

function startOfUtcDay(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

export interface AwardInput {
  wodResultId: string;
  wodId: string;
  subScore: number | null;
  performedAt: Date;
}

/**
 * Classement de PROGRESSION HEBDO (B1) : on classe par EFFORT fourni cette semaine, jamais par
 * niveau. Tout le monde peut briller (régularité > volume, PR, exploration). Anti-farm par
 * plafonds. Les faux utilisateurs de seed ne génèrent aucun event → naturellement absents.
 */
@Injectable()
export class ProgressService {
  constructor(private readonly prisma: PrismaService) {}

  /** Attribue les EP d'un résultat loggé. Best-effort (ne fait jamais échouer le log). */
  async awardForResult(userId: string, sex: string, input: AwardInput): Promise<void> {
    if (input.subScore === null) return;
    const now = new Date();
    const weekKey = isoWeekKey(input.performedAt);
    // Fenêtre : semaine ISO courante uniquement (anti-backfill) ; pas de futur.
    if (weekKey !== isoWeekKey(now)) return;
    if (input.performedAt.getTime() > now.getTime() + 5 * 60_000) return;

    // Contexte : meilleur effort ANTÉRIEUR sur ce WOD (hors le résultat courant) → PR / 1ʳᵉ fois.
    const others = await this.prisma.wodResult.findMany({
      where: { userId, wodId: input.wodId, id: { not: input.wodResultId }, review: "ok", subScore: { not: null } },
      select: { subScore: true },
    });
    const isFirstEver = others.length === 0;
    const prevBest = others.length > 0 ? Math.max(...others.map((o) => o.subScore ?? 0)) : null;
    const isPr = !isFirstEver && prevBest !== null && input.subScore > prevBest;

    const dayStart = startOfUtcDay(now);
    const events: Array<{ type: string; ep: number; capped: string | null }> = [];

    // A — logger une séance (+10), plafonné 3/jour & 12/semaine.
    const [logToday, logWeek] = await Promise.all([
      this.prisma.progressEvent.count({ where: { userId, type: "wod_logged", epAwarded: { gt: 0 }, createdAt: { gte: dayStart } } }),
      this.prisma.progressEvent.count({ where: { userId, type: "wod_logged", epAwarded: { gt: 0 }, weekKey } }),
    ]);
    if (logToday >= CAP.logPerDay) events.push({ type: "wod_logged", ep: 0, capped: "daily_cap" });
    else if (logWeek >= CAP.logPerWeek) events.push({ type: "wod_logged", ep: 0, capped: "weekly_cap" });
    else events.push({ type: "wod_logged", ep: EP.log, capped: null });

    // B — jour actif (+15), une seule fois par jour (régularité > volume).
    const activeToday = await this.prisma.progressEvent.count({ where: { userId, type: "active_day", createdAt: { gte: dayStart } } });
    if (activeToday === 0) events.push({ type: "active_day", ep: EP.activeDay, capped: null });

    // F — première fois sur ce WOD (+25), encourage l'exploration.
    if (isFirstEver) events.push({ type: "new_wod", ep: EP.newWod, capped: null });

    // E — PR significatif (+40, gain ≥ 2 pts ou ≥ 1 %), plafonné 2/jour & 5/semaine.
    if (isPr && this.significantPr(input.subScore, prevBest)) {
      const [prToday, prWeek] = await Promise.all([
        this.prisma.progressEvent.count({ where: { userId, type: "pr", epAwarded: { gt: 0 }, createdAt: { gte: dayStart } } }),
        this.prisma.progressEvent.count({ where: { userId, type: "pr", epAwarded: { gt: 0 }, weekKey } }),
      ]);
      if (prToday >= CAP.prPerDay) events.push({ type: "pr", ep: 0, capped: "daily_cap" });
      else if (prWeek >= CAP.prPerWeek) events.push({ type: "pr", ep: 0, capped: "weekly_cap" });
      else events.push({ type: "pr", ep: EP.pr, capped: null });
    }

    const net = events.reduce((s, e) => s + e.ep, 0);
    const gotActiveDay = events.some((e) => e.type === "active_day" && e.ep > 0);
    const gotPr = events.some((e) => e.type === "pr" && e.ep > 0);

    await this.prisma.$transaction([
      this.prisma.progressEvent.createMany({
        data: events.map((e) => ({
          userId,
          weekKey,
          type: e.type,
          epAwarded: e.ep,
          cappedReason: e.capped,
          refId: input.wodResultId,
        })),
      }),
      this.prisma.progressWeekly.upsert({
        where: { userId_weekKey: { userId, weekKey } },
        create: { userId, weekKey, sex: sex as Sex, ep: net, activeDays: gotActiveDay ? 1 : 0, prCount: gotPr ? 1 : 0 },
        update: {
          ep: { increment: net },
          activeDays: { increment: gotActiveDay ? 1 : 0 },
          prCount: { increment: gotPr ? 1 : 0 },
        },
      }),
    ]);
  }

  private significantPr(subScore: number, prevBest: number | null): boolean {
    if (prevBest === null) return false;
    const gain = subScore - prevBest;
    return gain >= 2 || gain >= prevBest * 0.01;
  }

  /** Classement de la semaine courante (par sexe). Personne n'est « dernier » : EP = 0 → absent.
   *  IMPORTANT : on restreint aux athlètes qui ont ENCORE un profil. Un compte supprimé peut laisser
   *  des lignes progress_weekly orphelines (agrégat sans FK cascade — cf. engagement.service) : elles
   *  ne doivent JAMAIS apparaître au classement, sinon on affiche des lignes « — » sans nom. */
  async board(sex: string, userId?: string, memberIds?: string[]): Promise<unknown> {
    const weekKey = isoWeekKey(new Date());
    // Profils existants du sexe visé (éventuellement restreints à un club) = seuls athlètes classables.
    const eligible = await this.prisma.profile.findMany({
      where: { sex: sex as Sex, ...(memberIds ? { userId: { in: memberIds } } : {}) },
      select: { userId: true, displayName: true, rank: true },
    });
    const names = new Map(eligible.map((p) => [p.userId, p]));
    const eligibleIds = eligible.map((p) => p.userId);
    const where = { weekKey, sex: sex as Sex, ep: { gt: 0 }, userId: { in: eligibleIds } };
    const [rows, total] = await Promise.all([
      this.prisma.progressWeekly.findMany({ where, orderBy: { ep: "desc" }, take: 50 }),
      this.prisma.progressWeekly.count({ where }),
    ]);
    const entries = rows.map((r, i) => ({
      position: i + 1,
      userId: r.userId,
      displayName: names.get(r.userId)?.displayName ?? "—",
      rank: names.get(r.userId)?.rank ?? "rookie",
      ep: r.ep,
      isMe: r.userId === userId,
    }));

    let me: { position: number; ep: number } | null = null;
    if (userId) {
      const mine = await this.prisma.progressWeekly.findUnique({ where: { userId_weekKey: { userId, weekKey } } });
      if (mine && mine.ep > 0) {
        const above = await this.prisma.progressWeekly.count({
          where: { weekKey, sex: sex as Sex, ep: { gt: mine.ep }, userId: { in: eligibleIds } },
        });
        me = { position: above + 1, ep: mine.ep };
      }
    }
    return { weekKey, total, me, entries };
  }
}
