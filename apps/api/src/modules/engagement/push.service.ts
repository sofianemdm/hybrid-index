import { Injectable, Logger } from "@nestjs/common";
import { JWT } from "google-auth-library";
import { PrismaService } from "../../infra/prisma/prisma.service";
import {
  withinQuietHours,
  underDailyCap,
  cooldownElapsed,
  prefEnabled,
  type QuietHours,
} from "./notification-gating";
import { NOTIFICATION_TRIGGERS, pushCopy, type PushLocale } from "./notifications.data";

/** Charge utile d'une notification push (copie déjà localisée FR). */
export interface PushMessage {
  title: string;
  body: string;
  /** `data.type` = clé du déclencheur ; sert au gating (cooldown/opt-out) et au routage app. */
  data?: Record<string, string>;
}

const DEFAULT_QUIET: QuietHours = { start: "22:00", end: "07:00" };
const DEFAULT_DAILY_CAP = 2;

/** Convertit un cooldown du catalogue ("24h", "72h", "7d", "0") en secondes. */
function cooldownToSec(raw: string | undefined): number {
  if (!raw) return 0;
  const m = /^(\d+)\s*([hdm]?)$/.exec(raw.trim());
  if (!m) return 0;
  const n = Number(m[1]);
  switch (m[2]) {
    case "d":
      return n * 86400;
    case "m":
      return n * 60;
    case "h":
    default:
      return n * 3600;
  }
}

/** Cooldown (en secondes) par clé de déclencheur, dérivé du catalogue NOTIFICATION_TRIGGERS. */
const COOLDOWN_BY_TYPE: Record<string, number> = Object.fromEntries(
  NOTIFICATION_TRIGGERS.map((t) => [t.key, cooldownToSec(t.cooldown)]),
);

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

  /**
   * Gating AAA : décide si un push de `type` peut partir MAINTENANT pour `userId`, en appliquant
   * les préférences (opt-out par clé, quietHours, dailyCap) + le cooldown par type. Retourne la
   * raison du blocage (pour le log) ou null si l'envoi est autorisé. `now` injectable (tests).
   */
  private async gate(userId: string, type: string | undefined, now = new Date()): Promise<string | null> {
    const prefsRow = await this.prisma.notificationPrefs.findUnique({ where: { userId } });
    const prefs = (prefsRow?.prefs as Record<string, boolean> | undefined) ?? {};
    const quietHours = (prefsRow?.quietHours as QuietHours | undefined) ?? DEFAULT_QUIET;
    const dailyCap = prefsRow?.dailyCap ?? DEFAULT_DAILY_CAP;

    // 1) Opt-out par clé (le type du déclencheur sert de clé de préférence).
    if (type && !prefEnabled(prefs, type)) return "opt-out";

    // 2) Heures de silence.
    if (withinQuietHours(now, quietHours)) return "quiet-hours";

    // 3) Plafond journalier (envois des dernières 24h, tous types confondus).
    const since = new Date(now.getTime() - 86400_000);
    const countToday = await this.prisma.notificationLog.count({
      where: { userId, sentAt: { gte: since } },
    });
    if (!underDailyCap(countToday, dailyCap)) return "daily-cap";

    // 4) Cooldown par type (dernier envoi de ce même type).
    if (type) {
      const last = await this.prisma.notificationLog.findFirst({
        where: { userId, type },
        orderBy: { sentAt: "desc" },
        select: { sentAt: true },
      });
      if (!cooldownElapsed(last?.sentAt ?? null, now, COOLDOWN_BY_TYPE[type] ?? 0)) return "cooldown";
    }
    return null;
  }

  /**
   * Envoie une notification à tous les appareils d'un utilisateur, APRÈS gating (opt-out,
   * quietHours, dailyCap, cooldown). Journalise l'envoi dans NotificationLog (pour le gating
   * suivant). No-op journalisé si push inactif ou si le gating bloque.
   */
  async sendToUser(userId: string, msg: PushMessage): Promise<void> {
    // Push INACTIF (pas de compte de service FCM) : no-op PUR, AUCUNE requête DB. Le gating et le
    // log ne servent qu'à un envoi réel ; inutile (et risqué en test) de toucher la base sinon.
    if (!this.enabled) {
      this.logger.debug(`[push inactif] → ${userId} : ${msg.title} — ${msg.body}`);
      return;
    }
    const type = msg.data?.type;
    const blocked = await this.gate(userId, type).catch(() => null);
    if (blocked) {
      this.logger.debug(`[push bloqué:${blocked}] → ${userId} (${type ?? "?"}) : ${msg.title}`);
      return;
    }
    const rows = await this.prisma.pushToken.findMany({ where: { userId }, select: { token: true } });
    if (rows.length === 0) return; // pas d'appareil : rien à journaliser
    await Promise.all(rows.map((r) => this.sendToToken(r.token, msg).catch((e) => this.logger.warn(`push KO: ${e}`))));
    await this.logSent(userId, type);
  }

  /** Journalise un envoi push (pour dailyCap/cooldown). best-effort : n'interrompt jamais l'envoi. */
  private async logSent(userId: string, type: string | undefined): Promise<void> {
    await this.prisma.notificationLog
      .create({ data: { userId, type: type ?? "unknown" } })
      .catch((e) => this.logger.warn(`notificationLog KO: ${e}`));
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

  // --- Déclencheurs amicaux (copie centralisée FR/EN dans notifications.data, ton bienveillant) ---
  //
  // TODO(i18n) : la langue est figée à "fr" tant que le modèle Profile/User ne porte pas de `locale`.
  // Dès qu'un champ `locale` existe, le résoudre par appelant et le passer en 2e argument de pushCopy.

  /** Compose un PushMessage à partir de la copie centralisée (locale FR par défaut). */
  private compose(type: string, params: Record<string, string | number> = {}, locale: PushLocale = "fr"): PushMessage {
    const { title, body } = pushCopy(type, locale, params);
    return { title, body, data: { type } };
  }

  notifyRankOvertaken(userId: string): Promise<void> {
    return this.sendToUser(userId, this.compose("rank-overtaken"));
  }

  notifyStaleAttribute(userId: string, attributeLabel: string): Promise<void> {
    return this.sendToUser(userId, this.compose("stale-attribute", { attributeLabel }));
  }

  notifyNearRank(userId: string, points: number): Promise<void> {
    return this.sendToUser(userId, this.compose("near-rank", { points }));
  }

  notifyKudos(userId: string, count: number): Promise<void> {
    return this.sendToUser(userId, this.compose("kudos", { count }));
  }

  notifyWeeklyRecap(userId: string, deltaIndex: number, sessions: number): Promise<void> {
    return this.sendToUser(userId, this.compose("weekly-recap", { deltaIndex, sessions }));
  }

  /** Nouveau message privé reçu. `senderName` = pseudo de l'expéditeur. */
  notifyNewMessage(userId: string, senderName: string): Promise<void> {
    return this.sendToUser(userId, this.compose("new-message", { senderName }));
  }
}
