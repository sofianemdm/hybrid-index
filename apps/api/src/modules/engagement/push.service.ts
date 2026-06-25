import { Injectable, Logger } from "@nestjs/common";
import { JWT } from "google-auth-library";
import { PrismaService } from "../../infra/prisma/prisma.service";

/** Charge utile d'une notification push (copie déjà localisée FR). */
export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/**
 * Service push (FCM HTTP v1). S'active quand `FCM_SERVICE_ACCOUNT` (JSON du compte de service
 * Firebase) est présent dans l'environnement ; sinon on journalise sans envoyer (dév/local).
 * Les device tokens sont PERSISTÉS en base (table `push_token`) — survit aux redéploiements.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private jwtClient: JWT | null = null;
  private serviceAccount: ServiceAccount | null = null;

  constructor(private readonly prisma: PrismaService) {}

  /** Le push est-il réellement activé (compte de service Firebase fourni) ? */
  get enabled(): boolean {
    return Boolean(process.env.FCM_SERVICE_ACCOUNT);
  }

  /** Charge (paresseusement, une fois) le compte de service + le client OAuth2. */
  private auth(): { client: JWT; projectId: string } | null {
    if (!this.enabled) return null;
    if (!this.jwtClient || !this.serviceAccount) {
      try {
        const sa = JSON.parse(process.env.FCM_SERVICE_ACCOUNT as string) as ServiceAccount;
        this.serviceAccount = sa;
        this.jwtClient = new JWT({
          email: sa.client_email,
          key: sa.private_key,
          scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
        });
      } catch (e) {
        this.logger.error(`FCM_SERVICE_ACCOUNT invalide : ${e}`);
        return null;
      }
    }
    return { client: this.jwtClient, projectId: this.serviceAccount.project_id };
  }

  /** Enregistre un device token (idempotent) : 1 token = 1 appareil, ré-affecté au bon user. */
  async registerToken(userId: string, token: string, platform = "android"): Promise<void> {
    if (!token) return;
    await this.prisma.pushToken.upsert({
      where: { token },
      create: { userId, token, platform },
      update: { userId, platform },
    });
  }

  async removeToken(userId: string, token: string): Promise<void> {
    await this.prisma.pushToken.deleteMany({ where: { userId, token } });
  }

  /** Envoie une notification à tous les appareils d'un utilisateur. No-op (journalisé) si inactif. */
  async sendToUser(userId: string, msg: PushMessage): Promise<void> {
    if (!this.enabled) {
      this.logger.debug(`[push inactif] → ${userId} : ${msg.title} — ${msg.body}`);
      return;
    }
    const rows = await this.prisma.pushToken.findMany({ where: { userId }, select: { token: true } });
    await Promise.all(rows.map((r) => this.sendToToken(r.token, msg).catch((e) => this.logger.warn(`push KO: ${e}`))));
  }

  /** Appel FCM HTTP v1 (OAuth2). Un token invalide (404/UNREGISTERED) est supprimé de la base. */
  private async sendToToken(token: string, msg: PushMessage): Promise<void> {
    const a = this.auth();
    if (!a) return;
    const accessToken = (await a.client.getAccessToken()).token;
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${a.projectId}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: msg.title, body: msg.body },
          data: msg.data ?? {},
        },
      }),
    });
    if (!res.ok) {
      this.logger.warn(`FCM ${res.status} pour token ${token.slice(0, 8)}…`);
      // Token périmé / désinstallé → on le purge pour ne pas réessayer indéfiniment.
      if (res.status === 404 || res.status === 400) {
        await this.prisma.pushToken.deleteMany({ where: { token } }).catch(() => undefined);
      }
    }
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

  /** Nouveau message privé reçu. `senderName` = pseudo de l'expéditeur. */
  notifyNewMessage(userId: string, senderName: string): Promise<void> {
    return this.sendToUser(userId, {
      title: `Message de ${senderName}`,
      body: "Ouvre la conversation pour répondre.",
      data: { type: "new-message" },
    });
  }
}
