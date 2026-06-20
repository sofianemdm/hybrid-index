import { Body, Controller, Post } from "@nestjs/common";
import { ZodValidationPipe } from "../../common/zod-validation.pipe";
import { AuthService } from "./auth.service";
import { type AuthResponse, GoogleAuthRequest, LoginRequest, RegisterRequest } from "./auth.dto";

@Controller("v1/auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post("register")
  register(@Body(new ZodValidationPipe(RegisterRequest)) body: RegisterRequest): Promise<AuthResponse> {
    return this.auth.register(body);
  }

  @Post("login")
  login(@Body(new ZodValidationPipe(LoginRequest)) body: LoginRequest): Promise<AuthResponse> {
    return this.auth.login(body);
  }

  /** Connexion / inscription via Google (nécessite GOOGLE_CLIENT_ID côté serveur). */
  @Post("google")
  google(
    @Body(new ZodValidationPipe(GoogleAuthRequest)) body: GoogleAuthRequest,
  ): Promise<AuthResponse & { isNew: boolean }> {
    return this.auth.google(body);
  }
}
