import { ConflictException, ForbiddenException, Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { isOldEnough, MIN_AGE_YEARS } from "@hybrid-index/contracts";
import * as bcrypt from "bcryptjs";
import { PrismaService } from "../../infra/prisma/prisma.service";
import type { AuthResponse, LoginRequest, RegisterRequest } from "./auth.dto";

export interface JwtPayload {
  sub: string;
  email: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
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

    const user = await this.prisma.user.create({
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

    return this.sign(user.id, email, displayName);
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

  private sign(id: string, email: string, displayName: string): AuthResponse {
    const payload: JwtPayload = { sub: id, email };
    return { token: this.jwt.sign(payload), user: { id, email, displayName } };
  }
}
