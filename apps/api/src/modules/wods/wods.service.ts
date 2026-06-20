import { Injectable, NotFoundException } from "@nestjs/common";
import type { Sex } from "@prisma/client";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";

@Injectable()
export class WodsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
  ) {}

  /** Catalogue des WODs (15 références + communautaires à venir). */
  async catalog(): Promise<unknown[]> {
    const wods = await this.prisma.wod.findMany({ orderBy: [{ requiresEquipment: "asc" }, { name: "asc" }] });
    return wods.map((w) => ({
      id: w.id,
      name: w.name,
      type: w.type,
      scoreType: w.scoreType,
      requiresEquipment: w.requiresEquipment,
      targetAttributes: w.targetAttributes,
      isBenchmark: w.isBenchmark,
      isCustom: w.isCustom,
    }));
  }

  /** Fiche détaillée : métadonnées + paliers de référence (score-service) + ton meilleur effort. */
  async detail(id: string, userId?: string): Promise<unknown> {
    const wod = await this.prisma.wod.findUnique({ where: { id } });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });

    let levels: unknown = null;
    try {
      levels = await this.scoreClient.getWodLevels(id);
    } catch {
      levels = null; // WOD communautaire (pas de paliers officiels) ou score-service indisponible
    }

    let myBest: unknown = null;
    if (userId) {
      const best = await this.prisma.wodResult.findFirst({
        where: { userId, wodId: id, review: "ok", subScore: { not: null } },
        orderBy: { subScore: "desc" },
      });
      if (best) {
        myBest = {
          rawResult: Number(best.rawResult),
          subScore: best.subScore,
          performedAt: best.performedAt.toISOString(),
        };
      }
    }

    return {
      id: wod.id,
      name: wod.name,
      type: wod.type,
      scoreType: wod.scoreType,
      requiresEquipment: wod.requiresEquipment,
      targetAttributes: wod.targetAttributes,
      isBenchmark: wod.isBenchmark,
      isCustom: wod.isCustom,
      levels,
      myBest,
    };
  }

  /** Classement d'un WOD (meilleur effort par utilisateur, par sexe). */
  async leaderboard(id: string, sex: string, userId?: string): Promise<unknown> {
    const rows = await this.prisma.wodResult.findMany({
      where: { wodId: id, sex: sex as Sex, review: "ok", subScore: { not: null } },
      orderBy: [{ subScore: "desc" }],
      distinct: ["userId"], // meilleur effort par utilisateur (premier dans l'ordre subScore desc)
      take: 100,
      select: { userId: true, subScore: true, rawResult: true },
    });
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: rows.map((r) => r.userId) } },
      select: { userId: true, displayName: true, rank: true },
    });
    const names = new Map(profiles.map((p) => [p.userId, p]));
    return {
      wodId: id,
      sex,
      entries: rows.map((r, i) => ({
        position: i + 1,
        userId: r.userId,
        displayName: names.get(r.userId)?.displayName ?? "—",
        rank: names.get(r.userId)?.rank ?? "rookie",
        rawResult: Number(r.rawResult),
        subScore: r.subScore,
        isMe: r.userId === userId,
      })),
    };
  }
}
