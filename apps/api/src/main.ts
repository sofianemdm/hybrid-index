import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { Logger } from "@nestjs/common";
import { AppModule } from "./app.module";
import { configureApp } from "./app.config";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: false });
  configureApp(app);
  app.enableShutdownHooks();
  // PaaS (Railway/Render…) injectent PORT ; on le privilégie, puis API_PORT, puis 3000.
  // Bind 0.0.0.0 pour être joignable depuis l'extérieur du conteneur.
  const port = Number(process.env.PORT ?? process.env.API_PORT ?? 3000);
  await app.listen(port, "0.0.0.0");
  Logger.log(`api en écoute sur le port ${port}`, "Bootstrap");
}

void bootstrap();
