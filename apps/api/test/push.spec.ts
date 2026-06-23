import { PushService } from "../src/modules/engagement/push.service";

describe("PushService — prêt mais inactif", () => {
  const original = process.env.FCM_SERVER_KEY;
  afterEach(() => {
    if (original === undefined) delete process.env.FCM_SERVER_KEY;
    else process.env.FCM_SERVER_KEY = original;
  });

  it("inactif par défaut (pas de clé FCM)", () => {
    delete process.env.FCM_SERVER_KEY;
    expect(new PushService().enabled).toBe(false);
  });

  it("actif si FCM_SERVER_KEY présent", () => {
    process.env.FCM_SERVER_KEY = "test-key";
    expect(new PushService().enabled).toBe(true);
  });

  it("registerToken puis sendToUser ne lève pas quand inactif (no-op)", async () => {
    delete process.env.FCM_SERVER_KEY;
    const svc = new PushService();
    svc.registerToken("u1", "device-token-123");
    await expect(svc.notifyRankOvertaken("u1")).resolves.toBeUndefined();
  });

  it("ignore un token vide", () => {
    const svc = new PushService();
    expect(() => svc.registerToken("u1", "")).not.toThrow();
  });
});
