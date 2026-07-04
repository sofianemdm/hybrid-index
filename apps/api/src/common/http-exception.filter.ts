import { type ArgumentsHost, Catch, type ExceptionFilter, HttpException, HttpStatus, Logger } from "@nestjs/common";
import type { ErrorCode } from "@hybrid-index/contracts";

/** Type structurel minimal de la réponse HTTP (évite la dépendance aux types express). */
interface HttpResponse {
  status(code: number): HttpResponse;
  json(body: unknown): unknown;
  setHeader(name: string, value: string): unknown;
}

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

/** Enveloppe standard `{ error: { code, message, details, traceId } }` (architecture.md §4.1). */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<HttpResponse>();

    // Les exceptions inattendues (non HttpException) deviennent des 500 : on les logge pour ne
    // pas perdre la cause (sinon le client ne voit qu'« Erreur interne »).
    if (!(exception instanceof HttpException)) {
      this.logger.error(
        exception instanceof Error ? exception.stack ?? exception.message : String(exception),
      );
    }

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

    // CRUCIAL (bug 04/07) : garantir `Cross-Origin-Resource-Policy: cross-origin` sur TOUTE réponse
    // d'erreur. Sans lui (défaut helmet = same-origin, ou middleware helmet non appliqué sur le
    // chemin d'exception), le NAVIGATEUR REFUSE que l'app Flutter Web (autre origine) LISE la réponse
    // → XHR `onError` → le client remonte « serveur injoignable » alors que le 404/400 arrive bien.
    // Vécu : un 404 « pas d'Index » (attendu à l'onboarding) bloquait TOUTE création de compte.
    // On le pose ici EN DUR, indépendamment de l'ordre des middlewares (belt & suspenders).
    try {
      res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
    } catch {
      /* certains transports (tests) n'exposent pas setHeader : sans effet, non bloquant */
    }
    res.status(status).json({ error: { code, message, ...(details ? { details } : {}) } });
  }
}
