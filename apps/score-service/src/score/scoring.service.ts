import { BadRequestException, Injectable, UnprocessableEntityException } from "@nestjs/common";
import type { internalScore } from "@hybrid-index/contracts";
import {
  type AttributeResult,
  hybridIndex,
  percentile as percentileOf,
  subScoreFromPercentile,
} from "@hybrid-index/scoring-core";
import { WodsService } from "../wods/wods.service";
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
    const ref = wod.bySex[req.sex];

    if (wod.scoreType !== req.scoreType) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: `scoreType '${req.scoreType}' incompatible avec le WOD ${wod.id} ('${wod.scoreType}')`,
        details: { field: "scoreType", expected: wod.scoreType },
      });
    }

    // Anti-triche §5.5 : hors bornes physiologiques ⇒ refusé (exclu des classements).
    // NB : la détection d'ANOMALIE (saut > +30 % en 7 j → WOD_RESULT_ANOMALY) est STATEFULL
    // (inter-efforts) et relève de l'`api` (historique en base), pas du score-service pur.
    if (req.rawResult < ref.hardMin || req.rawResult > ref.hardMax) {
      throw new UnprocessableEntityException({
        code: "WOD_RESULT_OUT_OF_BOUNDS",
        message: `Résultat ${req.rawResult} hors bornes plausibles [${ref.hardMin}, ${ref.hardMax}] pour ${wod.id}/${req.sex}`,
        details: { field: "rawResult", min: ref.hardMin, max: ref.hardMax },
      });
    }

    const p = percentileOf(req.rawResult, ref.model);
    return {
      subScore: subScoreFromPercentile(p),
      percentile: p,
      attributesAffected: wod.targetAttributes.map((t) => t.attribute),
      scoringVersionId: this.versions.getActiveVersionId(),
    };
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
    const result = hybridIndex(radar, req.goal, req.attributeScores.length);
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
