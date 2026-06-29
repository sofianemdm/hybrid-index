import { Global, Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { JwtAuthGuard } from "./jwt-auth.guard";
import { OptionalJwtAuthGuard } from "./optional-jwt-auth.guard";
import { GoogleTokenVerifier } from "./google-verifier";
import { AuthTokenService } from "./auth-token.service";

/**
 * Auth email + mot de passe (bcrypt) + JWT. OAuth Apple/Google différé (credentials externes).
 * Global pour que JwtModule/JwtAuthGuard soient injectables par les modules protégés.
 */
/** Secret JWT : obligatoire en production (refus de démarrer avec un secret par défaut public). */
function resolveJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (secret) return secret;
  if (process.env.NODE_ENV === "production") {
    throw new Error("JWT_SECRET est obligatoire en production.");
  }
  return "dev-secret-hybrid-index-not-for-prod";
}

@Global()
@Module({
  imports: [
    JwtModule.register({
      secret: resolveJwtSecret(),
      signOptions: { expiresIn: "30d" },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, AuthTokenService, JwtAuthGuard, OptionalJwtAuthGuard, GoogleTokenVerifier],
  exports: [AuthTokenService, JwtAuthGuard, OptionalJwtAuthGuard, JwtModule],
})
export class AuthModule {}
