import { Body, Controller, Post } from "@nestjs/common";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { RateLimit } from "../../common/rate-limit.guard";
import { AuthService } from "./auth.service";
import { AppleAuthRequest, type AuthResponse, ForgotPasswordRequest, GoogleAuthRequest, LoginRequest, RegisterRequest, ResetPasswordRequest } from "./auth.dto";

@Controller("v1/auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  // Anti-abus : création de comptes en masse limitée par IP.
  // 30/h (relevé de 10 le 04/07) : une IP partagée (foyer, salle, école) ou une phase
  // de test dépassait 10 inscriptions/h → 429 injustes. 30 reste anti-spam.
  @RateLimit({ limit: 30, windowSec: 3600 })
  @Post("register")
  register(@Body(new ZodValidationPipe(RegisterRequest)) body: RegisterRequest): Promise<AuthResponse> {
    return this.auth.register(body);
  }

  // Anti brute-force : 20 tentatives / 15 min / IP.
  @RateLimit({ limit: 20, windowSec: 900 })
  @Post("login")
  login(@Body(new ZodValidationPipe(LoginRequest)) body: LoginRequest): Promise<AuthResponse> {
    return this.auth.login(body);
  }

  /** « Mot de passe oublié » : envoie un code par email. Réponse TOUJOURS { ok: true }
   *  (pas d'énumération d'emails). Anti-abus : 5 demandes / 15 min / IP. */
  @RateLimit({ limit: 5, windowSec: 900 })
  @Post("forgot")
  forgot(@Body(new ZodValidationPipe(ForgotPasswordRequest)) body: ForgotPasswordRequest): Promise<{ ok: true }> {
    return this.auth.forgotPassword(body);
  }

  /** Réinitialise le mot de passe avec le code reçu par email (erreur générique RESET_INVALID). */
  @RateLimit({ limit: 10, windowSec: 900 })
  @Post("reset")
  reset(@Body(new ZodValidationPipe(ResetPasswordRequest)) body: ResetPasswordRequest): Promise<{ ok: true }> {
    return this.auth.resetPassword(body);
  }

  /** Connexion / inscription via Apple (nécessite APPLE_BUNDLE_ID côté serveur). */
  @RateLimit({ limit: 20, windowSec: 900 })
  @Post("apple")
  apple(
    @Body(new ZodValidationPipe(AppleAuthRequest)) body: AppleAuthRequest,
  ): Promise<AuthResponse & { isNew: boolean }> {
    return this.auth.apple(body);
  }

  /** Connexion / inscription via Google (nécessite GOOGLE_CLIENT_ID côté serveur). */
  @RateLimit({ limit: 20, windowSec: 900 })
  @Post("google")
  google(
    @Body(new ZodValidationPipe(GoogleAuthRequest)) body: GoogleAuthRequest,
  ): Promise<AuthResponse & { isNew: boolean }> {
    return this.auth.google(body);
  }
}
