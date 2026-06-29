import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService } from "../profile/profile-scoring.service";
import type { UpdateAvatarRequest, UpdateMeRequest } from "./me.dto";
import { serializeAvatar } from "../../common/avatar.serializer";

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

  /** Met à jour le profil (objectif / matériel). Un changement d'objectif recalcule l'Index
   *  (pondération par objectif). Le pseudo (`displayName`) est figé après création → non modifiable
   *  ici (absent du DTO, rejeté en amont). */
  async update(userId: string, req: UpdateMeRequest): Promise<unknown> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    const goalChanged = req.goal !== undefined && req.goal !== profile.goal;

    const updated = await this.prisma.profile.update({
      where: { userId },
      data: {
        ...(req.goal !== undefined ? { goal: req.goal } : {}),
        ...(req.equipmentPref !== undefined ? { equipmentPref: req.equipmentPref } : {}),
        ...(req.locale !== undefined ? { locale: req.locale } : {}),
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

  async getAvatar(userId: string): Promise<unknown> {
    const avatar = await this.prisma.avatar.findUnique({ where: { userId } });
    // `GET /v1/me/avatar` renvoie un avatar par défaut (jamais null) pour préremplir l'éditeur ;
    // les listes publiques, elles, exposent `null` via serializeAvatar (repli côté mobile).
    return serializeAvatar(avatar) ?? DEFAULT_AVATAR;
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
