import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

/** Métadonnées app (mise à jour forcée) : défauts inoffensifs sans env, pilotage par env. */
describe("api — GET /v1/meta/app (e2e)", () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    delete process.env.APP_MIN_BUILD;
    await app?.close();
  });

  it("sans APP_MIN_BUILD → minBuild 0 (aucun client jamais bloqué par défaut)", async () => {
    delete process.env.APP_MIN_BUILD;
    const res = await request(app.getHttpServer()).get("/v1/meta/app").expect(200);
    expect(res.body.minBuild).toBe(0);
    expect(typeof res.body.storeUrl).toBe("string");
  });

  it("APP_MIN_BUILD=42 → publié tel quel (sans redéploiement mobile)", async () => {
    process.env.APP_MIN_BUILD = "42";
    const res = await request(app.getHttpServer()).get("/v1/meta/app").expect(200);
    expect(res.body.minBuild).toBe(42);
  });
});
