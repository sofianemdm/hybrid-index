import { PushService } from "../src/modules/engagement/push.service";
import type { PrismaService } from "../src/infra/prisma/prisma.service";
import {
  isTransactionalNotification,
  TRANSACTIONAL_NOTIFICATION_TYPES,
} from "../src/modules/engagement/notifications.data";

/**
 * Incrément 2 — la notification TRANSACTIONNELLE `new-message` CONTOURNE le gating de confort
 * (quietHours + dailyCap + cooldown) tout en RESPECTANT l'opt-out utilisateur. Polish : le push
 * porte `conversationId` (+ senderId) dans `data` pour le deep-link.
 *
 * On force le push ACTIF (FCM_SERVICE_ACCOUNT) pour traverser réellement `gate()`, et on intercepte
 * l'appel réseau FCM (`sendToToken`) pour capturer le payload sans toucher le réseau.
 */

const ENV_KEY = "FCM_SERVICE_ACCOUNT";
const SA = '{"project_id":"x","client_email":"y","private_key":"z"}';

/** Heure DANS la fenêtre de silence par défaut (22:00→07:00) : 23h00. */
const QUIET_NOW = new Date("2026-06-30T23:00:00");

interface SentToken {
  token: string;
  msg: { title: string; body: string; data?: Record<string, string> };
}

/**
 * Construit un PushService actif avec un Prisma simulé paramétrable + capture des envois FCM.
 * `prefs`/`quietHours`/`dailyCap` pilotent le gating ; `countToday` simule le plafond journalier ;
 * `lastSentAt` simule un cooldown récent.
 */
function buildPush(opts: {
  prefs?: Record<string, boolean>;
  quietHours?: { start: string; end: string };
  dailyCap?: number;
  countToday?: number;
  lastSentAt?: Date | null;
  locale?: string;
}) {
  const sent: SentToken[] = [];
  const prisma = {
    notificationPrefs: {
      findUnique: jest.fn(async () => ({
        prefs: opts.prefs ?? {},
        quietHours: opts.quietHours ?? null,
        dailyCap: opts.dailyCap ?? 2,
      })),
    },
    notificationLog: {
      count: jest.fn(async () => opts.countToday ?? 0),
      findFirst: jest.fn(async () => (opts.lastSentAt ? { sentAt: opts.lastSentAt } : null)),
      create: jest.fn(async () => undefined),
    },
    pushToken: { findMany: jest.fn(async () => [{ token: "tok-1" }]) },
    profile: { findUnique: jest.fn(async () => ({ locale: opts.locale ?? "fr" })) },
  } as unknown as PrismaService;
  const svc = new PushService(prisma);
  // Intercepte l'appel réseau FCM : on capture le message au lieu d'émettre.
  (svc as unknown as { sendToToken: (token: string, msg: SentToken["msg"]) => Promise<void> }).sendToToken =
    async (token, msg) => {
      sent.push({ token, msg });
    };
  return { svc, sent, prisma };
}

/** Accès direct au gating privé (now injectable) pour des assertions fines. */
function gate(svc: PushService, userId: string, type: string | undefined, now: Date): Promise<string | null> {
  return (svc as unknown as { gate(u: string, t: string | undefined, n: Date): Promise<string | null> }).gate(
    userId,
    type,
    now,
  );
}

describe("Incrément 2 — `new-message` est TRANSACTIONNEL (catalogue)", () => {
  it("`new-message` est marqué transactionnel ; les nudges ne le sont pas", () => {
    expect(isTransactionalNotification("new-message")).toBe(true);
    expect(TRANSACTIONAL_NOTIFICATION_TYPES.has("new-message")).toBe(true);
    expect(isTransactionalNotification("rank-overtaken")).toBe(false);
    expect(isTransactionalNotification("weekly-recap")).toBe(false);
    expect(isTransactionalNotification(undefined)).toBe(false);
  });
});

