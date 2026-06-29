import { WeeklyEngagementService } from "../src/modules/engagement/weekly-engagement.service";
import type { PrismaService } from "../src/infra/prisma/prisma.service";
import type { EngagementService, WeeklyRecap } from "../src/modules/engagement/engagement.service";
import type { PushService } from "../src/modules/engagement/push.service";

function recap(over: Partial<WeeklyRecap> = {}): WeeklyRecap {
  return {
    weekStart: "2026-06-22T00:00:00.000Z",
    sessions: 3,
    indexNow: 70,
    deltaIndex: 4,
    streakCurrent: 2,
    weekValidated: true,
    ...over,
  };
}

describe("WeeklyEngagementService — cron hebdo de ré-engagement", () => {
  it("runOnce : envoie récap + attribut stagnant à chaque athlète actif (push inactif ⇒ no-op propre)", async () => {
    const prisma = {
      hybridIndex: { findMany: jest.fn().mockResolvedValue([{ userId: "u1" }, { userId: "u2" }]) },
      attributeScore: {
        findFirst: jest
          .fn()
          // u1 a un attribut stagnant, u2 non.
          .mockResolvedValueOnce({ attribute: "strength" })
          .mockResolvedValueOnce(null),
      },
      // u1 est anglophone → le libellé d'attribut doit être en EN ("strength"), pas "force".
      profile: { findUnique: jest.fn().mockResolvedValue({ locale: "en" }) },
    } as unknown as PrismaService;

    const engagement = {
      weeklyRecap: jest.fn().mockResolvedValue(recap()),
    } as unknown as EngagementService;

    // PushService réel-like mais désactivé : on vérifie juste qu'il est appelé sans lever.
    const push = {
      notifyWeeklyRecap: jest.fn().mockResolvedValue(undefined),
      notifyStaleAttribute: jest.fn().mockResolvedValue(undefined),
    } as unknown as PushService;

    const svc = new WeeklyEngagementService(prisma, engagement, push);
    const res = await svc.runOnce();

    expect(res).toEqual({ processed: 2 });
    expect(push.notifyWeeklyRecap).toHaveBeenCalledTimes(2);
    expect(push.notifyWeeklyRecap).toHaveBeenCalledWith("u1", 4, 3);
    // Seul u1 a un attribut stagnant ; libellé localisé EN (u1 est anglophone).
    expect(push.notifyStaleAttribute).toHaveBeenCalledTimes(1);
    expect(push.notifyStaleAttribute).toHaveBeenCalledWith("u1", "strength");
  });

  it("runOnce : pas de récap « vide » (0 séance ET +0 pt) — on n'envoie rien d'inutile", async () => {
    const prisma = {
      hybridIndex: { findMany: jest.fn().mockResolvedValue([{ userId: "u1" }]) },
      attributeScore: { findFirst: jest.fn().mockResolvedValue(null) },
    } as unknown as PrismaService;
    const engagement = {
      weeklyRecap: jest.fn().mockResolvedValue(recap({ sessions: 0, deltaIndex: 0 })),
    } as unknown as EngagementService;
    const push = {
      notifyWeeklyRecap: jest.fn().mockResolvedValue(undefined),
      notifyStaleAttribute: jest.fn().mockResolvedValue(undefined),
    } as unknown as PushService;

    const svc = new WeeklyEngagementService(prisma, engagement, push);
    const res = await svc.runOnce();

    expect(res).toEqual({ processed: 1 });
    expect(push.notifyWeeklyRecap).not.toHaveBeenCalled();
  });

  it("runOnce : un échec sur un user n'arrête pas la boucle (isolation best-effort)", async () => {
    const prisma = {
      hybridIndex: { findMany: jest.fn().mockResolvedValue([{ userId: "boom" }, { userId: "ok" }]) },
      attributeScore: { findFirst: jest.fn().mockResolvedValue(null) },
    } as unknown as PrismaService;
    const engagement = {
      weeklyRecap: jest
        .fn()
        .mockRejectedValueOnce(new Error("recap KO"))
        .mockResolvedValueOnce(recap()),
    } as unknown as EngagementService;
    const push = {
      notifyWeeklyRecap: jest.fn().mockResolvedValue(undefined),
      notifyStaleAttribute: jest.fn().mockResolvedValue(undefined),
    } as unknown as PushService;

    const svc = new WeeklyEngagementService(prisma, engagement, push);
    const res = await svc.runOnce();

    // « boom » échoue (non compté), « ok » passe.
    expect(res).toEqual({ processed: 1 });
    expect(push.notifyWeeklyRecap).toHaveBeenCalledWith("ok", 4, 3);
  });
});
