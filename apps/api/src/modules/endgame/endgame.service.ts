import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";

/**
 * Endgame (cahier §) : Grand Chelem (battre le pro sur les 15 WODs), classement mondial (tous
 * sexes), statut ambassadeur. Le comparatif au pro est calculé par le score-service (autorité).
 */
@Injectable()
export class EndgameService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
  ) {}

  async endgame(userId: string): Promise<unknown> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    const idx = await this.prisma.hybridIndex.findUnique({ where: { userId } });
    const results = await this.prisma.wodResult.findMany({ where: { userId }, select: { wodId: true, rawResult: true } });

    const gs = await this.scoreClient.computeGrandSlam({
      sex: profile.sex,
      bests: results.map((r) => ({ wodId: r.wodId, rawResult: Number(r.rawResult) })),
    });

    // Classement mondial (toutes ligues confondues).
    const globalTotal = await this.prisma.hybridIndex.count();
    let globalRank: number | null = null;
    if (idx) {
      const above = await this.prisma.hybridIndex.count({ where: { value: { gt: idx.value } } });
      globalRank = above + 1;
    }

    const grandSlamComplete = gs.total > 0 && gs.beaten === gs.total;
    return {
      grandSlam: { beaten: gs.beaten, total: gs.total, remaining: gs.remaining, complete: grandSlamComplete },
      globalRank,
      globalTotal,
      isTop100: globalRank !== null && globalRank <= 100,
      // Statut ambassadeur : Grand Chelem complet (critère initial — affinable produit).
      ambassador: grandSlamComplete,
    };
  }
}
