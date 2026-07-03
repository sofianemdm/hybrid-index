import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import type { AttributeKey, Sex, WodType } from "@prisma/client";
import type { internalScore } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import type { EstimateWodRequest } from "./wod-estimate.dto";
import type { CreateWodRequest } from "./create-wod.dto";
import { WodCatalogService } from "./wod-catalog.service";

/**
 * CONSTRUCTEUR de séances communautaires — extrait de l'ex-wods.service (752 lignes) au découpage
 * du 03/07 : création/édition/suppression des WODs custom + estimation ad-hoc (aperçu du builder).
 * La LECTURE (catalogue/fiche) vit dans WodCatalogService ; le log de résultat dans WodsService.
 */
@Injectable()
export class WodBuilderService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly catalog: WodCatalogService, // create/update renvoient la fiche détaillée
  ) {}

  /** Garde-fou anti-spam de création de WOD : nb max de WODs custom créés par un utilisateur sur une
   *  heure glissante. @nestjs/throttler n'est pas configuré → garde-fou applicatif (count createdAt). */
  static readonly MAX_CUSTOM_WODS_PER_HOUR = 10;

  /** Estimation ad-hoc d'un WOD décomposé (aperçu live du builder). */
  estimate(req: EstimateWodRequest): Promise<internalScore.ComputeEstimateResponse> {
    return this.scoreClient.computeEstimate(req);
  }

  /** Crée un WOD personnalisé (attributs ciblés dérivés du moteur d'estimation). */
  async create(userId: string, body: CreateWodRequest): Promise<unknown> {
    // Anti-abus : refuse si l'utilisateur a déjà créé trop de WODs sur la dernière heure (spam /
    // pollution du catalogue communautaire). Pas de throttler global dans l'app → contrôle applicatif.
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentCount = await this.prisma.wod.count({
      where: { createdById: userId, isCustom: true, createdAt: { gte: oneHourAgo } },
    });
    if (recentCount >= WodBuilderService.MAX_CUSTOM_WODS_PER_HOUR) {
      throw new BadRequestException({
        code: "RATE_LIMIT",
        message: "Trop de séances créées récemment. Réessaie dans un moment.",
      });
    }

    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    const sex = (profile?.sex ?? "male") as Sex;
    const est = await this.scoreClient.computeEstimate({
      sex,
      scoreType: body.scoreType,
      wodType: body.type,
      timeCapSec: body.timeCapSec,
      rounds: body.rounds,
      blocks: body.blocks,
    });
    const targetAttributes = (est.attributesAffected.length > 0 ? est.attributesAffected : ["hybrid"]) as AttributeKey[];
    const wod = await this.prisma.wod.create({
      data: {
        name: body.name.trim(),
        isBenchmark: false,
        isCustom: true,
        createdById: userId,
        type: body.type as WodType,
        requiresEquipment: body.requiresEquipment,
        targetAttributes,
        scoreType: body.scoreType,
        movements: body.blocks,
        timeCapSec: body.timeCapSec ?? null,
        rounds: body.rounds ?? null,
        calibration: "estimated",
      },
    });
    return this.catalog.detail(wod.id, userId);
  }

  /** Charge un WOD et VÉRIFIE qu'il est éditable/supprimable par `userId` :
   *  - existe (404 sinon) ;
   *  - est bien communautaire (`isCustom`) — jamais un benchmark/officiel ni un WOD Ligue (403) ;
   *  - appartient à l'utilisateur (`createdById === userId`, 403 sinon).
   *  Renvoie le WOD pour réutilisation par update/remove. */
  private async assertOwnedCustomWod(userId: string, wodId: string): Promise<{ id: string; isCustom: boolean; createdById: string | null }> {
    const wod = await this.prisma.wod.findUnique({
      where: { id: wodId },
      select: { id: true, isCustom: true, createdById: true },
    });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });
    // Officiel / benchmark / Ligue : jamais modifiable (un WOD Ligue n'est de toute façon pas isCustom).
    if (!wod.isCustom) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Cette séance ne peut pas être modifiée." });
    }
    if (wod.createdById !== userId) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Seul le créateur peut modifier cette séance." });
    }
    return wod;
  }

  /** Met à jour un WOD communautaire (créateur uniquement). Réutilise la validation du DTO de
   *  création (mêmes bornes anti-abus) et recalcule les attributs ciblés via le moteur d'estimation,
   *  comme à la création. 403 si non-créateur ou WOD non-custom ; 404 si introuvable. */
  async update(userId: string, wodId: string, body: CreateWodRequest): Promise<unknown> {
    await this.assertOwnedCustomWod(userId, wodId);

    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    const sex = (profile?.sex ?? "male") as Sex;
    const est = await this.scoreClient.computeEstimate({
      sex,
      scoreType: body.scoreType,
      wodType: body.type,
      timeCapSec: body.timeCapSec,
      rounds: body.rounds,
      blocks: body.blocks,
    });
    const targetAttributes = (est.attributesAffected.length > 0 ? est.attributesAffected : ["hybrid"]) as AttributeKey[];
    await this.prisma.wod.update({
      where: { id: wodId },
      data: {
        name: body.name.trim(),
        type: body.type as WodType,
        requiresEquipment: body.requiresEquipment,
        targetAttributes,
        scoreType: body.scoreType,
        movements: body.blocks,
        timeCapSec: body.timeCapSec ?? null,
        rounds: body.rounds ?? null,
      },
    });
    return this.catalog.detail(wodId, userId);
  }

  /** Supprime un WOD communautaire (créateur uniquement). 403 si non-créateur ou WOD non-custom ;
   *  404 si introuvable. EFFETS : la relation `WodResult.wod` n'a PAS d'`onDelete: Cascade` (Restrict
   *  par défaut). Supprimer un WOD déjà loggé invaliderait des résultats/sous-scores comptés dans
   *  l'Index → on REFUSE explicitement (409) avec un message clair plutôt que de cascader et fausser
   *  les Index/classements. Tant qu'aucun résultat n'existe, la suppression est sûre. */
  async remove(userId: string, wodId: string): Promise<{ deleted: true }> {
    await this.assertOwnedCustomWod(userId, wodId);
    const resultCount = await this.prisma.wodResult.count({ where: { wodId } });
    if (resultCount > 0) {
      throw new ConflictException({
        code: "WOD_HAS_RESULTS",
        message: "Impossible de supprimer : des athlètes ont déjà enregistré un résultat sur cette séance.",
      });
    }
    await this.prisma.wod.delete({ where: { id: wodId } });
    return { deleted: true };
  }
}
