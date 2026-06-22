import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { type internalScore, type onboardingDto, rankFromIndex } from "@hybrid-index/contracts";
import { coverageAdjustedValue, indexPercentile, ratingFromInternal } from "@hybrid-index/scoring-core";
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
    const efforts = this.toEfforts(req.course, req.estimatedPushups, req.estimatedAirSquats);
    if (efforts.length === 0) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: "Fournis au moins un temps de course ou une estimation de pompes.",
      });
    }

    const profile = await this.scoreClient.computeProfile({ sex: req.sex, goal: req.goal, efforts });

    // Ajustement de couverture (cohérent avec le profil persisté après onboarding) : la révélation
    // affiche déjà l'Index ajusté, qui remontera à mesure que le radar se complète.
    const adjValue = coverageAdjustedValue(profile.index.value, profile.index.radarCoverage);
    const ovr = Math.round(ratingFromInternal(adjValue));

    return {
      index: {
        value: ovr, // OVR /100 révélé (ajusté par couverture)
        percentile: indexPercentile(adjValue),
        rank: rankFromIndex(ovr),
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

    const efforts = this.toEfforts(req.course, req.estimatedPushups, req.estimatedAirSquats);
    if (efforts.length === 0) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: "Fournis au moins une course, des pompes ou des squats.",
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
            distanceMeters: e.distanceMeters ?? null,
            source: "declared",
            idempotencyKey: `onboarding:${e.wodId}`,
            performedAt: now,
          },
          update: { rawResult: e.rawResult, distanceMeters: e.distanceMeters ?? null, performedAt: now },
        }),
      ),
    );

    const result = await this.profileScoring.recomputeForUser(userId);
    if (!result) throw new NotFoundException({ code: "NOT_FOUND", message: "Calcul du profil impossible." });
    return result;
  }

  private toEfforts(
    course: { distanceMeters: number; timeSeconds: number } | undefined,
    estimatedPushups: number | undefined,
    estimatedAirSquats: number | undefined,
  ): internalScore.EffortInput[] {
    const efforts: internalScore.EffortInput[] = [];
    if (course) {
      // Course à distance libre : normalisée via Riegel côté score-service.
      efforts.push({
        wodId: "run_free_distance",
        rawResult: course.timeSeconds,
        distanceMeters: course.distanceMeters,
        ageWeeks: 0,
      });
    }
    if (estimatedPushups !== undefined) {
      efforts.push({ wodId: "max_pushups", rawResult: estimatedPushups, ageWeeks: 0 });
    }
    if (estimatedAirSquats !== undefined) {
      efforts.push({ wodId: "max_air_squats", rawResult: estimatedAirSquats, ageWeeks: 0 });
    }
    return efforts;
  }
}
