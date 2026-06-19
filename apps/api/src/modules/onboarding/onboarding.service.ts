import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { type internalScore, type onboardingDto, rankFromIndex } from "@hybrid-index/contracts";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService, type PersistedProfile } from "../profile/profile-scoring.service";
import type { OnboardingCompleteRequest } from "./onboarding-complete.dto";

/**
 * Onboarding — calcule le HYBRID INDEX PROVISOIRE (le « reveal », cahier §8) à partir
 * d'un temps de course et/ou d'une auto-évaluation.
 * - `estimate` : calcul pur SANS compte (aperçu temps réel du wizard).
 * - `complete` : authentifié, persiste les efforts + l'Index révélé (état durable du compte).
 */
@Injectable()
export class OnboardingService {
  constructor(
    private readonly scoreClient: ScoreClient,
    private readonly prisma: PrismaService,
    private readonly profileScoring: ProfileScoringService,
  ) {}

  async estimate(req: onboardingDto.OnboardingEstimateRequest): Promise<onboardingDto.RevealResponse> {
    const efforts = this.toEfforts(req.course, req.estimatedPushups);
    if (efforts.length === 0) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: "Fournis au moins un temps de course ou une estimation de pompes.",
      });
    }

    const profile = await this.scoreClient.computeProfile({ sex: req.sex, goal: req.goal, efforts });

    return {
      index: {
        value: profile.index.value,
        percentile: profile.index.percentile,
        rank: rankFromIndex(profile.index.value),
        isProvisional: profile.index.isProvisional,
        isEstimated: profile.index.isEstimated,
        radarCoverage: profile.index.radarCoverage,
      },
      radar: profile.radar.map((a) => ({
        attribute: a.attribute,
        score: a.score,
        unlocked: a.unlocked,
        isEstimated: a.isEstimated,
      })),
    };
  }

  /** Persiste les efforts d'onboarding et renvoie l'Index révélé (désormais durable). */
  async complete(userId: string, req: OnboardingCompleteRequest): Promise<PersistedProfile> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    const efforts = this.toEfforts(req.course, req.estimatedPushups);
    if (efforts.length === 0) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: "Fournis au moins un temps de course ou une estimation de pompes.",
      });
    }

    const now = new Date();
    await Promise.all(
      efforts.map((e) =>
        this.prisma.wodResult.upsert({
          where: { userId_idempotencyKey: { userId, idempotencyKey: `onboarding:${e.wodId}` } },
          create: {
            userId,
            wodId: e.wodId,
            sex: profile.sex,
            rawResult: e.rawResult,
            source: "declared",
            idempotencyKey: `onboarding:${e.wodId}`,
            performedAt: now,
          },
          update: { rawResult: e.rawResult, performedAt: now },
        }),
      ),
    );

    const result = await this.profileScoring.recomputeForUser(userId);
    if (!result) throw new NotFoundException({ code: "NOT_FOUND", message: "Calcul du profil impossible." });
    return result;
  }

  private toEfforts(
    course: { wodId: string; timeSeconds: number } | undefined,
    estimatedPushups: number | undefined,
  ): internalScore.EffortInput[] {
    const efforts: internalScore.EffortInput[] = [];
    if (course) {
      efforts.push({ wodId: course.wodId, rawResult: course.timeSeconds, ageWeeks: 0 });
    }
    if (estimatedPushups !== undefined) {
      efforts.push({ wodId: "max_pushups", rawResult: estimatedPushups, ageWeeks: 0 });
    }
    return efforts;
  }
}
