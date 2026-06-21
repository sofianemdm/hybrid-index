import type { INestApplication } from "@nestjs/common";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { HttpExceptionFilter } from "./common/http-exception.filter";

/** Configuration partagée par le bootstrap (main.ts) et les tests e2e. */
export function configureApp(app: INestApplication): INestApplication {
  app.useGlobalFilters(new HttpExceptionFilter());
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
