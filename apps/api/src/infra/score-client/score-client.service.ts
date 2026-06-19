import { HttpException, Inject, Injectable, ServiceUnavailableException } from "@nestjs/common";
import type { internalScore } from "@hybrid-index/contracts";

export const SCORE_SERVICE_URL = Symbol("SCORE_SERVICE_URL");

/**
 * Client HTTP de l'`api` vers le microservice Score (contrat interne /v1/score/*).
 * L'app mobile ne connaît JAMAIS le score-service : seul l'`api` l'appelle (frontière §1.2).
 */
@Injectable()
export class ScoreClient {
  constructor(@Inject(SCORE_SERVICE_URL) private readonly baseUrl: string) {}

  computeProfile(req: internalScore.ComputeProfileRequest): Promise<internalScore.ComputeProfileResponse> {
    return this.post("/v1/score/profile", req);
  }

  computeSubScore(req: internalScore.ComputeSubScoreRequest): Promise<internalScore.ComputeSubScoreResponse> {
    return this.post("/v1/score/sub-score", req);
  }

  computeIndex(req: internalScore.ComputeIndexRequest): Promise<internalScore.ComputeIndexResponse> {
    return this.post("/v1/score/index", req);
  }

  private async post<T>(path: string, body: unknown): Promise<T> {
    let res: Response;
    try {
      res = await fetch(`${this.baseUrl}${path}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch {
      // score-service injoignable → §4.1 : 503, résultat stocké, score en attente.
      throw new ServiceUnavailableException({
        code: "SCORE_SERVICE_UNAVAILABLE",
        message: "Le service de score est indisponible.",
      });
    }

    if (!res.ok) {
      const payload = (await res.json().catch(() => undefined)) as { error?: unknown } | undefined;
      // Propage les erreurs client (4xx, ex. bornes physio) ; sinon 503.
      if (res.status >= 400 && res.status < 500) {
        throw new HttpException(payload?.error ?? { code: "VALIDATION_ERROR", message: "Requête invalide" }, res.status);
      }
      throw new ServiceUnavailableException({
        code: "SCORE_SERVICE_UNAVAILABLE",
        message: "Le service de score a renvoyé une erreur.",
      });
    }

    return (await res.json()) as T;
  }
}
