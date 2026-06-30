import { MessagingService } from "../src/modules/messaging/messaging.service";
import { RealtimeGateway } from "../src/modules/realtime/realtime.gateway";
import { RealtimeService, type RealtimeEvent } from "../src/modules/realtime/realtime.service";

/**
 * Lot 7.1 (lecture temps réel) + 7.2 (saisie). On vérifie que :
 * - l'ouverture d'une conversation par le destinataire émet un event `read` vers L'EXPÉDITEUR ;
 * - le relais `typing` ne joint QUE l'autre participant, et est refusé aux non-participants / bloqués ;
 * - le gateway route une trame montante `{type:'typing'}` vers le handler, en s'appuyant sur l'userId
 *   du HANDSHAKE (jamais sur un éventuel champ du payload) et en ignorant les trames invalides.
 *
 * Mocks ciblés (pas de Postgres) : on isole la logique de routage/sécurité du temps réel.
 */

/** Capture les events émis par userId (le RealtimeService réel est testé ailleurs). */
function fakeRealtime() {
  const emitted: Array<{ userId: string; event: RealtimeEvent }> = [];
  return {
    emitted,
    emitToUser: (userId: string, event: RealtimeEvent) => emitted.push({ userId, event }),
  } as unknown as RealtimeService & { emitted: typeof emitted };
}

const ME = "user-me";
const OTHER = "user-other";
const CONV = "conv-1";

describe("Lot 7.1 — lecture temps réel : `messages()` émet `read` vers l'expéditeur", () => {
  function buildService(opts: { markedCount: number }) {
    const realtime = fakeRealtime();
    const conv = { id: CONV, userAId: ME, userBId: OTHER };
    const prisma = {
      conversation: { findUnique: jest.fn().mockResolvedValue(conv) },
      message: {
        // Pas de messages plus anciens (page récente, hasMore=false).
        findMany: jest.fn().mockResolvedValue([]),
        // Ancre de curseur (chemin `before`) : on renvoie une date quelconque.
        findFirst: jest.fn().mockResolvedValue({ createdAt: new Date() }),
        updateMany: jest.fn().mockResolvedValue({ count: opts.markedCount }),
      },
      user: { findUnique: jest.fn().mockResolvedValue({ profile: { displayName: "X", rank: "rookie" }, avatar: null }) },
    } as unknown as ConstructorParameters<typeof MessagingService>[0];
    const moderation = { isBlockedBetween: jest.fn() } as unknown as ConstructorParameters<typeof MessagingService>[1];
    const push = {} as unknown as ConstructorParameters<typeof MessagingService>[2];
    const svc = new MessagingService(prisma, moderation, push, realtime);
    return { svc, realtime, prisma };
  }

  it("émet `{type:'read'}` vers l'EXPÉDITEUR (l'autre participant) quand des messages passent lus", async () => {
    const { svc, realtime } = buildService({ markedCount: 2 });
    await svc.messages(ME, CONV); // ME ouvre/charge la page récente → marque lus les msgs de OTHER
    expect(realtime.emitted).toEqual([{ userId: OTHER, event: { type: "read", conversationId: CONV } }]);
  });

  it("n'émet RIEN si aucun message n'a été marqué lu (rien de neuf à signaler)", async () => {
    const { svc, realtime } = buildService({ markedCount: 0 });
    await svc.messages(ME, CONV);
    expect(realtime.emitted).toHaveLength(0);
  });

  it("n'émet PAS `read` en remontant l'historique (paramètre `before` présent)", async () => {
    const { svc, realtime, prisma } = buildService({ markedCount: 0 });
    await svc.messages(ME, CONV, { before: "anchor" });
    // En mode pagination antérieure, on ne marque pas lu et donc on n'émet pas.
    expect((prisma as unknown as { message: { updateMany: jest.Mock } }).message.updateMany).not.toHaveBeenCalled();
    expect(realtime.emitted).toHaveLength(0);
  });
});

