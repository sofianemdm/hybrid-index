import { Module } from "@nestjs/common";
import { RealtimeGateway } from "./realtime.gateway";
import { RealtimeService } from "./realtime.service";

/**
 * Temps réel WebSocket (signal de refresh des messages). `RealtimeService` (registre + émission)
 * est exporté pour que la messagerie y pousse ses events.
 * TEMPORAIRE (auth-rebuild) : l'ancienne dépendance `AuthModule` (validation JWT au handshake)
 * a été retirée avec l'auth. Le gateway utilise désormais un shim (voir realtime.gateway.ts).
 */
@Module({
  providers: [RealtimeGateway, RealtimeService],
  exports: [RealtimeService],
})
export class RealtimeModule {}
