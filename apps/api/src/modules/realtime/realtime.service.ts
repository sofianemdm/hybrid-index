import { Injectable, Logger } from "@nestjs/common";

/** Socket minimale dont a besoin le registre (sous-ensemble de l'API `ws`). Permet de tester avec un mock. */
export interface RealtimeSocket {
  /** État de la connexion ; `1` = OPEN dans l'API `ws`/WebSocket. */
  readyState: number;
  send(data: string): void;
}

/** OPEN au sens de l'API WebSocket (`WebSocket.OPEN === 1`). */
const WS_OPEN = 1;

/** Événement poussé au client. Champ `type` discriminant pour évolutions sans casse (read/typing…). */
export interface RealtimeEvent {
  type: "dm";
  conversationId: string;
}

/**
 * Registre en mémoire `userId -> Set<socket>` (multi-onglets / multi-device) et émission best-effort.
 * Mono-instance : le registre est local au process (suffisant tant que l'API tourne en une instance ;
 * le passage multi-instance se fera via Redis Pub/Sub — le contrat d'`emitToUser` ne changera pas).
 */
@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  private readonly sockets = new Map<string, Set<RealtimeSocket>>();

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