describe("Lot 7.2 — saisie : `relayTyping` sécurité + bon destinataire", () => {
  function buildService(opts: { conv: unknown; blocked: boolean }) {
    const realtime = fakeRealtime();
    const prisma = {
      conversation: { findUnique: jest.fn().mockResolvedValue(opts.conv) },
    } as unknown as ConstructorParameters<typeof MessagingService>[0];
    const moderation = {
      isBlockedBetween: jest.fn().mockResolvedValue(opts.blocked),
    } as unknown as ConstructorParameters<typeof MessagingService>[1];
    const push = {} as unknown as ConstructorParameters<typeof MessagingService>[2];
    const svc = new MessagingService(prisma, moderation, push, realtime);
    return { svc, realtime };
  }

  it("relaie `{type:'typing'}` au SEUL autre participant", async () => {
    const { svc, realtime } = buildService({ conv: { userAId: ME, userBId: OTHER }, blocked: false });
    const to = await svc.relayTyping(ME, CONV);
    expect(to).toBe(OTHER);
    expect(realtime.emitted).toEqual([{ userId: OTHER, event: { type: "typing", conversationId: CONV } }]);
  });

  it("ignore un émetteur NON participant (aucun relais, pas d'erreur)", async () => {
    const { svc, realtime } = buildService({ conv: { userAId: "a", userBId: "b" }, blocked: false });
    const to = await svc.relayTyping(ME, CONV);
    expect(to).toBeNull();
    expect(realtime.emitted).toHaveLength(0);
  });

  it("ignore si la conversation est introuvable", async () => {
    const { svc, realtime } = buildService({ conv: null, blocked: false });
    expect(await svc.relayTyping(ME, CONV)).toBeNull();
    expect(realtime.emitted).toHaveLength(0);
  });

  it("coupe le signal si les deux comptes sont bloqués (cohérent avec l'envoi)", async () => {
    const { svc, realtime } = buildService({ conv: { userAId: ME, userBId: OTHER }, blocked: true });
    expect(await svc.relayTyping(ME, CONV)).toBeNull();
    expect(realtime.emitted).toHaveLength(0);
  });
});

describe("RealtimeGateway — canal montant : route `typing` via l'userId du handshake", () => {
  it("délègue `{type:'typing'}` à handleClientTyping avec l'userId validé (jamais celui du payload)", () => {
    const realtime = new RealtimeService();
    const calls: Array<{ userId: string; conversationId: string }> = [];
    realtime.setTypingHandler((userId, conversationId) => {
      calls.push({ userId, conversationId });
    });
    const gw = new RealtimeGateway({} as never, realtime);

    // Accès à la méthode privée pour tester le routage de trame sans vrai socket `ws`.
    const handle = (gw as unknown as { handleClientFrame(c: unknown, d: unknown): void }).handleClientFrame.bind(gw);
    const client = { userId: ME };

    // Trame valide : un payload qui tente d'usurper un autre userId est ignoré — on utilise le handshake.
    handle(client, JSON.stringify({ type: "typing", conversationId: CONV, userId: "spoofed" }));
    // Buffer (l'API `ws` peut livrer des Buffer) accepté aussi.
    handle(client, Buffer.from(JSON.stringify({ type: "typing", conversationId: "conv-2" }), "utf8"));

    expect(calls).toEqual([
      { userId: ME, conversationId: CONV },
      { userId: ME, conversationId: "conv-2" },
    ]);
  });

  it("ignore les trames non conformes (mauvais type, non-JSON, conversationId manquant)", () => {
    const realtime = new RealtimeService();
    const calls: string[] = [];
    realtime.setTypingHandler((_userId, conversationId) => {
      calls.push(conversationId);
    });
    const gw = new RealtimeGateway({} as never, realtime);
    const handle = (gw as unknown as { handleClientFrame(c: unknown, d: unknown): void }).handleClientFrame.bind(gw);
    const client = { userId: ME };

    handle(client, "pas du json");
    handle(client, JSON.stringify({ type: "dm", conversationId: CONV })); // type non monté
    handle(client, JSON.stringify({ type: "typing" })); // conversationId manquant
    handle({ userId: undefined }, JSON.stringify({ type: "typing", conversationId: CONV })); // non authentifié

    expect(calls).toHaveLength(0);
  });
});
