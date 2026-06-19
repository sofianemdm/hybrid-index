import type { INestApplication } from "@nestjs/common";
import { HttpExceptionFilter } from "./common/http-exception.filter";

/** Configuration partagée par le bootstrap (main.ts) et les tests e2e. */
export function configureApp(app: INestApplication): INestApplication {
  app.useGlobalFilters(new HttpExceptionFilter());
  return app;
}
