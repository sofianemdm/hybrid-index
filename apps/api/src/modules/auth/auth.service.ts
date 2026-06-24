import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { isOldEnough, MIN_AGE_YEARS } from "@hybrid-index/contracts";
import * as bcrypt from "bcryptjs";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { GoogleTokenVerifier } from "./google-verifier";
import type { AuthResponse, GoogleAuthRequest, LoginRequest, RegisterRequest } from "./auth.dto";

export interface JwtPayload {
  sub: string;
  email: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly googleVerifier: GoogleTokenVerifier,
  ) {}

  async register(req: RegisterRequest): Promise<AuthResponse> {
    // Age-gating (D4) : refus net avant toute écriture.
    if (!isOldEnough(req.dateOfBirth, new Date())) {
      throw new ForbiddenException({
        code: "AGE_RESTRICTED",
        message: `Âge minimum requis : ${MIN_AGE_YEARS} ans.`,
      });
    }

    const email = req.email.toLowerCase().trim();
    const displayName = req.displayName.trim();
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ConflictException({ code: "CONFLICT", message: "Cet email est déjà utilisé." });
    }
    const nameTaken = await this.prisma.profile.findUnique({ where: { displayName } });
    if (nameTaken) {
      throw new ConflictException({ code: "CONFLICT", message: "Ce pseudo est déjà pris." });
    }

    const passwordHash = await bcrypt.hash(req.password, 10);

    let user;
    try {
      user = await this.prisma.user.create({
        data: {
          email,
          passwordHash,
          dateOfBirth: req.dateOfBirth,
          ageVerified: true,
          consents: { tos: true, acceptedAt: new Date().toISOString() },
          identities: { create: { provider: "email", providerSubject: email } },
          profile: {
            create: {
              displayName,
              sex: req.sex,
              goal: req.goal,
              equipmentPref: req.equipmentPref,
            },
          },
        },
      });
    } catch (e) {
      throw this.uniqueViolation(e); // course email/pseudo concurrente → 409 ciblé (pas 500)
    }

    return this.sign(user.id, email, displayName);
  }

  /** Traduit une violation d'unicité Prisma (P2002, course concurrente sur email/pseudo) en
   *  ConflictException ciblée. Renvoie l'erreur d'origine si ce n'est pas un P2002. */
  private uniqueViolation(e: unknown): unknown {
    const err = e as { code?: string; meta?: { target?: string[] | string } };
    if (err?.code !== "P2002") return e;
    const target = Array.isArray(err.meta?.target) ? err.meta!.target.join(",") : String(err.meta?.target ?? "");
    if (target.includes("displayName")) {
      return new ConflictException({ code: "CONFLICT", message: "Ce pseudo est déjà pris." });
    }
    return new ConflictException({ code: "CONFLICT", message: "Cet email est déjà utilisé." });
  }

  async login(req: LoginRequest): Promise<AuthResponse> {
    const email = req.email.toLowerCase().trim();
    const user = await this.prisma.user.findUnique({ where: { email }, include: { profile: true } });
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Identifiants invalides." });
    }
    const ok = await bcrypt.compare(req.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Identifiants invalides." });
    }
    return this.sign(user.id, email, user.profile?.displayName ?? "");
  }

  /** Connexion / inscription via Google. Le profil n'est requis qu'à la première connexion. */
  async google(req: GoogleAuthRequest): Promise<AuthResponse & { isNew: boolean }> {
    const { sub, email: rawEmail } = await this.googleVerifier.verify(req.idToken);
    const email = rawEmail.toLowerCase().trim();

    // 1) Identité Google déjà connue → connexion.
    const identity = await this.prisma.authIdentity.findUnique({
      where: { provider_providerSubject: { provider: "google", providerSubject: sub } },
      include: { user: { include: { profile: true } } },
    });
    if (identity) {
      return { ...this.sign(identity.userId, email, identity.user.profile?.displayName ?? ""), isNew: false };
    }

    // 2) Compte email existant → on lie l'identité Google.
    const existingUser = await this.prisma.user.findUnique({ where: { email }, include: { profile: true } });
    if (existingUser) {
      await this.prisma.authIdentity.create({
        data: { userId: existingUser.id, provider: "google", providerSubject: sub },
      });
      return { ...this.sign(existingUser.id, email, existingUser.profile?.displayName ?? ""), isNew: false };
    }

    // 3) Nouveau compte : le profil (dont la date de naissance pour l'age-gate) est requis.
    if (!req.profile) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: "Première connexion Google : profil requis.",
        details: { needsProfile: true },
      });
    }
    if (!isOldEnough(req.profile.dateOfBirth, new Date())) {
      throw new ForbiddenException({ code: "AGE_RESTRICTED", message: `Âge minimum requis : ${MIN_AGE_YEARS} ans.` });
    }
    const displayName = req.profile.displayName.trim();
    const nameTaken = await this.prisma.profile.findUnique({ where: { displayName } });
    if (nameTaken) throw new ConflictException({ code: "CONFLICT", message: "Ce pseudo est déjà pris." });

    let user;
    try {
      user = await this.prisma.user.create({
        data: {
          email,
          dateOfBirth: req.profile.dateOfBirth,
          ageVerified: true,
          consents: { tos: true, provider: "google", acceptedAt: new Date().toISOString() },
          identities: { create: { provider: "google", providerSubject: sub } },
          profile: {
            create: {
              displayName,
              sex: req.profile.sex,
              goal: req.profile.goal,
              equipmentPref: req.profile.equipmentPref,
            },
          },
        },
      });
    } catch (e) {
      throw this.uniqueViolation(e);
    }
    return { ...this.sign(user.id, email, displayName), isNew: true };
  }

  private sign(id: string, email: string, displayName: string): AuthResponse {
    const payload: JwtPayload = { sub: id, email };
    return { token: this.jwt.sign(payload), user: { id, email, displayName } };
  }
}
