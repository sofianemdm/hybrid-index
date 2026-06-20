import { Injectable, NotFoundException } from "@nestjs/common";
import { ATTRIBUTE_KEYS, type internalScore } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { SESSIONS, type Session } from "./sessions.data";

export interface CoachResponse {
  targetAttribute: string;
  projection: internalScore.ComputeProjectionResponse;
  sessions: Session[];
}

/**
 * Coach : l'utilisateur cible un attribut faible → on calcule l'Index PROJETÉ (autorité
 * score-service) et on propose des séances ciblées (filtrées selon le matériel disponible).
 */
@Injectable()
export class CoachService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
  ) {}

  async coach(userId: string, attribute?: string): Promise<CoachResponse> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    const scores = await this.prisma.attributeScore.findMany({ where: { userId } });
    const byAttr = new Map(scores.map((s) => [s.attribute, s]));
    const attributeScores = ATTRIBUTE_KEYS.map((a) => {
      const s = byAttr.get(a);
      return { attribute: a, score: s?.score ?? 0, unlocked: s?.unlocked ?? false, isEstimated: s?.isEstimated ?? false };
    });

    // Cible : l'attribut demandé, sinon le plus faible parmi les attributs débloqués.
    const unlocked = attributeScores.filter((a) => a.unlocked);
    const target =
      (attribute as (typeof ATTRIBUTE_KEYS)[number] | undefined) ??
      (unlocked.length > 0
        ? unlocked.reduce((min, a) => (a.score < min.score ? a : min)).attribute
        : ATTRIBUTE_KEYS[0]);

    const projection = await this.scoreClient.computeProjection({
      goal: profile.goal,
      targetAttribute: target,
      attributeScores,
    });

    const noGear = profile.equipmentPref === "none";
    const sessions = SESSIONS.filter(
      (s) => s.primaryAttribute === target && (!noGear || !s.requiresEquipment),
    ).slice(0, 8);

    return { targetAttribute: target, projection, sessions };
  }
}
