import type { INestApplication } from "@nestjs/common";
import { HttpExceptionFilter } from "./common/http-exception.filter";

/** Configuration partagée par le bootstrap (main.ts) et les tests e2e. */
export function configureApp(app: INestApplication): INestApplication {
  app.useGlobalFilters(new HttpExceptionFilter());
  // CORS : nécessaire pour l'app Flutter Web (navigateur). `*` en dev ; restreindre en prod.
  const origins = process.env.CORS_ORIGINS ?? "*";
  app.enableCors({
    origin: origins === "*" ? true : origins.split(",").map((o) => o.trim()),
    methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  });
  return app;
}