describe("Incrément 2 — `gate()` exempte le transactionnel mais garde l'opt-out", () => {
  const original = process.env[ENV_KEY];
  beforeAll(() => {
    process.env[ENV_KEY] = SA;
  });
  afterAll(() => {
    if (original === undefined) delete process.env[ENV_KEY];
    else process.env[ENV_KEY] = original;
  });

  it("PASSE malgré quietHours (nuit) pour `new-message`", async () => {
    const { svc } = buildPush({ quietHours: { start: "22:00", end: "07:00" } });
    expect(await gate(svc, "u1", "new-message", QUIET_NOW)).toBeNull();
  });

  it("PASSE malgré dailyCap atteint (countToday >= cap) pour `new-message`", async () => {
    const { svc } = buildPush({ dailyCap: 2, countToday: 5 });
    expect(await gate(svc, "u1", "new-message", new Date("2026-06-30T12:00:00"))).toBeNull();
  });

  it("PASSE malgré un envoi très récent (cooldown) pour `new-message`", async () => {
    const now = new Date("2026-06-30T12:00:00");
    const { svc } = buildPush({ lastSentAt: new Date(now.getTime() - 1000) }); // il y a 1 s
    expect(await gate(svc, "u1", "new-message", now)).toBeNull();
  });

  it("RESPECTE l'opt-out : si l'utilisateur a coupé `new-message`, BLOQUÉ (opt-out)", async () => {
    const { svc } = buildPush({ prefs: { "new-message": false } });
    expect(await gate(svc, "u1", "new-message", new Date("2026-06-30T12:00:00"))).toBe("opt-out");
  });

  it("CONTRÔLE : un nudge non transactionnel reste gaté par quietHours", async () => {
    const { svc } = buildPush({ quietHours: { start: "22:00", end: "07:00" } });
    expect(await gate(svc, "u1", "rank-overtaken", QUIET_NOW)).toBe("quiet-hours");
  });

  it("CONTRÔLE : un nudge non transactionnel reste gaté par dailyCap", async () => {
    const { svc } = buildPush({ dailyCap: 2, countToday: 2 });
    expect(await gate(svc, "u1", "rank-overtaken", new Date("2026-06-30T12:00:00"))).toBe("daily-cap");
  });
});

describe("Incrément 2 + Polish — `notifyNewMessage` envoie de bout en bout (nuit) + deep-link", () => {
  const original = process.env[ENV_KEY];
  beforeAll(() => {
    process.env[ENV_KEY] = SA;
  });
  afterAll(() => {
    if (original === undefined) delete process.env[ENV_KEY];
    else process.env[ENV_KEY] = original;
  });

  it("la nuit + au-delà du dailyCap, le push DM PART quand même, data porte conversationId/senderId/senderName/type", async () => {
    // Conditions hostiles : quietHours actives + plafond journalier déjà dépassé.
    const { svc, sent } = buildPush({
      quietHours: { start: "22:00", end: "07:00" },
      dailyCap: 2,
      countToday: 9,
    });
    await svc.notifyNewMessage("u-dest", "Alex", "conv-77", "u-sender");
    expect(sent).toHaveLength(1);
    expect(sent[0].msg.data).toEqual({
      type: "new-message",
      conversationId: "conv-77",
      senderId: "u-sender",
      senderName: "Alex",
    });
    // `type` n'est jamais écrasé par les champs de deep-link.
    expect(sent[0].msg.data?.type).toBe("new-message");
    expect(sent[0].msg.title).toBe("Message de Alex"); // copie FR interpolée
  });

  it("si l'utilisateur a coupé les notifs de message, RIEN n'est envoyé (opt-out respecté)", async () => {
    const { svc, sent } = buildPush({ prefs: { "new-message": false } });
    await svc.notifyNewMessage("u-dest", "Alex", "conv-77", "u-sender");
    expect(sent).toHaveLength(0);
  });
});
