import { Injectable, Logger } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { isoWeekKey } from "../engagement/iso-week";
import { monthKeyOf } from "./league.rotation";
import { LeagueLifecycleService } from "./league-lifecycle.service";
import { totalsBestPerWeek, rankTotals } from "./league.aggregate";
import type {
  LeagueSeasonView,
  LeagueWeekView,
  LeagueStandingsView,
  LeagueMeView,
  LeagueLastResultView,
  LeaguePodiumRow,
} from "./league.dto";
import { avatarMapByUserId } from "../../common/avatar.serializer";
import { primaryClubNameByUserId } from "../../common/club-lookup";

const DEFAULT_TOP = 50;

/** Lectures de la Ligue (saison/semaine courante, classement mensuel, résumé perso). */
@Injectable()
export class LeagueService {
  private readonly logger = new Logger(LeagueService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly lifecycle: LeagueLifecycleService,
  ) {}

  /**
   * Garde idempotent : renvoie la saison qui couvre « maintenant » et, si AUCUNE n'est active
   * (ex. la saison du mois a été supprimée par un run e2e sur la base de dev — cf. mémoire
   * « e2e-pollue-base-dev »), la RECRÉE à la volée pour le mois courant. Ainsi l'utilisateur ne
   * voit JAMAIS « aucune saison de ligue en cours ».
   *
   * `openSeasonForMonth` est déjà idempotent et protégé (il refuse de créer une saison cassée si
   * les WODs Ligue ne sont pas seedés → il lève). On capture cette erreur : dans ce cas on
   * retombe sur le comportement historique (pas de saison) plutôt que de propager un 500.
   */
  private async ensureActiveSeason(now = new Date()) {
    const existing = await this.activeSeason(now);
    if (existing) return existing;
    try {
      await this.lifecycle.openSeasonForMonth(monthKeyOf(now));
    } catch (e) {
      // WODs Ligue non seedés (ou course concurrente) → on ne casse pas l'endpoint.
      this.logger.warn(`Auto-réparation saison Ligue impossible : ${e}`);
    }
    // Re-lecture : si la création a réussi (ou si un autre process l'a créée entre-temps).
    return this.activeSeason(now);
  }

  private async activeSeason(now = new Date()) {
    // « La » saison active = celle qui COUVRE le moment présent (une saison future ne compte pas).
    return this.prisma.leagueSeason.findFirst({
      where: { status: "active", opensAt: { lte: now }, closesAt: { gt: now } },
    });
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
    const season = await this.ensureActiveSeason(now);
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
    const season = await this.ensureActiveSeason();
    if (!season) return { monthKey: null, sex, total: 0, entries: [], me: null };

    const rows = await this.prisma.leaguePoints.findMany({
      where: { seasonId: season.id, sex, review: "ok" },
      select: { userId: true, weekId: true, points: true },
    });
    const ranked = rankTotals(totalsBestPerWeek(rows));

    const topIds = ranked.slice(0, DEFAULT_TOP).map((t) => t.userId);
    const viewerNeedsName = viewerUserId && !topIds.includes(viewerUserId) ? [viewerUserId] : [];
    // Noms + avatars + club des athlètes affichés en parallèle, chacun en UNE requête batch (pas de N+1).
    const [names, avatars, clubMembers] = await Promise.all([
      this.prisma.profile.findMany({
        where: { userId: { in: [...topIds, ...viewerNeedsName] } },
        select: { userId: true, displayName: true },
      }),
      this.prisma.avatar.findMany({ where: { userId: { in: topIds } } }),
      // Inclure le VIEWER (même hors top-50) pour que son club apparaisse sur sa carte « ma position ».
      this.prisma.clubMember.findMany({
        where: { userId: { in: [...topIds, ...viewerNeedsName] } },
        select: { userId: true, club: { select: { name: true, status: true } } },
        orderBy: { joinedAt: "asc" },
      }),
    ]);
    const nameOf = new Map(names.map((n) => [n.userId, n.displayName]));
    const avatarOf = avatarMapByUserId(avatars);
    const clubOf = primaryClubNameByUserId(clubMembers);

    const entries = ranked.slice(0, DEFAULT_TOP).map((t, i) => ({
      position: i + 1,
      userId: t.userId,
      displayName: nameOf.get(t.userId) ?? "Athlète",
      points: t.total,
      isMe: t.userId === viewerUserId,
      avatar: avatarOf.get(t.userId) ?? null, // absent de la map = pas d'avatar → repli mobile
      clubName: clubOf.get(t.userId) ?? null,
    }));

    let me: { position: number; points: number; clubName: string | null } | null = null;
    if (viewerUserId) {
      const idx = ranked.findIndex((t) => t.userId === viewerUserId);
      if (idx >= 0)
        me = { position: idx + 1, points: ranked[idx].total, clubName: clubOf.get(viewerUserId) ?? null };
    }
    return { monthKey: season.monthKey, sex, total: ranked.length, entries, me };
  }

