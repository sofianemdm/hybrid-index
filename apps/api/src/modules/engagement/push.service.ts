import { Injectable, Logger } from "@nestjs/common";

/** Charge utile d'une notification push (copie déjà localisée FR). */
export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Service push « prêt mais inactif ».
 *
 * Tout le code d'envoi et les déclencheurs amicaux sont en place ; l'envoi RÉEL n'est activé que
 * si `FCM_SERVER_KEY` est présent dans l'environnement (sinon on journalise sans envoyer). C'est
 * l'interrupteur : le jour où le projet Firebase est créé et la clé fournie, le push s'allume
 * sans toucher au code.
 *
 * NB — stockage des tokens : en mémoire pour l'instant (suffisant tant que le push est inactif).
 * À l'ACTIVATION : remplacer la Map par une table `PushToken` persistée (1 migration) — voir
 * `registerToken`. Aucune fonctionnalité active ne dépend de ce store aujourd'hui.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private readonly tokens = new Map<string, Set<string>>();

  /** Le push est-il réellement activé (clé Firebase présente) ? */
  get enabled(): boolean {
    return Boolean(process.env.FCM_SERVER_KEY);
  }

  /** Enregistre un device token pour un utilisateur (idempotent). */
  registerToken(userId: string, token: string): void {
    if (!token) return;
    const set = this.tokens.get(userId) ?? new Set<string>();
    set.add(token);
    this.tokens.set(userId, set);
  }

  removeToken(userId: string, token: string): void {
    this.tokens.get(userId)?.delete(token);
  }

  /** Envoie une notification à tous les devices d'un utilisateur. No-op (journalisé) si inactif. */
  async sendToUser(userId: string, msg: PushMessage): Promise<void> {
    if (!this.enabled) {
      this.logger.debug(`[push inactif] → ${userId} : ${msg.title} — ${msg.body}`);
      return;
    }
    const tokens = [...(this.tokens.get(userId) ?? [])];
    if (tokens.length === 0) return;
    await Promise.all(tokens.map((t) => this.sendToToken(t, msg).catch((e) => this.logger.warn(`push KO: ${e}`))));
  }

  /** Appel FCM (HTTP legacy). Exécuté uniquement quand `enabled`. */
  private async sendToToken(token: string, msg: PushMessage): Promise<void> {
    const res = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        Authorization: `key=${process.env.FCM_SERVER_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        to: token,
        notification: { title: msg.title, body: msg.body },
        data: msg.data ?? {},
      }),
    });
    if (!res.ok) this.logger.warn(`FCM ${res.status} pour token ${token.slice(0, 8)}…`);
  }

  // --- Déclencheurs amicaux (copie FR verrouillée, ton bienveillant) ---

  notifyRankOvertaken(userId: string): Promise<void> {
    return this.sendToUser(userId, {
      title: "On t'a doublé au classement",
      body: "Reprends ta place — un bon WOD peut suffire. 👊",
      data: { type: "rank-overtaken" },
    });
  }

  notifyStaleAttribute(userId: string, attributeLabel: string): Promise<void> {
    return this.sendToUser(userId, {
      title: "Un de tes axes mérite un re-test",
      body: `Ton ${attributeLabel} peut grimper. Quand tu veux.`,
      data: { type: "stale-attribute" },
    });
  }

  notifyNearRank(userId: string, points: number): Promise<void> {
    return this.sendToUser(userId, {
      title: "Le prochain palier est tout proche",
      body: `Plus que ${points} point${points > 1 ? "s" : ""} — un bon WOD et tu y es.`,
      data: { type: "near-rank" },
    });
  }

  notifyKudos(userId: string, count: number): Promise<void> {
    return this.sendToUser(userId, {
      title: "On a réagi à ta perf",
      body: `${count} athlète${count > 1 ? "s ont" : " a"} salué ta séance. 🔥`,
      data: { type: "kudos" },
    });
  }

  notifyWeeklyRecap(userId: string, deltaIndex: number, sessions: number): Promise<void> {
    return this.sendToUser(userId, {
      title: "Ta semaine en bref",
      body: `+${deltaIndex} pts d'Index, ${sessions} séance${sessions > 1 ? "s" : ""}. Belle semaine. 📈`,
      data: { type: "weekly-recap" },
    });
  }
}
