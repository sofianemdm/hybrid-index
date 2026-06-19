import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request from "supertest";
import { AppModule } from "../src/app.module";

describe("score-service (e2e)", () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it("GET /v1/score/health → ok + version active", async () => {
    const res = await request(app.getHttpServer()).get("/v1/score/health").expect(200);
    expect(res.body).toEqual({
      service: "score-service",
      status: "ok",
      activeScoringVersion: "scoring-v1",
    });
  });

  it("GET /v1/score/version → métadonnées de la version active", async () => {
    const res = await request(app.getHttpServer()).get("/v1/score/version").expect(200);
    expect(res.body.id).toBe("scoring-v1");
    expect(res.body.status).toBe("active");
    expect(res.body.curve).toBe("sigmoid-v1");
  });
});