  /**
   * Résultat de la DERNIÈRE saison CLOSE (status="closed", closedAt le plus récent), pour le
   * « reveal » de fin de saison côté mobile. Renvoie le PODIUM (top 3) du SEXE du viewer + sa
   * propre ligne (s'il a participé). Renvoie `null` si aucune saison close n'existe.
   *
   * Le sexe du viewer = celui de son standing dans cette saison s'il a participé, sinon celui de
   * son Profil (un non-participant voit quand même le podium de SA ligue). Sans viewer connu, on
   * retombe sur "male" (le contrôleur protège l'endpoint, ce cas reste défensif).
   *
   * Aucune requête N+1 : profils + avatars du podium sont chargés en UNE requête batch chacun.
   */
  async lastResult(viewerUserId: string | undefined): Promise<LeagueLastResultView | null> {
    const season = await this.prisma.leagueSeason.findFirst({
      where: { status: "closed", closedAt: { not: null } },
      orderBy: { closedAt: "desc" },
      select: { id: true, monthKey: true },
    });
    if (!season) return null;

    // Sexe du viewer : standing de la saison en priorité, sinon profil.
    let viewerStanding: { finalRank: number; totalPoints: number; movement: string | null; sex: string } | null =
      null;
    let sex: "male" | "female" = "male";
    if (viewerUserId) {
      const std = await this.prisma.leagueStanding.findUnique({
        where: { seasonId_userId: { seasonId: season.id, userId: viewerUserId } },
        select: { finalRank: true, totalPoints: true, movement: true, sex: true },
      });
      if (std) {
        viewerStanding = std;
        sex = std.sex as "male" | "female";
      } else {
        const profile = await this.prisma.profile.findUnique({
          where: { userId: viewerUserId },
          select: { sex: true },
        });
        if (profile?.sex === "female" || profile?.sex === "male") sex = profile.sex;
      }
    }

    const top = await this.prisma.leagueStanding.findMany({
      where: { seasonId: season.id, sex },
      orderBy: { finalRank: "asc" },
      take: 3,
      select: { userId: true, finalRank: true, totalPoints: true },
    });

    const podiumIds = top.map((s) => s.userId);
    const [names, avatars] = await Promise.all([
      this.prisma.profile.findMany({
        where: { userId: { in: podiumIds } },
        select: { userId: true, displayName: true },
      }),
      this.prisma.avatar.findMany({ where: { userId: { in: podiumIds } } }),
    ]);
    const nameOf = new Map(names.map((n) => [n.userId, n.displayName]));
    const avatarOf = avatarMapByUserId(avatars);

    const podium: LeaguePodiumRow[] = top.map((s) => ({
      finalRank: s.finalRank,
      userId: s.userId,
      displayName: nameOf.get(s.userId) ?? "Athlète",
      totalPoints: s.totalPoints,
      avatar: avatarOf.get(s.userId) ?? null,
    }));

    return {
      monthKey: season.monthKey,
      sex,
      podium,
      me: viewerStanding
        ? {
            finalRank: viewerStanding.finalRank,
            totalPoints: viewerStanding.totalPoints,
            movement: viewerStanding.movement,
          }
        : null,
    };
  }

  async me(userId: string): Promise<LeagueMeView> {
    const season = await this.ensureActiveSeason();
    if (!season) return { enrolled: false, monthKey: null, points: 0, position: null, weeksPlayed: 0, clubName: null };
    // Club « principal » du viewer : affiché sur sa carte « ma position » (même hors top-50).
    const clubMembers = await this.prisma.clubMember.findMany({
      where: { userId },
      select: { userId: true, club: { select: { name: true, status: true } } },
      orderBy: { joinedAt: "asc" },
    });
    const clubName = primaryClubNameByUserId(clubMembers).get(userId) ?? null;
    const entry = await this.prisma.leagueEntry.findUnique({
      where: { seasonId_userId: { seasonId: season.id, userId } },
      select: { sex: true },
    });
    if (!entry)
      return { enrolled: false, monthKey: season.monthKey, points: 0, position: null, weeksPlayed: 0, clubName };

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
      clubName,
    };
  }
}
