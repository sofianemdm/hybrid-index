import { type ArgumentsHost, Catch, type ExceptionFilter, HttpException, HttpStatus } from "@nestjs/common";
import type { ErrorCode } from "@hybrid-index/contracts";

/** Type structurel minimal de la réponse HTTP (évite la dépendance aux types express). */
interface HttpResponse {
  status(code: number): HttpResponse;
  json(body: unknown): unknown;
}

/** Mappe un code HTTP vers un code d'erreur métier par défaut (cf. architecture.md §4.1). */
const STATUS_TO_CODE: Record<number, ErrorCode> = {
  400: "VALIDATION_ERROR",
  401: "UNAUTHENTICATED",
  403: "FORBIDDEN",
  404: "NOT_FOUND",
  409: "CONFLICT",
  422: "WOD_RESULT_OUT_OF_BOUNDS",
  429: "RATE_LIMITED",
  503: "SCORE_SERVICE_UNAVAILABLE",
};

/**
 * Formate toutes les exceptions en enveloppe standard `{ error: { code, message, details, traceId } }`.
 * Pattern partagé : l'`api` réutilisera la même forme côté public.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<HttpResponse>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code: ErrorCode = "INTERNAL";
    let message = "Erreur interne";
    let details: Record<string, unknown> | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      code = STATUS_TO_CODE[status] ?? "INTERNAL";
      const body = exception.getResponse();
      if (typeof body === "string") {
        message = body;
      } else if (body && typeof body === "object") {
        const o = body as Record<string, unknown>;
        if (typeof o.code === "string") code = o.code as ErrorCode;
        if (typeof o.message === "string") message = o.message;
        else if (Array.isArray(o.message)) message = o.message.join(", ");
        if (o.details && typeof o.details === "object") details = o.details as Record<string, unknown>;
      }
    }

    res.status(status).json({ error: { code, message, ...(details ? { details } : {}) } });
  }
}
