import { MessagingService } from "../src/modules/messaging/messaging.service";
import type { RealtimeEvent } from "../src/modules/realtime/realtime.service";
import type { RealtimeService } from "../src/modules/realtime/realtime.service";

/**
 * Incrément 1 — la trame WS `dm` transporte le MESSAGE COMPLET (plus de round-trip REST).
 *
 * On vérifie que `send()` émet, vers le DESTINATAIRE ET l'EXPÉDITEUR (multi-device), un event
 * `{type:'dm', conversationId, message:{…}}` dont `message` a la MÊME forme que la réponse REST de
 * `messages()` (id, senderId, body, createdAt, sentAt, readAt, isMine), avec `isMine` calculé PAR
 * destinataire (false côté destinataire, true côté expéditeur). Mocks ciblés (pas de Postgres).
 */

const ME = "user-me";
const OTHER = "user-other";
const CONV = "conv-42";
const MSG_ID = "msg-1";
const NOW = new Date("2026-06-30T12:00:00.000Z");

function fakeRealtime() {
  const emitted: Array<{ userId: string; event: RealtimeEvent }> = [];
  return {
    emitted,
    emitToUser: (userId: string, event: RealtimeEvent) => emitted.push({ userId, event }),
  } as unknown as RealtimeService & { emitted: typeof emitted };
}

function buildService() {
  const realtime = fakeRealtime();
  const pushCalls: Array<{ userId: string; senderName: string; conversationId?: string; senderId?: string }> = [];
  const prisma = {
    user: {
      // assertCanDm → eligibility : me + other actifs, même tranche d'âge.
      findUnique: jest.fn().mockResolvedValue({ dateOfBirth: new Date("1990-01-01") }),
      findFirst: jest.fn().mockResolvedValue({ dateOfBirth: new Date("1990-01-01") }),
    },
    conversation: { upsert: jest.fn().mockResolvedValue({ id: CONV }) },
    message: { create: jest.fn().mockResolvedValue({ id: MSG_ID, senderId: ME, body: "Salut !", createdAt: NOW }) },
    profile: { findUnique: jest.fn().mockResolvedValue({ displayName: "MoiMême" }) },
  } as unknown as ConstructorParameters<typeof MessagingService>[0];
  const moderation = { isBlockedBetween: jest.fn().mockResolvedValue(false) } as unknown as ConstructorParameters<typeof MessagingService>[1];
  const push = {
    notifyNewMessage: jest.fn(async (userId: string, senderName: string, conversationId?: string, senderId?: string) => {
      pushCalls.push({ userId, senderName, conversationId, senderId });
    }),
  } as unknown as ConstructorParameters<typeof MessagingService>[2];
  const svc = new MessagingService(prisma, moderation, push, realtime);
  return { svc, realtime, pushCalls };
}

describe("Incrément 1 — `send()` émet le MESSAGE COMPLET dans la trame WS `dm`", () => {
  it("émet `dm` au DESTINATAIRE et à l'EXPÉDITEUR, message complet, `isMine` par destinataire", async () => {
    const { svc, realtime } = buildService();
    await svc.send(ME, OTHER, "Salut !");

    // Une trame par participant (destinataire d'abord, puis expéditeur multi-device).
    expect(realtime.emitted).toHaveLength(2);
    const toOther = realtime.emitted.find((e) => e.userId === OTHER)!;
    const toMe = realtime.emitted.find((e) => e.userId === ME)!;
    expect(toOther).toBeDefined();
    expect(toMe).toBeDefined();

    // Forme commune (MÊME contrat que la réponse REST de messages()).
    const expectedBase = {
      id: MSG_ID,
      senderId: ME,
      body: "Salut !",
      createdAt: NOW.toISOString(),
      sentAt: NOW.toISOString(),
      readAt: null,
    };
    expect(toOther.event).toEqual({
      type: "dm",
      conversationId: CONV,
      message: { ...expectedBase, isMine: false }, // côté DESTINATAIRE : pas son message
    });
    expect(toMe.event).toEqual({
      type: "dm",
      conversationId: CONV,
      message: { ...expectedBase, isMine: true }, // côté EXPÉDITEUR (multi-device) : son message
    });
  });

  it("la réponse REST de `send()` porte le même message (isMine:true côté expéditeur)", async () => {
    const { svc } = buildService();
    const res = (await svc.send(ME, OTHER, "Salut !")) as { conversationId: string; message: Record<string, unknown> };
    expect(res.conversationId).toBe(CONV);
    expect(res.message).toEqual({
      id: MSG_ID,
      senderId: ME,
      body: "Salut !",
      createdAt: NOW.toISOString(),
      sentAt: NOW.toISOString(),
      readAt: null,
      isMine: true,
    });
  });

  it("notifie le destinataire AVEC conversationId + senderId (deep-link push)", async () => {
    const { svc, pushCalls } = buildService();
    await svc.send(ME, OTHER, "Salut !");
    // Le push est best-effort/async (void) → on laisse la microtask se résoudre.
    await Promise.resolve();
    await Promise.resolve();
    expect(pushCalls).toEqual([
      { userId: OTHER, senderName: "MoiMême", conversationId: CONV, senderId: ME },
    ]);
  });
});
