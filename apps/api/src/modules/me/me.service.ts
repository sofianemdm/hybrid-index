import { ConflictException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService } from "../profile/profile-scoring.service";
import type { UpdateAvatarRequest, UpdateMeRequest } from "./me.dto";

const DEFAULT_AVATAR = {
  skinTone: 2,
  hairStyle: 1,
  hairColor: 1,
  beardStyle: null as number | null,
  accessory: 0,
  background: 0,
  photoData: null as string | null,
  diceStyle: null as string | null,
  diceSeed: null as string | null,
  diceOptions: null as Record<string, string> | null,
};

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

    let updated;
    try {
      updated = await this.prisma.profile.update({
        where: { userId },
        data: {
          ...(req.displayName !== undefined ? { displayName: req.displayName.trim() } : {}),
          ...(req.goal !== undefined ? { goal: req.goal } : {}),
          ...(req.equipmentPref !== undefined ? { equipmentPref: req.equipmentPref } : {}),
        },
      });
    } catch (e) {
      // Course concurrente sur le pseudo (P2002) après le findUnique ci-dessus → 409 ciblé.
      const err = e as { code?: string };
      if (err?.code === "P2002") {
        throw new ConflictException({ code: "CONFLICT", message: "Ce pseudo est déjà pris." });
      }
      throw e;
    }

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

  async getAvatar(userId: string): Promise<unknown> {
    const avatar = await this.prisma.avatar.findUnique({ where: { userId } });
    if (!avatar) return DEFAULT_AVATAR;
    return {
      skinTone: avatar.skinTone,
      hairStyle: avatar.hairStyle,
      hairColor: avatar.hairColor,
      beardStyle: avatar.beardStyle,
      accessory: avatar.accessory,
      background: avatar.background,
      photoData: avatar.photoData,
      diceStyle: avatar.diceStyle,
      diceSeed: avatar.diceSeed,
      diceOptions: avatar.diceOptions ? (JSON.parse(avatar.diceOptions) as Record<string, string>) : null,
    };
  }

  async updateAvatar(userId: string, req: UpdateAvatarRequest): Promise<unknown> {
    const data = {
      skinTone: req.skinTone,
      hairStyle: req.hairStyle,
      hairColor: req.hairColor,
      beardStyle: req.beardStyle ?? null,
      accessory: req.accessory ?? 0,
      background: req.background ?? 0,
      photoData: req.photoData ?? null,
      diceStyle: req.diceStyle ?? null,
      diceSeed: req.diceSeed ?? null,
      diceOptions: req.diceOptions ? JSON.stringify(req.diceOptions) : null,
    };
    await this.prisma.avatar.upsert({
      where: { userId },
      create: { userId, ...data, equippedCosmetics: {}, unlockedCosmetics: {} },
      update: data,
    });
    return data;
  }
}
