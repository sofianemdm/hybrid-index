import { Body, Controller, Get, Post } from "@nestjs/common";
import { internalScore } from "@hybrid-index/contracts";
import { ZodValidationPipe } from "../common/zod-validation.pipe";
import { ScoringVersionService } from "./scoring-version.service";
import { ScoringService } from "./scoring.service";

/**
 * Contrat INTERNE versionné (api -> score-service), préfixe /v1/score.
 * Le score-service n'est jamais exposé publiquement (cf. docker-compose).
 */
@Controller("v1/score")
export class ScoreController {
  constructor(
    private readonly versions: ScoringVersionService,
    private readonly scoring: ScoringService,
  ) {}

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

  @Post("sub-score")
  subScore(
    @Body(new ZodValidationPipe(internalScore.ComputeSubScoreRequest))
    body: internalScore.ComputeSubScoreRequest,
  ): internalScore.ComputeSubScoreResponse {
    return this.scoring.computeSubScore(body);
  }

  @Post("index")
  index(
    @Body(new ZodValidationPipe(internalScore.ComputeIndexRequest))
    body: internalScore.ComputeIndexRequest,
  ): internalScore.ComputeIndexResponse {
    return this.scoring.computeIndex(body);
  }
}
