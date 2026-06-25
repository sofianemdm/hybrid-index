import { ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import type { EnrollResponse } from "./league.dto";

/** Inscription OPT-IN à la saison de Ligue active. Au lancement : filière bodyweight, niveau rx. */
@Injectable()
export class LeagueEnrollmentService {
  constructor(private readonly prisma: PrismaService) {}

  async enroll(userId: string): Promise<EnrollResponse> {
    const profile = await this.prisma.profile.findUnique({ where: { userId }, select: { sex: true } });
    if (!profile) {
      throw new ForbiddenException({ code: "PROFILE_REQUIRED", message: "Profil requis pour rejoindre la Ligue." });
    }
    const season = await this.prisma.leagueSeason.findFirst({ where: { status: "active" } });
    if (!season) {
      throw new NotFoundException({ code: "NO_ACTIVE_SEASON", message: "Aucune saison de Ligue en cours." });
    }
    await this.prisma.leagueEntry.upsert({
      where: { seasonId_userId: { seasonId: season.id, userId } },
      create: { seasonId: season.id, userId, sex: profile.sex, filiere: "bodyweight", level: "rx" },
      update: {},
    });
    return { seasonId: season.id, enrolled: true, sex: profile.sex };
  }

  async isEnrolled(userId: string, seasonId: string): Promise<boolean> {
    const entry = await this.prisma.leagueEntry.findUnique({
      where: { seasonId_userId: { seasonId, userId } },
      select: { userId: true },
    });
    return entry != null;
  }
}
