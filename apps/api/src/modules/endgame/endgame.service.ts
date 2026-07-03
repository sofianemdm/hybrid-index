import { Injectable, NotFoundException } from "@nestjs/common";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { FLAGSHIP_WOD_IDS } from "../wods/wod-constants";

/**
 * Endgame : le GRAND CHELEM = réussir les 4 séances phares.
 * - Bronze : les 4 terminées (quel que soit le temps).
 * - Argent : les 4 avec une bonne note — difficile mais atteignable (~1 an de pratique CrossFit).
 * - Or : les 4 avec une note excellente — ultra exigeant (~5 ans de muscu/CrossFit/HYROX).
 * Les seuils portent sur la note /100 (déjà normalisée par sexe → équitable H/F).
 */
const SILVER_MIN = 75;
const GOLD_MIN = 90;

@Injectable()
export class EndgameService {
  constructor(private readonly prisma: PrismaService) {}

  async endgame(userId: string): Promise<unknown> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });
    const idx = await this.prisma.hybridIndex.findUnique({ where: { userId } });

    // Meilleur sous-score (interne /1000) par séance phare.
    const rows = await this.prisma.wodResult.findMany({
      where: { userId, wodId: { in: FLAGSHIP_WOD_IDS }, review: "ok", subScore: { not: null } },
      select: { wodId: true, subScore: true },
    });
    const bestByWod = new Map<string, number>();
    for (const r of rows) {
      const cur = bestByWod.get(r.wodId) ?? 0;
      if ((r.subScore ?? 0) > cur) bestByWod.set(r.wodId, r.subScore ?? 0);
    }
    const wods = await this.prisma.wod.findMany({
      where: { id: { in: FLAGSHIP_WOD_IDS } },
      select: { id: true, name: true },
    });
    const nameById = new Map(wods.map((w) => [w.id, w.name]));

    const flagship = FLAGSHIP_WOD_IDS.map((wodId) => {
      const internal = bestByWod.get(wodId);
      return {
        wodId,
        name: nameById.get(wodId) ?? wodId,
        done: internal !== undefined,
        score: internal === undefined ? null : Math.round(ratingFromInternal(internal)), // /100
      };
    });
    const allDone = flagship.every((f) => f.done);
    const minScore = allDone ? Math.min(...flagship.map((f) => f.score ?? 0)) : 0;
    const tier = !allDone ? "none" : minScore >= GOLD_MIN ? "gold" : minScore >= SILVER_MIN ? "silver" : "bronze";

    // Classement mondial (toutes ligues confondues), pour l'écran endgame.
    const globalTotal = await this.prisma.hybridIndex.count();
    let globalRank: number | null = null;
    if (idx) {
      const above = await this.prisma.hybridIndex.count({ where: { value: { gt: idx.value } } });
      globalRank = above + 1;
    }

    return {
      grandSlam: {
        tier, // none | bronze | silver | gold
        completed: flagship.filter((f) => f.done).length,
        total: FLAGSHIP_WOD_IDS.length,
        minScore,
        thresholds: { silver: SILVER_MIN, gold: GOLD_MIN },
        flagship,
      },
      globalRank,
      globalTotal,
      isTop100: globalRank !== null && globalRank <= 100,
      ambassador: tier === "gold",
    };
  }
}
