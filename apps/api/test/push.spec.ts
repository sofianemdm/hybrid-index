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

  it("inactif → TOUS les déclencheurs de ré-engagement sont des no-op silencieux (aucune requête DB)", async () => {
    delete process.env.FCM_SERVICE_ACCOUNT;
    let dbTouched = false;
    const prisma = {
      pushToken: { findMany: async () => { dbTouched = true; return []; } },
      notificationPrefs: { findUnique: async () => { dbTouched = true; return null; } },
      notificationLog: { count: async () => { dbTouched = true; return 0; }, findFirst: async () => { dbTouched = true; return null; } },
    } as unknown as PrismaService;
    const svc = new PushService(prisma);
    // Les 6 déclencheurs câblés à leur source dans cette mission.
    await expect(svc.notifyKudos("u1", 3)).resolves.toBeUndefined();
    await expect(svc.notifyNearRank("u1", 4)).resolves.toBeUndefined();
    await expect(svc.notifyRankOvertaken("u1")).resolves.toBeUndefined();
    await expect(svc.notifyStaleAttribute("u1", "force")).resolves.toBeUndefined();
    await expect(svc.notifyWeeklyRecap("u1", 5, 3)).resolves.toBeUndefined();
    // Push inactif ⇒ no-op PUR : aucune table touchée (pas de gating ni de log inutiles).
    expect(dbTouched).toBe(false);
  });

  it("la copie centralisée interpole les pluriels (near-rank/kudos)", async () => {
    process.env.FCM_SERVICE_ACCOUNT = '{"project_id":"x","client_email":"y","private_key":"z"}';
    const sent: Array<{ title: string; body: string }> = [];
    // On capture le message en interceptant sendToUser (le réseau FCM n'est pas appelé).
    const svc = new PushService(fakePrisma);
    (svc as unknown as { sendToUser: (u: string, m: { title: string; body: string }) => Promise<void> }).sendToUser =
      async (_u, msg) => {
        sent.push(msg);
      };
    await svc.notifyNearRank("u1", 1);
    await svc.notifyNearRank("u1", 3);
    await svc.notifyKudos("u1", 1);
    await svc.notifyKudos("u1", 2);
    expect(sent[0].body).toContain("1 point ");
    expect(sent[1].body).toContain("3 points ");
    expect(sent[2].body).toContain("a salué");
    expect(sent[3].body).toContain("ont salué");
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
