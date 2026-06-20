import { Injectable, NotFoundException, UnprocessableEntityException } from "@nestjs/common";
import type { AttributeKey, Sex, WodType } from "@prisma/client";
import type { internalScore } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { ProfileScoringService, type PersistedProfile } from "../profile/profile-scoring.service";
import { SCORING_VERSION_UUID } from "../../common/constants";
import type { EstimateWodRequest } from "./wod-estimate.dto";
import type { CreateWodRequest, LogWodResultRequest } from "./create-wod.dto";

@Injectable()
export class WodsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly profileScoring: ProfileScoringService,
  ) {}

  /** Crée un WOD personnalisé (attributs ciblés dérivés du moteur d'estimation). */
  async create(userId: string, body: CreateWodRequest): Promise<unknown> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    const sex = (profile?.sex ?? "male") as Sex;
    const est = await this.scoreClient.computeEstimate({
      sex,
      scoreType: body.scoreType,
      wodType: body.type,
      timeCapSec: body.timeCapSec,
      rounds: body.rounds,
      blocks: body.blocks,
    });
    const targetAttributes = (est.attributesAffected.length > 0 ? est.attributesAffected : ["hybrid"]) as AttributeKey[];
    const wod = await this.prisma.wod.create({
      data: {
        name: body.name.trim(),
        isBenchmark: false,
        isCustom: true,
        createdById: userId,
        type: body.type as WodType,
        requiresEquipment: body.requiresEquipment,
        targetAttributes,
        scoreType: body.scoreType,
        movements: body.blocks,
        timeCapSec: body.timeCapSec ?? null,
        rounds: body.rounds ?? null,
        calibration: "estimated",
      },
    });
    return this.detail(wod.id, userId);
  }

  /** Logue un résultat sur un WOD (officiel → barème ; custom → moteur d'estimation), puis
   *  recalcule l'Index (no-drop, custom étiqueté estimé). */
  async logResult(
    userId: string,
    wodId: string,
    body: LogWodResultRequest,
  ): Promise<{ result: unknown; profile: PersistedProfile | null }> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });
    const wod = await this.prisma.wod.findUnique({ where: { id: wodId } });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });

    let subScore: number | null;
    let percentile: number | null;
    let attributesAffected: AttributeKey[];

    if (wod.isCustom) {
      const est = await this.scoreClient.computeEstimate({
        sex: profile.sex,
        scoreType: wod.scoreType,
        wodType: wod.type,
        timeCapSec: wod.timeCapSec ?? undefined,
        rounds: wod.rounds ?? undefined,
        blocks: wod.movements as internalScore.WodBlockInput[],
        userResult: body.rawResult,
      });
      if (est.outOfBounds) {
        throw new UnprocessableEntityException({
          code: "WOD_RESULT_OUT_OF_BOUNDS",
          message: "Résultat hors des bornes plausibles estimées pour ce WOD.",
        });
      }
      subScore = est.subScore;
      percentile = est.percentile;
      attributesAffected = est.attributesAffected as AttributeKey[];
    } else {
      const scored = await this.scoreClient.computeSubScore({
        wodId,
        sex: profile.sex,
        scoreType: wod.scoreType,
        rawResult: body.rawResult,
      });
      subScore = scored.subScore;
      percentile = scored.percentile;
      attributesAffected = scored.attributesAffected as AttributeKey[];
    }

    const created = await this.prisma.wodResult.create({
      data: {
        userId,
        wodId,
        sex: profile.sex,
        rawResult: body.rawResult,
        subScore,
        percentile,
        attributesAffected,
        source: "declared",
        scoringVersionId: SCORING_VERSION_UUID,
        rxCompliant: body.rxCompliant ?? true,
        performedAt: new Date(),
      },
    });
    await this.prisma.wod.update({ where: { id: wodId }, data: { resultCount: { increment: 1 } } });
    const recomputed = await this.profileScoring.recomputeForUser(userId);

    return {
      result: { id: created.id, wodId, rawResult: body.rawResult, subScore, rxCompliant: created.rxCompliant },
      profile: recomputed,
    };
  }

  /** Catalogue public des mouvements (pour le builder). */
  movements(): Promise<internalScore.MovementSummary[]> {
    return this.scoreClient.getMovements();
  }

  /** Estimation ad-hoc d'un WOD décomposé (aperçu live du builder). */
  estimate(req: EstimateWodRequest): Promise<internalScore.ComputeEstimateResponse> {
    return this.scoreClient.computeEstimate(req);
  }

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

  /** Classement d'un WOD (meilleur effort par utilisateur, par sexe, variante Rx ou Scaled). */
  async leaderboard(id: string, sex: string, rx: boolean, userId?: string): Promise<unknown> {
    const rows = await this.prisma.wodResult.findMany({
      where: { wodId: id, sex: sex as Sex, review: "ok", subScore: { not: null }, rxCompliant: rx },
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
