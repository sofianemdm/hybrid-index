import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { isoWeekKey } from "../engagement/iso-week";
import { totalsBestPerWeek, rankTotals } from "./league.aggregate";
import type { LeagueSeasonView, LeagueWeekView, LeagueStandingsView, LeagueMeView } from "./league.dto";

const DEFAULT_TOP = 50;

/** Lectures de la Ligue (saison/semaine courante, classement mensuel, résumé perso). */
@Injectable()
export class LeagueService {
  constructor(private readonly prisma: PrismaService) {}

  private async activeSeason() {
    return this.prisma.leagueSeason.findFirst({ where: { status: "active" } });
  }

  /** Semaine courante (WOD imposé) d'une saison, selon la semaine ISO du jour. */
  private async currentWeekView(seasonId: string, now: Date): Promise<LeagueWeekView | null> {
    const week = await this.prisma.leagueWeek.findFirst({
      where: { seasonId, weekKey: isoWeekKey(now), filiere: "bodyweight" },
    });
    if (!week) return null;
    const wod = await this.prisma.wod.findUnique({ where: { id: week.wodId }, select: { name: true } });
    return {
      weekIndex: week.weekIndex,
      weekKey: week.weekKey,
      wodId: week.wodId,
      wodName: wod?.name ?? week.wodId,
      opensAt: week.opensAt.toISOString(),
      closesAt: week.closesAt.toISOString(),
    };
  }

  async seasonView(viewerUserId: string | undefined, now = new Date()): Promise<LeagueSeasonView | null> {
    const season = await this.activeSeason();
    if (!season) return null;
    const enrolled = viewerUserId
      ? (await this.prisma.leagueEntry.findUnique({
          where: { seasonId_userId: { seasonId: season.id, userId: viewerUserId } },
          select: { userId: true },
        })) != null
      : false;
    return {
      monthKey: season.monthKey,
      status: season.status,
      divisionTier: season.divisionTier,
      opensAt: season.opensAt.toISOString(),
      closesAt: season.closesAt.toISOString(),
      currentWeek: await this.currentWeekView(season.id, now),
      enrolled,
    };
  }

  async currentWeek(now = new Date()): Promise<LeagueWeekView | null> {
    const season = await this.activeSeason();
    if (!season) return null;
    return this.currentWeekView(season.id, now);
  }

  async standings(sex: "male" | "female", viewerUserId?: string): Promise<LeagueStandingsView> {
    const season = await this.activeSeason();
    if (!season) return { monthKey: null, sex, total: 0, entries: [], me: null };

    const rows = await this.prisma.leaguePoints.findMany({
      where: { seasonId: season.id, sex, review: "ok" },
      select: { userId: true, weekId: true, points: true },
    });
    const ranked = rankTotals(totalsBestPerWeek(rows));

    const topIds = ranked.slice(0, DEFAULT_TOP).map((t) => t.userId);
    const viewerNeedsName = viewerUserId && !topIds.includes(viewerUserId) ? [viewerUserId] : [];
    const names = await this.prisma.profile.findMany({
      where: { userId: { in: [...topIds, ...viewerNeedsName] } },
      select: { userId: true, displayName: true },
    });
    const nameOf = new Map(names.map((n) => [n.userId, n.displayName]));

    const entries = ranked.slice(0, DEFAULT_TOP).map((t, i) => ({
      position: i + 1,
      userId: t.userId,
      displayName: nameOf.get(t.userId) ?? "Athlète",
      points: t.total,
      isMe: t.userId === viewerUserId,
    }));

    let me: { position: number; points: number } | null = null;
    if (viewerUserId) {
      const idx = ranked.findIndex((t) => t.userId === viewerUserId);
      if (idx >= 0) me = { position: idx + 1, points: ranked[idx].total };
    }
    return { monthKey: season.monthKey, sex, total: ranked.length, entries, me };
  }

  async me(userId: string): Promise<LeagueMeView> {
    const season = await this.activeSeason();
    if (!season) return { enrolled: false, monthKey: null, points: 0, position: null, weeksPlayed: 0 };
    const entry = await this.prisma.leagueEntry.findUnique({
      where: { seasonId_userId: { seasonId: season.id, userId } },
      select: { sex: true },
    });
    if (!entry) return { enrolled: false, monthKey: season.monthKey, points: 0, position: null, weeksPlayed: 0 };

    const rows = await this.prisma.leaguePoints.findMany({
      where: { seasonId: season.id, sex: entry.sex, review: "ok" },
      select: { userId: true, weekId: true, points: true },
    });
    const ranked = rankTotals(totalsBestPerWeek(rows));
    const idx = ranked.findIndex((t) => t.userId === userId);
    const mine = idx >= 0 ? ranked[idx] : null;
    return {
      enrolled: true,
      monthKey: season.monthKey,
      points: mine?.total ?? 0,
      position: idx >= 0 ? idx + 1 : null,
      weeksPlayed: mine?.weeksPlayed ?? 0,
    };
  }
}
