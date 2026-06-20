import { HttpException, Inject, Injectable, ServiceUnavailableException } from "@nestjs/common";
import { internalScore } from "@hybrid-index/contracts";
import type { ZodSchema } from "zod";

export const SCORE_SERVICE_URL = Symbol("SCORE_SERVICE_URL");

/**
 * Client HTTP de l'`api` vers le microservice Score (contrat interne /v1/score/*).
 * L'app mobile ne connaît JAMAIS le score-service : seul l'`api` l'appelle (frontière §1.2).
 * La réponse est revalidée contre le schéma du contrat (défense de la frontière interne).
 */
@Injectable()
export class ScoreClient {
  constructor(@Inject(SCORE_SERVICE_URL) private readonly baseUrl: string) {}

  computeProfile(req: internalScore.ComputeProfileRequest): Promise<internalScore.ComputeProfileResponse> {
    return this.post("/v1/score/profile", req, internalScore.ComputeProfileResponse);
  }

  computeSubScore(req: internalScore.ComputeSubScoreRequest): Promise<internalScore.ComputeSubScoreResponse> {
    return this.post("/v1/score/sub-score", req, internalScore.ComputeSubScoreResponse);
  }

  computeIndex(req: internalScore.ComputeIndexRequest): Promise<internalScore.ComputeIndexResponse> {
    return this.post("/v1/score/index", req, internalScore.ComputeIndexResponse);
  }

  computeProjection(req: internalScore.ComputeProjectionRequest): Promise<internalScore.ComputeProjectionResponse> {
    return this.post("/v1/score/project", req, internalScore.ComputeProjectionResponse);
  }

  computeGrandSlam(req: internalScore.ComputeGrandSlamRequest): Promise<internalScore.ComputeGrandSlamResponse> {
    return this.post("/v1/score/grand-slam", req, internalScore.ComputeGrandSlamResponse);
  }

  getWodLevels(wodId: string): Promise<internalScore.WodLevelsResponse> {
    return this.get(`/v1/score/wods/${encodeURIComponent(wodId)}/levels`, internalScore.WodLevelsResponse);
  }

  private async get<T>(path: string, schema: ZodSchema<T>): Promise<T> {
    let res: Response;
    try {
      res = await fetch(`${this.baseUrl}${path}`, { method: "GET", headers: { "content-type": "application/json" } });
    } catch {
      throw new ServiceUnavailableException({ code: "SCORE_SERVICE_UNAVAILABLE", message: "Le service de score est indisponible." });
    }
    if (!res.ok) {
      const payload = (await res.json().catch(() => undefined)) as { error?: unknown } | undefined;
      if (res.status >= 400 && res.status < 500) {
        throw new HttpException(payload?.error ?? { code: "VALIDATION_ERROR", message: "Requête invalide" }, res.status);
      }
      throw new ServiceUnavailableException({ code: "SCORE_SERVICE_UNAVAILABLE", message: "Le service de score a renvoyé une erreur." });
    }
    const parsed = schema.safeParse(await res.json());
    if (!parsed.success) {
      throw new ServiceUnavailableException({ code: "SCORE_SERVICE_UNAVAILABLE", message: "Réponse du service de score non conforme." });
    }
    return parsed.data;
  }

  private async post<T>(path: string, body: unknown, schema: ZodSchema<T>): Promise<T> {
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

    const parsed = schema.safeParse(await res.json());
    if (!parsed.success) {
      // Le score-service a renvoyé un corps non conforme au contrat → on ne propage pas de donnée corrompue.
      throw new ServiceUnavailableException({
        code: "SCORE_SERVICE_UNAVAILABLE",
        message: "Réponse du service de score non conforme au contrat.",
      });
    }
    return parsed.data;
  }
}
