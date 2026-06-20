import { ConflictException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService } from "../profile/profile-scoring.service";
import type { UpdateMeRequest } from "./me.dto";

@Injectable()
export class MeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly profileScoring: ProfileScoringService,
  ) {}

  /** Met à jour le profil. Un changement d'objectif recalcule l'Index (pondération par objectif). */
  async update(userId: string, req: UpdateMeRequest): Promise<unknown> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    if (req.displayName !== undefined) {
      const displayName = req.displayName.trim();
      const taken = await this.prisma.profile.findUnique({ where: { displayName } });
      if (taken && taken.userId !== userId) {
        throw new ConflictException({ code: "CONFLICT", message: "Ce pseudo est déjà pris." });
      }
    }

    const goalChanged = req.goal !== undefined && req.goal !== profile.goal;

    const updated = await this.prisma.profile.update({
      where: { userId },
      data: {
        ...(req.displayName !== undefined ? { displayName: req.displayName.trim() } : {}),
        ...(req.goal !== undefined ? { goal: req.goal } : {}),
        ...(req.equipmentPref !== undefined ? { equipmentPref: req.equipmentPref } : {}),
      },
    });

    // L'objectif change la pondération de l'Index → on recalcule à partir des efforts persistés.
    if (goalChanged) {
      await this.profileScoring.recomputeForUser(userId).catch(() => undefined);
    }

    return {
      displayName: updated.displayName,
      sex: updated.sex,
      goal: updated.goal,
      equipmentPref: updated.equipmentPref,
      rank: updated.rank,
    };
  }
}
