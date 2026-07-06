import { Injectable } from "@nestjs/common";
import type { Sex } from "@prisma/client";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { isoWeekKey, weekStart, addWeeks } from "../engagement/iso-week";
import { FLAGSHIP_WOD_IDS } from "../wods/wod-constants";
import { WOD_PRESCRIPTIONS } from "../wods/wod-prescriptions.data";

/**
 * Défi de la semaine : un WOD imposé qui change chaque semaine, en rotation VARIÉE
 * (cardio / force / hybride / HYROX / sans matériel). Tout le monde se mesure dessus ;
 * le classement du défi ne compte QUE les résultats loggés pendant la semaine en cours.
 */
// IMPORTANT : on EXCLUT les WODs « flagship » (permanents, toujours dispo dans l'app :
// hyrox_sprint, grace, benchmark_zero, ergo_skill « Machine & Mur »). Les annoncer comme
// « nouvelle séance de la semaine » était trompeur (l'utilisateur y a toujours accès → ça semble
// « ancien »). La rotation ne contient donc que des benchmarks non-permanents.
const ROTATION: ReadonlyArray<{ wodId: string; theme: string }> = [
  { wodId: "fran", theme: "Force & cardio" },
  { wodId: "run_5k", theme: "Cardio pur" },
  { wodId: "helen", theme: "Hybride" },
  { wodId: "karen", theme: "Mental & cardio" },
  { wodId: "row_2k", theme: "Cardio · rameur" },
  { wodId: "cindy", theme: "Endurance" },
  { wodId: "jackie", theme: "Hybride" },
  { wodId: "burpees_7min", theme: "Cardio · sans matériel" },
];

const WEEK_MS = 7 * 86_400_000;
// Lundi 1er janvier 2024 (UTC) comme origine de rotation.
const EPOCH_MONDAY = Date.UTC(2024, 0, 1);

const ovrSub = (v: number | null): number | null => (v == null ? null : Math.round(ratingFromInternal(v)));

@Injectable()
export class ChallengeService {
  constructor(private readonly prisma: PrismaService) {}

  private slot(now: Date): { wodId: string; theme: string; start: Date; end: Date; weekKey: string } {
    const start = weekStart(now);
    const idx = Math.round((start.getTime() - EPOCH_MONDAY) / WEEK_MS);
    const pick = ROTATION[((idx % ROTATION.length) + ROTATION.length) % ROTATION.length];
    return { ...pick, start, end: addWeeks(start, 1), weekKey: isoWeekKey(now) };
  }

  async current(): Promise<unknown> {
    const s = this.slot(new Date());
    const wod = await this.prisma.wod.findUnique({ where: { id: s.wodId } });
    return {
      weekKey: s.weekKey,
      theme: s.theme,
      wodId: s.wodId,
      wodName: wod?.name ?? s.wodId,
      scoreType: wod?.scoreType ?? "time",
      isFlagship: FLAGSHIP_WOD_IDS.includes(s.wodId),
      startsAt: s.start.toISOString(),
      endsAt: s.end.toISOString(),
      prescription: WOD_PRESCRIPTIONS[s.wodId] ?? null,
    };
  }

  /** Classement du défi : meilleur effort par utilisateur sur le WOD du défi, CETTE semaine. */
  async leaderboard(sex: string, userId?: string): Promise<unknown> {
    const s = this.slot(new Date());
    const rows = await this.prisma.wodResult.findMany({
      where: {
        wodId: s.wodId,
        sex: sex as Sex,
        review: "ok",
        subScore: { not: null },
        rxCompliant: true,
        performedAt: { gte: s.start, lt: s.end },
      },
      orderBy: [{ subScore: "desc" }],
      distinct: ["userId"],
      take: 100,
      select: { userId: true, subScore: true, rawResult: true },
    });
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: rows.map((r) => r.userId) } },
      select: { userId: true, displayName: true, rank: true },
    });
    const names = new Map(profiles.map((p) => [p.userId, p]));
    const entries = rows.map((r, i) => ({
      position: i + 1,
      userId: r.userId,
      displayName: names.get(r.userId)?.displayName ?? "—",
      rank: names.get(r.userId)?.rank ?? "rookie",
      rawResult: Number(r.rawResult),
      subScore: ovrSub(r.subScore),
      isMe: r.userId === userId,
    }));
    return { weekKey: s.weekKey, wodId: s.wodId, sex, total: entries.length, entries };
  }
}
