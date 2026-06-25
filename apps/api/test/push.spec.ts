import { PushService } from "../src/modules/engagement/push.service";
import type { PrismaService } from "../src/infra/prisma/prisma.service";

// Prisma minimal simulé (le push n'utilise que pushToken.* et profile.findUnique).
const fakePrisma = {
  pushToken: {
    upsert: async () => undefined,
    deleteMany: async () => ({ count: 0 }),
    findMany: async () => [] as Array<{ token: string }>,
  },
} as unknown as PrismaService;

describe("PushService — activation via compte de service", () => {
  const original = process.env.FCM_SERVICE_ACCOUNT;
  afterEach(() => {
    if (original === undefined) delete process.env.FCM_SERVICE_ACCOUNT;
    else process.env.FCM_SERVICE_ACCOUNT = original;
  });

  it("inactif par défaut (pas de compte de service)", () => {
    delete process.env.FCM_SERVICE_ACCOUNT;
    expect(new PushService(fakePrisma).enabled).toBe(false);
  });

  it("actif si FCM_SERVICE_ACCOUNT présent", () => {
    process.env.FCM_SERVICE_ACCOUNT = '{"project_id":"x","client_email":"y","private_key":"z"}';
    expect(new PushService(fakePrisma).enabled).toBe(true);
  });

  it("inactif → sendToUser/notify ne lève pas et n'envoie rien (no-op)", async () => {
    delete process.env.FCM_SERVICE_ACCOUNT;
    const svc = new PushService(fakePrisma);
    await expect(svc.notifyRankOvertaken("u1")).resolves.toBeUndefined();
    await expect(svc.notifyNewMessage("u1", "Alex")).resolves.toBeUndefined();
  });

  it("registerToken ignore un token vide (pas d'écriture)", async () => {
    let called = false;
    const prisma = {
      pushToken: { upsert: async () => { called = true; } },
    } as unknown as PrismaService;
    const svc = new PushService(prisma);
    await svc.registerToken("u1", "");
    expect(called).toBe(false);
  });
});
