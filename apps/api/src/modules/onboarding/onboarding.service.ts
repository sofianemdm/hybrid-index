import { BadRequestException, Injectable } from "@nestjs/common";
import { type internalScore, type onboardingDto, rankFromIndex } from "@hybrid-index/contracts";
import { ScoreClient } from "../../infra/score-client/score-client.service";

/**
 * Onboarding — calcule le HYBRID INDEX PROVISOIRE (le « reveal », cahier §8) à partir
 * d'un temps de course et/ou d'une auto-évaluation, SANS créer de compte (calcul pur).
 * Garantit un chiffre pour 100 % des inscrits (écran 5bis) tant qu'au moins une entrée est fournie.
 */
@Injectable()
export class OnboardingService {
  constructor(private readonly scoreClient: ScoreClient) {}

  async estimate(req: onboardingDto.OnboardingEstimateRequest): Promise<onboardingDto.RevealResponse> {
    const efforts: internalScore.EffortInput[] = [];
    if (req.course) {
      efforts.push({ wodId: req.course.wodId, rawResult: req.course.timeSeconds, ageWeeks: 0 });
    }
    if (req.estimatedPushups !== undefined) {
      efforts.push({ wodId: "max_pushups", rawResult: req.estimatedPushups, ageWeeks: 0 });
    }

    if (efforts.length === 0) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: "Fournis au moins un temps de course ou une estimation de pompes.",
      });
    }

    const profile = await this.scoreClient.computeProfile({
      sex: req.sex,
      goal: req.goal,
      efforts,
    });

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
}
