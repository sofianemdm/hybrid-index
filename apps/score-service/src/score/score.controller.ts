import { Controller, Get } from "@nestjs/common";
import type { internalScore } from "@hybrid-index/contracts";
import { ScoringVersionService } from "./scoring-version.service";

/**
 * Contrat INTERNE versionné (api -> score-service), préfixe /v1/score.
 * Incrément 0 : santé + version active. Les endpoints de calcul (sous-score, index,
 * recompute) arrivent à l'incrément 1.
 */
@Controller("v1/score")
export class ScoreController {
  constructor(private readonly versions: ScoringVersionService) {}

  @Get("health")
  health(): internalScore.ScoreServiceHealth {
    return {
      service: "score-service",
      status: "ok",
      activeScoringVersion: this.versions.getActiveVersionId(),
    };
  }

  @Get("version")
  version(): internalScore.ScoringVersionInfo {
    return this.versions.getActiveVersion();
  }
}
