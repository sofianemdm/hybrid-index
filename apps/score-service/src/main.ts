import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { Logger } from "@nestjs/common";
import { AppModule } from "./app.module";
import { configureApp } from "./app.config";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: false });
  configureApp(app);
  // Le score-service n'est PAS exposé publiquement : seul l'`api` l'appelle (contrat /v1/score/*).
  const port = Number(process.env.SCORE_SERVICE_PORT ?? 3001);
  await app.listen(port);
  Logger.log(`score-service en écoute sur le port ${port}`, "Bootstrap");
}

void bootstrap();
