import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ProfileScoringService } from "../profile/profile-scoring.service";
import type { UpdateAvatarRequest, UpdateMeRequest } from "./me.dto";
import { serializeAvatar } from "../../common/avatar.serializer";

/** Défaut renvoyé à l'éditeur quand l'utilisateur n'a pas encore d'avatar : avataaars neutre
 *  (l'éditeur ré-émet immédiatement un avatar complet avec seed + options par sexe). */
const DEFAULT_AVATAR = {
  photoData: null as string | null,
  diceStyle: "avataaars" as string | null,
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
