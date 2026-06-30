import { BadRequestException, ForbiddenException, Injectable, NotFoundException, type OnModuleInit } from "@nestjs/common";
import { dmAgeAllowed } from "@hybrid-index/contracts";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";
import { PushService } from "../engagement/push.service";
import { RealtimeService } from "../realtime/realtime.service";
import { serializeAvatar } from "../../common/avatar.serializer";

/** OVR /100 d'un Index interne /1000 (grade affiché), ou null. */
const ovr = (internal: number | null | undefined): number | null =>
  internal == null ? null : Math.round(ratingFromInternal(internal));

const MAX_BODY = 2000;

export interface DmEligibility {
  allowed: boolean;
  reason?: "self" | "blocked" | "age" | "not_connected";
}

/**
 * Messagerie privée (Phase C5). Portée PRUDENTE : on n'écrit qu'à quelqu'un avec qui on a un
 * lien réel (abonnement mutuel OU club commun), jamais à un inconnu, jamais en cas de blocage,
 * et UNIQUEMENT dans la même tranche d'âge (séparation stricte mineurs/adultes — voir contracts).
 */
@Injectable()
export class MessagingService implements OnModuleInit {
  constructor(
    private readonly prisma: PrismaService,
    private readonly moderation: ModerationService,
    private readonly push: PushService,
    private readonly realtime: RealtimeService,
  ) {}

  /**
   * Branche le canal montant « saisie » : le gateway WS reçoit `{type:'typing'}`, délègue à
   * `RealtimeService.handleClientTyping`, qui appelle ce handler — lequel valide la participation
   * (accès Prisma ici) et relaie à l'autre. Découplage de module : le gateway n'importe pas la
   * messagerie.
   */
  onModuleInit(): void {
    this.realtime.setTypingHandler(async (userId, conversationId) => {
      await this.relayTyping(userId, conversationId);
    });
  }

  /** Couple canonique (ordre stable) pour une conversation 1‑à‑1. */
  private pair(a: string, b: string): { userAId: string; userBId: string } {
    return a < b ? { userAId: a, userBId: b } : { userAId: b, userBId: a };
  }


