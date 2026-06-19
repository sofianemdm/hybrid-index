import { BadRequestException, Injectable, UnprocessableEntityException } from "@nestjs/common";
import { ATTRIBUTE_KEYS, type internalScore } from "@hybrid-index/contracts";
import {
  type AttributeResult,
  type ScoredEffort,
  computeRadar,
  hybridIndex,
  percentile as percentileOf,
  subScoreFromPercentile,
} from "@hybrid-index/scoring-core";
import { WodsService } from "../wods/wods.service";
import type { WodDefinition } from "../wods/wod.types";
import { ScoringVersionService } from "./scoring-version.service";

/**
 * Service de calcul du score, adossé à la logique pure `@hybrid-index/scoring-core`.
 * Toute formule vit dans scoring-core ; ici on orchestre (registre WOD, bornes, version).
 */
@Injectable()
export class ScoringService {
  constructor(
    private readonly wods: WodsService,
    private readonly versions: ScoringVersionService,
  ) {}

  /** Sous-score d'un effort sur un WOD de référence (R brut → percentile → courbe f). */
  computeSubScore(req: internalScore.ComputeSubScoreRequest): internalScore.ComputeSubScoreResponse {
    const wod = this.wods.getOrThrow(req.wodId);

    if (wod.scoreType !== req.scoreType) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: `scoreType '${req.scoreType}' incompatible avec le WOD ${wod.id} ('${wod.scoreType}')`,
        details: { field: "scoreType", expected: wod.scoreType },
      });
    }

    const { subScore, percentile } = this.scoreEffort(wod, req.sex, req.rawResult);
    return {
      subScore,
      percentile,
      attributesAffected: wod.targetAttributes.map((t) => t.attribute),
      scoringVersionId: this.versions.getActiveVersionId(),
    };
  }

  /** Calcule un sous-score + percentile pour un WOD/sexe/résultat, avec contrôle des bornes (§5.5). */
  private scoreEffort(wod: WodDefinition, sex: internalScore.ComputeSubScoreRequest["sex"], rawResult: number) {
    const ref = wod.bySex[sex];
    // Anti-triche §5.5 : hors bornes physiologiques ⇒ refusé (exclu des classements).
    // NB : la détection d'ANOMALIE (saut > +30 % en 7 j → WOD_RESULT_ANOMALY) est STATEFULL
    // (inter-efforts) et relève de l'`api` (historique en base), pas du score-service pur.
    if (rawResult < ref.hardMin || rawResult > ref.hardMax) {
      throw new UnprocessableEntityException({
        code: "WOD_RESULT_OUT_OF_BOUNDS",
        message: `Résultat ${rawResult} hors bornes plausibles [${ref.hardMin}, ${ref.hardMax}] pour ${wod.id}/${sex}`,
        details: { field: "rawResult", min: ref.hardMin, max: ref.hardMax },
      });
    }
    const p = percentileOf(rawResult, ref.model);
    return { subScore: subScoreFromPercentile(p), percentile: p };
  }

  /**
   * Agrège l'Index à partir de scores d'attributs déjà calculés (cf. contrat interne).
   * NB : `req.sex` est reçu mais pas encore utilisé — la distribution d'Index est sex-agnostique
   * au démarrage (N(450,140), §6.4) ; le champ est conservé pour le futur percentile par sexe.
   */
  computeIndex(req: internalScore.ComputeIndexRequest): internalScore.ComputeIndexResponse {
    const radar: AttributeResult[] = req.attributeScores.map((a) => ({
      attribute: a.attribute,
      score: a.score,
      unlocked: true,
      isEstimated: a.isEstimated,
      isStale: false,
      bestAgeWeeks: null,
    }));
    return this.toIndexResponse(hybridIndex(radar, req.goal, req.attributeScores.length));
  }

  /**
   * Profil complet : à partir d'une liste d'efforts BRUTS, calcule chaque sous-score, agrège le
   * radar (no-drop D3, proxy Force D2) et l'Index pondéré. Utilisé par l'onboarding (reveal) et,
   * plus tard, par le re-calcul après chaque WOD logué.
   */
  computeProfile(req: internalScore.ComputeProfileRequest): internalScore.ComputeProfileResponse {
    const efforts: ScoredEffort[] = req.efforts.map((e) => {
      const wod = this.wods.getOrThrow(e.wodId);
      const { subScore } = this.scoreEffort(wod, req.sex, e.rawResult);
      return {
        subScore,
        ageWeeks: e.ageWeeks,
        tags: wod.targetAttributes.map((t) => ({ attribute: t.attribute, estimated: t.estimated })),
      };
    });

    const radar = computeRadar(ATTRIBUTE_KEYS, efforts);
    const index = this.toIndexResponse(hybridIndex(radar, req.goal, req.efforts.length));
    return {
      index,
      radar: radar.map((a) => ({
        attribute: a.attribute,
        score: a.score,
        unlocked: a.unlocked,
        isEstimated: a.isEstimated,
        isStale: a.isStale,
      })),
    };
  }

  private toIndexResponse(result: {
    value: number;
    percentile: number;
    isProvisional: boolean;
    isEstimated: boolean;
    radarCoverage: number;
  }): internalScore.ComputeIndexResponse {
    return {
      value: result.value,
      percentile: result.percentile,
      isProvisional: result.isProvisional,
      isEstimated: result.isEstimated,
      radarCoverage: result.radarCoverage,
      scoringVersionId: this.versions.getActiveVersionId(),
    };
  }
}
