import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { AppModule } from "../src/app.module";
import { configureApp } from "../src/app.config";

describe("api (e2e)", () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    // `configureApp` installe l'adaptateur WebSocket avant `init()` (sinon le gateway temps réel
    // fait charger socket.io, absent → crash). Aligne le test sur le bootstrap réel (main.ts).
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it("GET /health → ok", async () => {
    const res = await request(app.getHttpServer()).get("/health").expect(200);
    expect(res.body).toEqual({ service: "api", status: "ok" });
  });
});