  async eligibility(me: string, other: string): Promise<DmEligibility> {
    if (me === other) return { allowed: false, reason: "self" };
    const [meUser, otherUser] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: me }, select: { dateOfBirth: true } }),
      // Cible : doit exister ET être active (pas de DM vers un compte supprimé/désactivé).
      this.prisma.user.findFirst({ where: { id: other, status: "active" }, select: { dateOfBirth: true } }),
    ]);
    if (!meUser || !otherUser) return { allowed: false, reason: "not_connected" };
    if (await this.moderation.isBlockedBetween(me, other)) return { allowed: false, reason: "blocked" };
    // App 100 % publique : on peut écrire à n'importe quel compte actif, SANS se suivre ni partager
    // de club. On conserve uniquement les garde-fous de sécurité : blocage et compatibilité d'âge
    // (protection des mineurs, cf. age-gating ≥ 13 ans) — jamais retirés.
    if (!dmAgeAllowed(meUser.dateOfBirth, otherUser.dateOfBirth, new Date())) return { allowed: false, reason: "age" };
    return { allowed: true };
  }

  private async assertCanDm(me: string, other: string): Promise<void> {
    const elig = await this.eligibility(me, other);
    if (elig.allowed) return;
    // App 100 % publique : aucune restriction de « lien social ». Le seul motif `not_connected`
    // restant signifie que le compte cible n'existe plus / n'est plus actif — copie honnête.
    const messages: Record<NonNullable<DmEligibility["reason"]>, string> = {
      self: "On ne s'écrit pas à soi-même.",
      blocked: "Échange impossible avec cet utilisateur.",
      age: "Les messages privés ne sont possibles qu'entre comptes de la même tranche d'âge.",
      not_connected: "Ce compte n'est plus disponible.",
    };
    throw new ForbiddenException({ code: "DM_NOT_ALLOWED", message: messages[elig.reason ?? "not_connected"] });
  }

  /** Envoie un message (crée la conversation au besoin). */
  async send(me: string, toUserId: string, rawBody: string): Promise<unknown> {
    const body = rawBody.trim();
    if (!body) throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Message vide." });
    if (body.length > MAX_BODY) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: `Message limité à ${MAX_BODY} caractères.` });
    }
    await this.assertCanDm(me, toUserId);

    const { userAId, userBId } = this.pair(me, toUserId);
    const now = new Date();
    const conv = await this.prisma.conversation.upsert({
      where: { userAId_userBId: { userAId, userBId } },
      create: { userAId, userBId, lastMessageAt: now },
      update: { lastMessageAt: now },
    });
    const msg = await this.prisma.message.create({
      data: { conversationId: conv.id, senderId: me, body },
    });
    // Notification push au destinataire (best-effort, no-op si push inactif). On passe l'id de
    // conversation pour le deep-link (tap → la BONNE conversation) côté client.
    void this.notifyRecipient(me, toUserId, conv.id);
    // Signal temps réel APRÈS commit (best-effort, jamais bloquant pour l'envoi REST) : on pousse
    // le MESSAGE COMPLET (Incrément 1 — instantanéité) au DESTINATAIRE et à l'EXPÉDITEUR
    // (multi-device). Le client l'ajoute DIRECTEMENT au fil, SANS round-trip REST. `isMine` est
    // calculé par destinataire (false côté destinataire, true côté expéditeur). `emitToUser` est
    // déjà best-effort, on isole tout de même par prudence.
    const createdAtIso = msg.createdAt.toISOString();
    const dmMessage = (forUser: string) => ({
      id: msg.id,
      senderId: me,
      body: msg.body,
      createdAt: createdAtIso,
      sentAt: createdAtIso,
      readAt: null,
      isMine: msg.senderId === forUser,
    });
    try {
      this.realtime.emitToUser(toUserId, { type: "dm", conversationId: conv.id, message: dmMessage(toUserId) });
      this.realtime.emitToUser(me, { type: "dm", conversationId: conv.id, message: dmMessage(me) });
    } catch {
      // best-effort : le DM est persisté, le temps réel est un bonus.
    }
    return {
      conversationId: conv.id,
      message: dmMessage(me),
    };
  }

  /** Pousse une notif « nouveau message » au destinataire (jamais bloquant pour l'envoi). */
  private async notifyRecipient(senderId: string, toUserId: string, conversationId: string): Promise<void> {
    try {
      const sender = await this.prisma.profile.findUnique({ where: { userId: senderId }, select: { displayName: true } });
      await this.push.notifyNewMessage(toUserId, sender?.displayName ?? "Un athlète", conversationId, senderId);
    } catch {
      // best-effort
    }
  }

  /** Mes conversations (autre participant + dernier message + non-lus). */
  async conversations(me: string): Promise<unknown[]> {
    const convs = await this.prisma.conversation.findMany({
      where: { OR: [{ userAId: me }, { userBId: me }], lastMessageAt: { not: null } },
      orderBy: { lastMessageAt: "desc" },
      take: 50,
      include: {
        userA: { include: { profile: { select: { displayName: true, rank: true } }, hybridIndex: { select: { value: true } }, avatar: true } },
        userB: { include: { profile: { select: { displayName: true, rank: true } }, hybridIndex: { select: { value: true } }, avatar: true } },
        // Aperçu : ignorer les messages masqués par modération.
        messages: { where: { status: "visible" }, orderBy: { createdAt: "desc" }, take: 1 },
      },
    });
    // Non-lus en UNE requête groupée (au lieu d'un COUNT par conversation — BUG-022 N+1).
    const unreadRows = await this.prisma.message.groupBy({
      by: ["conversationId"],
      where: { conversationId: { in: convs.map((c) => c.id) }, senderId: { not: me }, readAt: null, status: "visible" },
      _count: { _all: true },
    });
    const unreadByConv = new Map(unreadRows.map((r) => [r.conversationId, r._count._all]));
    const result = [];
    for (const c of convs) {
      const other = c.userAId === me ? c.userB : c.userA;
      const last = c.messages[0];
      result.push({
        id: c.id,
        other: {
          userId: other.id,
          displayName: other.profile?.displayName ?? "—",
          rank: other.profile?.rank ?? "rookie",
          index: ovr(other.hybridIndex?.value),
          avatar: serializeAvatar(other.avatar),
        },
        lastMessage: last ? { body: last.body, createdAt: last.createdAt.toISOString(), isMine: last.senderId === me } : null,
        unread: unreadByConv.get(c.id) ?? 0,
      });
    }
    return result;
  }

  /**
   * Messages d'une conversation (participant requis) + marquage comme lus.
   *
   * Pagination par curseur descendant : on renvoie la PAGE LA PLUS RÉCENTE (les `limit` derniers
   * messages, ré-ordonnés asc pour l'affichage) ; passer `before` = id d'un message charge la page
   * ANTÉRIEURE (« charger les messages précédents » au scroll vers le haut). `hasMore` indique s'il
   * reste des messages plus anciens à charger. Le marquage « lu » ne s'applique qu'à la page la
   * plus récente (before absent), pour ne pas marquer lu en remontant l'historique.
   */
  async messages(me: string, conversationId: string, opts?: { before?: string; limit?: number }): Promise<unknown> {
    const conv = await this.prisma.conversation.findUnique({ where: { id: conversationId } });
    if (!conv) throw new NotFoundException({ code: "NOT_FOUND", message: "Conversation introuvable." });
    if (conv.userAId !== me && conv.userBId !== me) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Conversation non accessible." });
    }
    const otherId = conv.userAId === me ? conv.userBId : conv.userAId;
    const limit = Math.min(Math.max(opts?.limit ?? 50, 1), 100);

    // Curseur : on borne par le createdAt du message `before` (messages STRICTEMENT plus anciens).
    let beforeCursor: Date | undefined;
    if (opts?.before) {
      const anchor = await this.prisma.message.findFirst({
        where: { id: opts.before, conversationId },
        select: { createdAt: true },
      });
      // Curseur inconnu (id étranger à la conversation) ⇒ page la plus récente (pas d'erreur dure).
      beforeCursor = anchor?.createdAt;
    }

    const [page, other] = await Promise.all([
      // On lit `limit + 1` en DESC pour savoir s'il reste des messages plus anciens (hasMore).
      this.prisma.message.findMany({
        where: {
          conversationId,
          status: "visible",
          ...(beforeCursor ? { createdAt: { lt: beforeCursor } } : {}),
        },
        // `id` en tie-breaker pour un ordre déterministe si deux messages partagent le createdAt.
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        take: limit + 1,
      }),
      this.prisma.user.findUnique({
        where: { id: otherId },
        include: { profile: { select: { displayName: true, rank: true } }, avatar: true },
      }),
    ]);

    const hasMore = page.length > limit;
    // On garde `limit` messages, puis on ré-ordonne asc pour l'affichage du fil (du + ancien au + récent).
    const rows = page.slice(0, limit).reverse();

    // Marquer « lu » uniquement sur la page la plus récente (chargement / poll), pas en remontant.
    if (!opts?.before) {
      const marked = await this.prisma.message.updateMany({
        where: { conversationId, senderId: { not: me }, readAt: null },
        data: { readAt: new Date() },
      });
      // Lecture temps réel : si on vient RÉELLEMENT de marquer des messages comme lus, on prévient
      // l'EXPÉDITEUR (l'autre participant) pour que son fil passe « Envoyé » → « Lu » sans attendre
      // le poll. Best-effort, jamais bloquant (le `readAt` est déjà persisté, le WS est un bonus).
      if (marked.count > 0) {
        try {
          this.realtime.emitToUser(otherId, { type: "read", conversationId });
        } catch {
          // best-effort : l'accusé de lecture est en base, le temps réel n'est qu'une accélération.
        }
      }
    }

    return {
      id: conv.id,
      other: {
        userId: otherId,
        displayName: other?.profile?.displayName ?? "—",
        rank: other?.profile?.rank ?? "rookie",
        avatar: serializeAvatar(other?.avatar),
      },
      // `hasMore` = il existe des messages plus anciens ; `nextBefore` = curseur à passer pour les charger.
      hasMore,
      nextBefore: hasMore && rows.length > 0 ? rows[0].id : null,
      messages: rows.map((m) => ({
        id: m.id,
        senderId: m.senderId,
        body: m.body,
        // `createdAt` = horodatage d'envoi ; `sentAt` est un alias explicite pour le client.
        createdAt: m.createdAt.toISOString(),
        sentAt: m.createdAt.toISOString(),
        // Accusé de lecture : non null dès que le destinataire a ouvert la conversation.
        readAt: m.readAt ? m.readAt.toISOString() : null,
        isMine: m.senderId === me,
      })),
    };
  }

  /**
   * Indicateur de saisie (Lot 7.2) : relaie un signal « X est en train d'écrire » à l'AUTRE
   * participant de la conversation. Éphémère — AUCUNE persistance, aucune notif push.
   *
   * Sécurité : on VALIDE que l'émetteur participe bien à la conversation (sinon on ne relaie rien,
   * pas d'erreur dure : le canal montant est best-effort, on ignore silencieusement les abus). Un
   * blocage entre les deux comptes coupe aussi le signal (cohérent avec l'impossibilité d'écrire).
   *
   * @returns l'id du destinataire si le signal a été relayé, sinon `null` (non-participant/bloqué).
   */
  async relayTyping(me: string, conversationId: string): Promise<string | null> {
    const conv = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      select: { userAId: true, userBId: true },
    });
    if (!conv) return null;
    if (conv.userAId !== me && conv.userBId !== me) return null; // émetteur non participant → ignore
    const otherId = conv.userAId === me ? conv.userBId : conv.userAId;
    // Un blocage (dans un sens ou l'autre) coupe le signal de saisie comme il coupe l'envoi.
    if (await this.moderation.isBlockedBetween(me, otherId)) return null;
    try {
      this.realtime.emitToUser(otherId, { type: "typing", conversationId });
    } catch {
      // best-effort : la saisie est un pur bonus d'UX, jamais bloquante.
    }
    return otherId;
  }
}
