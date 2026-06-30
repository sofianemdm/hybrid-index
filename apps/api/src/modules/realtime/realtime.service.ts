import { Injectable, Logger } from "@nestjs/common";

/** Socket minimale dont a besoin le registre (sous-ensemble de l'API `ws`). Permet de tester avec un mock. */
export interface RealtimeSocket {
  /** État de la connexion ; `1` = OPEN dans l'API `ws`/WebSocket. */
  readyState: number;
  send(data: string): void;
}

/** OPEN au sens de l'API WebSocket (`WebSocket.OPEN === 1`). */
const WS_OPEN = 1;

/**
 * Message direct sérialisé TRANSPORTÉ dans la trame WS `dm` (Incrément 1 — messagerie instantanée).
 * MÊME forme que la réponse REST de `MessagingService.messages()` : le client peut l'ajouter
 * DIRECTEMENT au fil, sans round-trip REST. `isMine` est calculé CÔTÉ SERVEUR par destinataire
 * (la trame étant émise à la fois au destinataire et à l'expéditeur multi-device, chacun reçoit
 * sa propre vue de `isMine`).
 */
export interface RealtimeDmMessage {
  id: string;
  senderId: string;
  body: string;
  /** Horodatage d'envoi (ISO). `sentAt` est un alias explicite pour le client (cf. REST). */
  createdAt: string;
  sentAt: string;
  /** Accusé de lecture (ISO) ou null tant que non lu — null à l'instant de l'envoi. */
  readAt: string | null;
  /** Vue propre au destinataire de la trame : ce message est-il le sien ? */
  isMine: boolean;
}

/**
 * Événement poussé au client. Champ `type` discriminant pour évolutions sans casse :
 * - `dm`     : un message vient d'être enregistré dans la conversation. La trame porte désormais
 *              le `message` COMPLET (Incrément 1) → le client l'ajoute DIRECTEMENT au fil, SANS
 *              round-trip REST. `message` reste optionnel : son absence fait retomber le client
 *              sur le repli historique (refetch REST), garantissant la rétro-compatibilité.
 * - `read`   : le destinataire a OUVERT la conversation et marqué les messages lus → l'EXPÉDITEUR
 *              fait passer son fil « Envoyé » → « Lu » sans attendre le poll.
 * - `typing` : l'autre participant est en train d'écrire (éphémère, AUCUNE persistance ; le client
 *              affiche un indicateur qui s'éteint tout seul après quelques secondes sans signal).
 */
export interface RealtimeEvent {
  type: "dm" | "read" | "typing";
  conversationId: string;
  /** Présent UNIQUEMENT sur les events `dm` : le message complet à ajouter sans refetch. */
  message?: RealtimeDmMessage;
}

/**
 * Registre en mémoire `userId -> Set<socket>` (multi-onglets / multi-device) et émission best-effort.
 * Mono-instance : le registre est local au process (suffisant tant que l'API tourne en une instance ;
 * le passage multi-instance se fera via Redis Pub/Sub — le contrat d'`emitToUser` ne changera pas).
 */
/**
 * Handler du canal MONTANT « saisie » (client → serveur). Implémenté par la messagerie (qui a accès
 * à Prisma pour valider la participation) et branché ici à l'init pour éviter une dépendance de
 * module circulaire (MessagingModule → RealtimeModule). Best-effort : toute erreur est avalée.
 */
export type TypingHandler = (userId: string, conversationId: string) => void | Promise<void>;

@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  private readonly sockets = new Map<string, Set<RealtimeSocket>>();
  private typingHandler?: TypingHandler;

  /**
   * Branche le handler de saisie montant (appelé une fois à l'init par la messagerie). On évite
   * ainsi que le gateway dépende de la messagerie (couplage de modules) : il délègue ici.
   */
  setTypingHandler(handler: TypingHandler): void {
    this.typingHandler = handler;
  }

  /**
   * Reçoit un signal de saisie d'un client authentifié (`userId` validé au handshake) et le délègue
   * au handler branché par la messagerie (validation de participation + relais à l'autre). No-op si
   * aucun handler n'est branché ou si `conversationId` est absent. JAMAIS bloquant / lançant.
   */
  handleClientTyping(userId: string, conversationId: string): void {
    if (!this.typingHandler || !conversationId) return;
    try {
      void Promise.resolve(this.typingHandler(userId, conversationId)).catch((err) => {
        this.logger.debug(`handleClientTyping: relais échoué (${(err as Error).message})`);
      });
    } catch (err) {
      this.logger.debug(`handleClientTyping: relais échoué (${(err as Error).message})`);
    }
  }

  /** Enregistre une socket pour un utilisateur (après validation du token). */
  register(userId: string, socket: RealtimeSocket): void {
    let set = this.sockets.get(userId);
    if (!set) {
      set = new Set();
      this.sockets.set(userId, set);
    }
    set.add(socket);
  }

  /** Retire une socket ; supprime la clé si l'utilisateur n'a plus aucune socket. */
  unregister(userId: string, socket: RealtimeSocket): void {
    const set = this.sockets.get(userId);
    if (!set) return;
    set.delete(socket);
    if (set.size === 0) this.sockets.delete(userId);
  }

  /** Nombre de sockets ouvertes pour un utilisateur (0 si déconnecté). Utilitaire/tests. */
  socketCount(userId: string): number {
    return this.sockets.get(userId)?.size ?? 0;
  }

  /**
   * Pousse un événement à TOUTES les sockets ouvertes de `userId`. Best-effort, JAMAIS bloquant :
   * no-op si l'utilisateur n'a aucune socket, et toute erreur d'envoi sur une socket est avalée
   * (le temps réel est un bonus ; la source de vérité reste REST + la notif push).
   */
  emitToUser(userId: string, event: RealtimeEvent): void {
    const set = this.sockets.get(userId);
    if (!set || set.size === 0) return;
    const payload = JSON.stringify(event);
    for (const socket of set) {
      if (socket.readyState !== WS_OPEN) continue;
      try {
        socket.send(payload);
      } catch (err) {
        this.logger.debug(`emitToUser: envoi échoué pour ${userId} (${(err as Error).message})`);
      }
    }
  }
}
