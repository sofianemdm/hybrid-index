import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { RealtimeGateway } from "./realtime.gateway";
import { RealtimeService } from "./realtime.service";

/**
 * Temps réel WebSocket (signal de refresh des messages). `RealtimeService` (registre + émission)
 * est exporté pour que la messagerie y pousse ses events. `AuthModule` est `@Global` (JwtModule),
 * mais on l'importe explicitement pour `AuthTokenService`.
 */
@Module({
  imports: [AuthModule],
  providers: [RealtimeGateway, RealtimeService],
  exports: [RealtimeService],
})
export class RealtimeModule {}
