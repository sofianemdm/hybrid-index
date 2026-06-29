import { RealtimeService, type RealtimeSocket } from "../src/modules/realtime/realtime.service";

/** Mock de socket : capture les payloads envoyés ; `readyState` pilotable (1 = OPEN). */
class FakeSocket implements RealtimeSocket {
  readyState = 1; // OPEN
  sent: string[] = [];
  throwOnSend = false;
  send(data: string): void {
    if (this.throwOnSend) throw new Error("socket en erreur");
    this.sent.push(data);
  }
}

describe("RealtimeService — registre userId→sockets & emitToUser", () => {
  let svc: RealtimeService;
  beforeEach(() => {
    svc = new RealtimeService();
  });

  it("register/unregister tient le compte des sockets par utilisateur", () => {
    const a1 = new FakeSocket();
    const a2 = new FakeSocket();
    expect(svc.socketCount("u-a")).toBe(0);

    svc.register("u-a", a1);
    svc.register("u-a", a2);
    expect(svc.socketCount("u-a")).toBe(2);

    svc.unregister("u-a", a1);
    expect(svc.socketCount("u-a")).toBe(1);

    svc.unregister("u-a", a2);
    expect(svc.socketCount("u-a")).toBe(0);
  });

  it("emitToUser envoie l'event JSON à TOUTES les sockets ouvertes de l'utilisateur (multi-device)", () => {
    const a1 = new FakeSocket();
    const a2 = new FakeSocket();
    svc.register("u-a", a1);
    svc.register("u-a", a2);

    svc.emitToUser("u-a", { type: "dm", conversationId: "conv-1" });

    const expected = JSON.stringify({ type: "dm", conversationId: "conv-1" });
    expect(a1.sent).toEqual([expected]);
    expect(a2.sent).toEqual([expected]);
  });

  it("emitToUser n'atteint QUE l'utilisateur ciblé (isolation entre users)", () => {
    const a = new FakeSocket();
    const b = new FakeSocket();
    svc.register("u-a", a);
    svc.register("u-b", b);

    svc.emitToUser("u-a", { type: "dm", conversationId: "conv-x" });

    expect(a.sent).toHaveLength(1);
    expect(b.sent).toHaveLength(0);
  });

  it("emitToUser est un no-op si l'utilisateur n'a aucune socket (déconnecté)", () => {
    // Ne doit pas lever : la notif push / le polling REST prennent le relais.
    expect(() => svc.emitToUser("absent", { type: "dm", conversationId: "c" })).not.toThrow();
  });

  it("emitToUser ignore les sockets non-OPEN (readyState != 1)", () => {
    const open = new FakeSocket();
    const closing = new FakeSocket();
    closing.readyState = 2; // CLOSING
    svc.register("u-a", open);
    svc.register("u-a", closing);

    svc.emitToUser("u-a", { type: "dm", conversationId: "c" });

    expect(open.sent).toHaveLength(1);
    expect(closing.sent).toHaveLength(0);
  });

  it("emitToUser est best-effort : une socket en erreur n'empêche pas l'envoi aux autres", () => {
    const bad = new FakeSocket();
    bad.throwOnSend = true;
    const good = new FakeSocket();
    svc.register("u-a", bad);
    svc.register("u-a", good);

    expect(() => svc.emitToUser("u-a", { type: "dm", conversationId: "c" })).not.toThrow();
    expect(good.sent).toHaveLength(1); // la bonne socket reçoit malgré l'échec de l'autre.
  });

  it("après unregister total, emitToUser ne joint plus l'utilisateur", () => {
    const s = new FakeSocket();
    svc.register("u-a", s);
    svc.unregister("u-a", s);
    svc.emitToUser("u-a", { type: "dm", conversationId: "c" });
    expect(s.sent).toHaveLength(0);
  });
});
