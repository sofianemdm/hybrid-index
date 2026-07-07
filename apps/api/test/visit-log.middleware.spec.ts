import "reflect-metadata";
import { JwtService } from "@nestjs/jwt";
import { VisitLogMiddleware } from "../src/common/visit-log.middleware";
import type { PrismaService } from "../src/infra/prisma/prisma.service";

/** Le tracking des visites est STRICTEMENT best-effort : une écriture qui échoue ne doit jamais
 *  bloquer ni faire échouer la requête, et le bruit (health, OPTIONS) est ignoré. Tests unitaires
 *  purs (Prisma mocké) — le chemin réel est couvert par admin.e2e.spec. */
describe("VisitLogMiddleware (unitaire)", () => {
  const jwt = new JwtService({ secret: "test-secret" });

  function build(create: jest.Mock): VisitLogMiddleware {
    const prisma = { visitLog: { create } } as unknown as PrismaService;
    return new VisitLogMiddleware(prisma, jwt);
  }

  const req = (over: Partial<{ method: string; originalUrl: string; headers: Record<string, string> }> = {}) => ({
    method: over.method ?? "GET",
    originalUrl: over.originalUrl ?? "/v1/wods",
    headers: { "x-forwarded-for": "203.0.113.7", "user-agent": "jest", ...(over.headers ?? {}) },
    ip: "127.0.0.1",
  });

  it("journalise une requête API : IP du proxy, chemin sans query, user du Bearer", async () => {
    const create = jest.fn().mockResolvedValue({});
    const mw = build(create);
    const token = jwt.sign({ sub: "11111111-1111-1111-1111-111111111111", email: "a@b.fr" });
    const next = jest.fn();
    mw.use(req({ originalUrl: "/v1/wods?benchmark=true", headers: { authorization: `Bearer ${token}` } }), {}, next);
    expect(next).toHaveBeenCalledTimes(1); // next() appelé SANS attendre l'écriture
    await Promise.resolve();
    expect(create).toHaveBeenCalledTimes(1);
    const data = create.mock.calls[0][0].data;
    expect(data).toMatchObject({ ip: "203.0.113.7", path: "/v1/wods", method: "GET", userAgent: "jest", userId: "11111111-1111-1111-1111-111111111111" });
  });

  it("Bearer invalide → journalisé en anonyme (userId null), sans throw", async () => {
    const create = jest.fn().mockResolvedValue({});
    const mw = build(create);
    const next = jest.fn();
    mw.use(req({ headers: { authorization: "Bearer forged.token.zzz" } }), {}, next);
    await Promise.resolve();
    expect(create.mock.calls[0][0].data.userId).toBeNull();
    expect(next).toHaveBeenCalledTimes(1);
  });

  it("écriture Prisma qui échoue → la requête passe quand même (best-effort)", async () => {
    const create = jest.fn().mockRejectedValue(new Error("db down"));
    const mw = build(create);
    const next = jest.fn();
    expect(() => mw.use(req(), {}, next)).not.toThrow();
    expect(next).toHaveBeenCalledTimes(1);
    await new Promise((r) => setImmediate(r)); // la rejection est avalée (pas d'unhandledRejection)
  });

  it("bruit ignoré : /health, /favicon et OPTIONS ne sont pas journalisés", () => {
    const create = jest.fn();
    const mw = build(create);
    const next = jest.fn();
    mw.use(req({ originalUrl: "/health" }), {}, next);
    mw.use(req({ originalUrl: "/favicon.ico" }), {}, next);
    mw.use(req({ method: "OPTIONS" }), {}, next);
    expect(create).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledTimes(3);
  });
});
