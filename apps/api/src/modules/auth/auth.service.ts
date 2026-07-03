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
import { randomInt } from "node:crypto";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { MailService } from "../../infra/mail/mail.service";
import { GoogleTokenVerifier } from "./google-verifier";
import { AppleTokenVerifier } from "./apple-verifier";
import type { AppleAuthRequest, AuthResponse, ForgotPasswordRequest, GoogleAuthRequest, LoginRequest, RegisterRequest, ResetPasswordRequest } from "./auth.dto";

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
    private readonly appleVerifier: AppleTokenVerifier,
    private readonly mail: MailService,
  ) {}

  /** Fenêtre de validité et nombre d'essais d'un code de réinitialisation. */
  static readonly RESET_CODE_TTL_MS = 15 * 60 * 1000;
  static readonly RESET_CODE_MAX_ATTEMPTS = 5;
  /** Anti-spam : délai minimal entre deux demandes de code pour le même compte. */
  static readonly RESET_REQUEST_COOLDOWN_MS = 60 * 1000;

  /**
   * « Mot de passe oublié » : génère un code à 6 chiffres (haché bcrypt en base, 15 min, 5 essais),
   * l'envoie par email, et répond TOUJOURS { ok: true } — même si l'email est inconnu ou lié à un
   * compte Google sans mot de passe (aucune énumération d'emails possible).
   */
  async forgotPassword(req: ForgotPasswordRequest): Promise<{ ok: true }> {
    const email = req.email.toLowerCase().trim();
    const user = await this.prisma.user.findUnique({ where: { email }, select: { id: true, passwordHash: true } });
    // Compte inexistant OU compte social sans mot de passe → réponse identique, aucun envoi.
    if (!user?.passwordHash) return { ok: true };

    // Anti-spam : si un code a été émis il y a moins d'une minute, on ne renvoie rien (réponse
    // identique — l'utilisateur pressé retape sa demande sans donner d'indice à un attaquant).
    const last = await this.prisma.passwordResetCode.findFirst({
      where: { userId: user.id },
      orderBy: { createdAt: "desc" },
      select: { createdAt: true },
    });
    if (last && Date.now() - last.createdAt.getTime() < AuthService.RESET_REQUEST_COOLDOWN_MS) {
      return { ok: true };
    }

    const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
    const codeHash = await bcrypt.hash(code, 10);
    // Un seul code actif par compte : purge des anciens puis création.
    await this.prisma.$transaction([
      this.prisma.passwordResetCode.deleteMany({ where: { userId: user.id } }),
      this.prisma.passwordResetCode.create({
        data: { userId: user.id, codeHash, expiresAt: new Date(Date.now() + AuthService.RESET_CODE_TTL_MS) },
      }),
    ]);
    await this.mail.sendPasswordResetCode(email, code);
    return { ok: true };
  }

  /**
   * Réinitialise le mot de passe avec le code reçu par email. Erreur UNIQUE et générique
   * (RESET_INVALID) quel que soit l'échec — email inconnu, code faux, expiré ou trop d'essais —
   * pour ne rien révéler. Le compteur d'essais est incrémenté AVANT la comparaison (un code ne
   * peut pas être brute-forcé : 5 essais max sur 15 minutes).
   */
  async resetPassword(req: ResetPasswordRequest): Promise<{ ok: true }> {
    const invalid = new BadRequestException({ code: "RESET_INVALID", message: "Code invalide ou expiré." });
    const email = req.email.toLowerCase().trim();
    const user = await this.prisma.user.findUnique({ where: { email }, select: { id: true, passwordHash: true } });
    if (!user?.passwordHash) throw invalid;

    const row = await this.prisma.passwordResetCode.findFirst({
      where: { userId: user.id },
      orderBy: { createdAt: "desc" },
    });
    if (!row || row.expiresAt.getTime() < Date.now() || row.attempts >= AuthService.RESET_CODE_MAX_ATTEMPTS) {
      throw invalid;
    }
    await this.prisma.passwordResetCode.update({ where: { id: row.id }, data: { attempts: { increment: 1 } } });
    const match = await bcrypt.compare(req.code, row.codeHash);
    if (!match) throw invalid;

    const passwordHash = await bcrypt.hash(req.newPassword, 10);
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: user.id }, data: { passwordHash } }),
      this.prisma.passwordResetCode.deleteMany({ where: { userId: user.id } }),
    ]);
    return { ok: true };
  }

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

  /**
   * Connexion / inscription « Sign in with Apple » — miroir exact du flux Google :
   * identité connue → connexion ; email existant → liaison ; sinon création (profil requis,
   * age-gate). Particularités Apple : l'email vit dans l'identityToken (relais privé possible)
   * et peut être ABSENT d'un token de reconnexion — l'identité (sub) suffit alors.
   */
  async apple(req: AppleAuthRequest): Promise<AuthResponse & { isNew: boolean }> {
    const { sub, email } = await this.appleVerifier.verify(req.identityToken);

    // 1) Identité Apple déjà connue → connexion (l'email du token peut manquer : on a celui du compte).
    const identity = await this.prisma.authIdentity.findUnique({
      where: { provider_providerSubject: { provider: "apple", providerSubject: sub } },
      include: { user: { include: { profile: true } } },
    });
    if (identity) {
      return {
        ...this.sign(identity.userId, identity.user.email ?? email ?? "", identity.user.profile?.displayName ?? ""),
        isNew: false,
      };
    }

    // Sans identité connue, l'email est indispensable (liaison ou création de compte).
    if (!email) {
      throw new UnauthorizedException({ code: "UNAUTHENTICATED", message: "Token Apple sans email." });
    }

    // 2) Compte email existant → on lie l'identité Apple.
    const existingUser = await this.prisma.user.findUnique({ where: { email }, include: { profile: true } });
    if (existingUser) {
      await this.prisma.authIdentity.create({
        data: { userId: existingUser.id, provider: "apple", providerSubject: sub },
      });
      return { ...this.sign(existingUser.id, email, existingUser.profile?.displayName ?? ""), isNew: false };
    }

    // 3) Nouveau compte : profil requis (date de naissance pour l'age-gate, sexe pour le scoring).
    if (!req.profile) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: "Première connexion Apple : profil requis.",
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
          consents: { tos: true, provider: "apple", acceptedAt: new Date().toISOString() },
          identities: { create: { provider: "apple", providerSubject: sub } },
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
