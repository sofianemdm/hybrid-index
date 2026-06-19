import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { ProfileScoringService, type PersistedProfile } from "../profile/profile-scoring.service";
import { SCORING_VERSION_UUID } from "../../common/constants";
import type { LogResultRequest } from "./results.dto";

export interface LogResultResponse {
  result: {
    id: string;
    wodId: string;
    rawResult: number;
    subScore: number | null;
    percentile: number | null;
    performedAt: string;
  };
  /** Profil recalculé (l'Index a pu bouger). */
  profile: PersistedProfile;
}

/**
 * Log d'un WOD : note l'effort via le score-service (bornes anti-triche §5.5),
 * persiste le résultat, puis recalcule l'Index/radar (no-drop). L'Index ne descend jamais
 * sur un moins bon résultat : le score-service garde le meilleur effort par attribut.
 */
@Injectable()
export class ResultsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly profileScoring: ProfileScoringService,
  ) {}

  async log(userId: string, req: LogResultRequest): Promise<LogResultResponse> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    // Note l'effort (propage 422 si hors bornes physiologiques, 404 si WOD inconnu).
    const scored = await this.scoreClient.computeSubScore({
      wodId: req.wodId,
      sex: profile.sex,
      scoreType: req.scoreType,
      rawResult: req.rawResult,
    });

    const performedAt = req.performedAt ?? new Date();
    const data = {
      wodId: req.wodId,
      sex: profile.sex,
      rawResult: req.rawResult,
      subScore: scored.subScore,
      percentile: scored.percentile,
      attributesAffected: scored.attributesAffected,
      source: "declared" as const,
      scoringVersionId: SCORING_VERSION_UUID,
      performedAt,
    };
    // Idempotent si une clé est fournie (retry réseau mobile) ; sinon création simple (historique).
    const created = req.idempotencyKey
      ? await this.prisma.wodResult.upsert({
          where: { userId_idempotencyKey: { userId, idempotencyKey: req.idempotencyKey } },
          create: { userId, idempotencyKey: req.idempotencyKey, ...data },
          update: data,
        })
      : await this.prisma.wodResult.create({ data: { userId, ...data } });

    const recomputed = await this.profileScoring.recomputeForUser(userId);
    if (!recomputed) throw new NotFoundException({ code: "NOT_FOUND", message: "Recalcul impossible." });

    return {
      result: {
        id: created.id,
        wodId: created.wodId,
        rawResult: Number(created.rawResult),
        subScore: created.subScore,
        percentile: created.percentile === null ? null : Number(created.percentile),
        performedAt: created.performedAt.toISOString(),
      },
      profile: recomputed,
    };
  }

  async list(userId: string): Promise<unknown[]> {
    const rows = await this.prisma.wodResult.findMany({
      where: { userId },
      orderBy: { performedAt: "desc" },
      take: 50,
    });
    return rows.map((r) => ({
      id: r.id,
      wodId: r.wodId,
      rawResult: Number(r.rawResult),
      subScore: r.subScore,
      percentile: r.percentile === null ? null : Number(r.percentile),
      performedAt: r.performedAt.toISOString(),
    }));
  }
}
