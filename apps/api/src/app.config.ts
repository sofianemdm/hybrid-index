import { Logger, type INestApplication } from "@nestjs/common";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { WsAdapter } from "@nestjs/platform-ws";
import helmet from "helmet";
import { HttpExceptionFilter } from "./common/http-exception.filter";

/** Configuration partagée par le bootstrap (main.ts) et les tests e2e. */
export function configureApp(app: INestApplication): INestApplication {
  // Transport WebSocket temps réel (raw `ws`, même port que l'API, chemin `/ws/messaging`).
  // Indispensable AVANT `init()` : sans adaptateur, le SocketModule de Nest tente de charger
  // socket.io (absent) et fait échouer le boot. Best-effort : un échec d'installation ne doit
  // JAMAIS empêcher le démarrage REST.
  try {
    app.useWebSocketAdapter(new WsAdapter(app));
  } catch (err) {
    Logger.warn(`Adaptateur WebSocket non installé (REST reste opérationnel) : ${(err as Error).message}`, "Bootstrap");
  }
  app.useGlobalFilters(new HttpExceptionFilter());
  // Headers de sécurité (HSTS, X-Content-Type-Options, X-Frame-Options, etc.). API JSON pure :
  // les défauts de helmet conviennent (la CSP ne concerne que des réponses HTML, inoffensive ici).
  app.use(helmet());
  // Photo d'avatar (data URL base64) → relever la limite du body parser (défaut Express 100 kb).
  (app as NestExpressApplication).useBodyParser("json", { limit: "800kb" });
  // CORS : nécessaire pour l'app Flutter Web (navigateur). `*` en dev ; restreindre en prod.
  const configured = process.env.CORS_ORIGINS;
  if (!configured && process.env.NODE_ENV === "production") {
    throw new Error("CORS_ORIGINS est obligatoire en production (ne pas exposer * par défaut).");
  }
  const origins = configured ?? "*";
  app.enableCors({
    origin: origins === "*" ? true : origins.split(",").map((o) => o.trim()),
    methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  });
  return app;
}
