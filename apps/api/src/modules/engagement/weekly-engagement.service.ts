import { Injectable, Logger } from "@nestjs/common";
import { Cron } from "@nestjs/schedule";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ChallengeService } from "../challenge/challenge.service";
import { EngagementService } from "./engagement.service";
import { PushService } from "./push.service";
import { attributeLabel, type PushLocale } from "./notifications.data";

/**
 * Cron hebdomadaire de ré-engagement (lundi matin) : pour chaque athlète ACTIF ayant déjà un Index,
 * envoie (best-effort) le RÉCAP de la semaine écoulée (« weekly-recap ») et, si pertinent, signale un
 * attribut en STAGNATION (« stale-attribute »). Tout passe par PushService.sendToUser → le gating
 * (opt-out par clé, quietHours, dailyCap, cooldown) et le no-op « push inactif » s'appliquent : ce
 * cron ne contourne JAMAIS les préférences de l'utilisateur. Un échec sur un user n'interrompt pas
 * la boucle (chaque envoi est isolé).
 */
@Injectable()
export class WeeklyEngagementService {
  private readonly logger = new Logger(WeeklyEngagementService.name);
  /** Borne de sécurité : on ne balaie pas une base illimitée en une passe (lots de N users). */
  private static readonly MAX_USERS_PER_RUN = 5000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly engagement: EngagementService,
    private readonly push: PushService,
    private readonly challenge: ChallengeService,
  ) {}

  /** Lundi 09:00 (heure serveur). Récap hebdo + signal d'attribut stagnant pour les actifs opt-in. */
  @Cron("0 9 * * 1")
  async weeklyReengagement(): Promise<void> {
    // En test, on n'envoie pas automatiquement (les unit tests appellent runOnce explicitement).
    if (process.env.NODE_ENV === "test" || process.env.JEST_WORKER_ID) return;
    await this.runOnce().catch((e) => this.logger.warn(`Cron ré-engagement hebdo KO : ${e}`));
  }

  /**
   * Exécute une passe : sélectionne les athlètes actifs ayant un Index, et pour chacun envoie le
   * récap hebdo puis (le cas échéant) le signal d'attribut stagnant. Idempotent vis-à-vis du gating
   * (cooldown 7j sur weekly-recap empêche tout doublon si relancé). Retourne le nombre d'users traités.
   */
  async runOnce(): Promise<{ processed: number }> {
    // Actifs = compte `active` AVEC un Index (au moins une séance) : on n'embête pas les comptes vides.
    const users = await this.prisma.hybridIndex.findMany({
      where: { user: { is: { status: "active" } } },
      select: { userId: true },
      take: WeeklyEngagementService.MAX_USERS_PER_RUN,
    });

    // Défi de la semaine résolu UNE fois pour toute la passe (même WOD pour tout le monde).
    // Best-effort : sans nom de défi, on n'envoie simplement pas cette notif.
    let challengeName: string | null;
    try {
      const ch = (await this.challenge.current()) as { wodName?: string } | null;
      challengeName = ch?.wodName ?? null;
    } catch {
      challengeName = null;
    }

    let processed = 0;
    for (const { userId } of users) {
      try {
        if (challengeName != null) await this.push.notifyWeeklyChallenge(userId, challengeName);
        await this.sendRecap(userId);
        await this.sendStaleAttribute(userId);
        processed += 1;
      } catch (e) {
        // Isolation par user : on logue et on continue (jamais d'arrêt global).
        this.logger.warn(`Ré-engagement hebdo KO (${userId}) : ${e}`);
      }
    }
    this.logger.log(`Ré-engagement hebdo : ${processed}/${users.length} athlètes traités.`);
    return { processed };
  }

  /** Récap de la semaine écoulée → push « weekly-recap » (gating en aval). */
  private async sendRecap(userId: string): Promise<void> {
    const recap = await this.engagement.weeklyRecap(userId);
    // On n'envoie un récap QUE s'il y a quelque chose à célébrer (au moins une séance ou un gain
    // d'Index) — un récap « 0 séance, +0 pt » n'est ni utile ni valorisant.
    if (recap.sessions <= 0 && recap.deltaIndex <= 0) return;
    await this.push.notifyWeeklyRecap(userId, recap.deltaIndex, recap.sessions);
  }

  /**
   * Signale UN attribut stagnant : un attribut débloqué marqué `isStale` (le score-service le pose
   * quand le meilleur effort de l'attribut est trop ancien). On choisit le plus FAIBLE (plus gros
   * levier de progression). Aucun attribut stale → pas de push.
   */
  private async sendStaleAttribute(userId: string): Promise<void> {
    const stale = await this.prisma.attributeScore.findFirst({
      where: { userId, unlocked: true, isStale: true },
      orderBy: [{ score: "asc" }, { attribute: "asc" }],
      select: { attribute: true },
    });
    if (!stale) return;
    // Libellé de l'attribut dans la langue du DESTINATAIRE (Profile.locale, repli FR) pour rester
    // cohérent avec le titre/corps localisés côté PushService.
    const locale = await this.recipientLocale(userId);
    await this.push.notifyStaleAttribute(userId, attributeLabel(stale.attribute, locale));
  }

  /** Langue du destinataire (Profile.locale, repli FR ; tolère un profil absent / une erreur DB). */
  private async recipientLocale(userId: string): Promise<PushLocale> {
    try {
      const profile = await this.prisma.profile.findUnique({
        where: { userId },
        select: { locale: true },
      });
      return profile?.locale === "en" ? "en" : "fr";
    } catch {
      return "fr";
    }
  }
}
