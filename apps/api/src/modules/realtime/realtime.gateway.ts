import { Logger } from "@nestjs/common";
import {
  type OnGatewayConnection,
  type OnGatewayDisconnect,
  type OnGatewayInit,
  WebSocketGateway,
} from "@nestjs/websockets";
import type { IncomingMessage } from "node:http";
import type { Server, WebSocket } from "ws";
import { AuthTokenService } from "../auth/auth-token.service";
import { RealtimeService } from "./realtime.service";

/** Code de fermeture applicatif (espace 4xxx) : token absent / invalide / compte inactif. */
const CLOSE_UNAUTHORIZED = 4401;
/** Intervalle du heartbeat (Railway/proxies coupent les sockets inactives). */
const HEARTBEAT_MS = 30_000;

/** Socket `ws` augmentée des métadonnées posées par le gateway. */
interface TrackedSocket extends WebSocket {
  userId?: string;
  isAlive?: boolean;
}

/** Origines autorisées au handshake : même liste que le CORS REST (`CORS_ORIGINS`), `*` en dev. */
function allowedOrigins(): string[] | "*" {
  const configured = process.env.CORS_ORIGINS;
  if (!configured) return "*"; // dev : parité avec le CORS REST (`*`).
  return configured.split(",").map((o) => o.trim()).filter(Boolean);
}

/**
 * Gateway WebSocket temps réel (raw `ws`, même port que l'API, chemin `/ws/messaging`).
 *
 * - Auth au handshake : token en query `?token=`, validé par `AuthTokenService` (MÊME secret et
 *   MÊME contrôle « compte actif » que REST). Échec ⇒ close `4401`.
 * - Origine vérifiée manuellement contre `CORS_ORIGINS` (le handshake WS n'est pas soumis au CORS fetch).
 * - Registre `userId -> Set<socket>` délégué à `RealtimeService` ; heartbeat ping/pong.
 *
 * Best-effort : toute erreur du gateway est isolée pour ne JAMAIS empêcher le boot de l'API ni
 * faire échouer un envoi REST.
 */
@WebSocketGateway({ path: "/ws/messaging" })
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(RealtimeGateway.name);
  private heartbeat?: ReturnType<typeof setInterval>;

  constructor(
    private readonly authToken: AuthTokenService,
    private readonly realtime: RealtimeService,
  ) {}

  afterInit(server: Server): void {
    // Heartbeat : on ping toutes les sockets ; celles sans `pong` au cycle précédent sont terminées.
    this.heartbeat = setInterval(() => {
      for (const client of server.clients) {
        const sock = client as TrackedSocket;
        if (sock.isAlive === false) {
          sock.terminate();
          continue;
        }
        sock.isAlive = false;
        try {
          sock.ping();
        } catch {
          // socket en cours de fermeture : ignore.
        }
      }
    }, HEARTBEAT_MS);
    // Ne pas maintenir le process en vie juste pour le heartbeat.
    this.heartbeat.unref?.();
  }

  async handleConnection(client: TrackedSocket, request: IncomingMessage): Promise<void> {
    // 1) Origine (handshake WS non soumis au CORS fetch → on contrôle nous-mêmes).
    const origin = request.headers.origin;
    const allowed = allowedOrigins();
    if (allowed !== "*" && origin != null && !allowed.includes(origin)) {
      this.logger.warn(`WS refusé : origine non autorisée (${origin})`);
      client.close(CLOSE_UNAUTHORIZED, "origin");
      return;
    }

    // 2) Token (query `?token=`).
    let token: string | null = null;
    try {
      const url = new URL(request.url ?? "", "http://localhost");
      token = url.searchParams.get("token");
    } catch {
      token = null;
    }

    // 3) Validation (MÊME logique que REST). Échec ⇒ close 4401, on NE retient pas la socket.
    let userId: string;
    try {
      const user = await this.authToken.verifyToken(token);
      userId = user.userId;
    } catch {
      client.close(CLOSE_UNAUTHORIZED, "unauthorized");
      return;
    }

    // 4) Enregistrement + heartbeat.
    client.userId = userId;
    client.isAlive = true;
    client.on("pong", () => {
      client.isAlive = true;
    });
    this.realtime.register(userId, client);
    this.logger.log(`WS connecté (user ${userId})`); // jamais l'URL/token, seulement l'userId validé.
  }

  handleDisconnect(client: TrackedSocket): void {
    if (client.userId) this.realtime.unregister(client.userId, client);
  }
}
