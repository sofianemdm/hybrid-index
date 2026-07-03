import { Injectable, NotFoundException, UnprocessableEntityException } from "@nestjs/common";
import type { AttributeKey } from "@prisma/client";
import type { internalScore } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { ProfileScoringService, type PersistedProfile } from "../profile/profile-scoring.service";
import { FeedEventsService } from "../social/feed-events.service";
import { ProgressService } from "../progress/progress.service";
import { LeaguePointsService } from "../league/league-points.service";
import { SCORING_VERSION_UUID } from "../../common/constants";
import type { LogWodResultRequest } from "./create-wod.dto";
import { ovrSub } from "./wod-constants";

/** LOG DE RÉSULTAT — l'ex-wods.service (752 lignes) a été découpé le 03/07 :
 *  lecture (catalogue/fiche/classement) → WodCatalogService ; création/édition custom →
 *  WodBuilderService ; constantes partagées → wod-constants. Ici ne reste que logResult. */
@Injectable()
export class WodsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly profileScoring: ProfileScoringService,
    private readonly feedEvents: FeedEventsService,
    private readonly progress: ProgressService,
    private readonly leaguePoints: LeaguePointsService,
  ) {}

  /** Logue un résultat sur un WOD (officiel → barème ; custom → moteur d'estimation), puis
   *  recalcule l'Index (no-drop, custom étiqueté estimé). */
  async logResult(
    userId: string,
    wodId: string,
    body: LogWodResultRequest,
  ): Promise<{ result: unknown; profile: PersistedProfile | null }> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });
    const wod = await this.prisma.wod.findUnique({ where: { id: wodId } });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });

    let subScore: number | null;
    let percentile: number | null;
    let attributesAffected: AttributeKey[];

    if (wod.isCustom) {
      const est = await this.scoreClient.computeEstimate({
        sex: profile.sex,
        scoreType: wod.scoreType,
        wodType: wod.type,
        timeCapSec: wod.timeCapSec ?? undefined,
        rounds: wod.rounds ?? undefined,
        blocks: wod.movements as internalScore.WodBlockInput[],
        userResult: body.rawResult,
      });
      if (est.outOfBounds) {
        throw new UnprocessableEntityException({
          code: "WOD_RESULT_OUT_OF_BOUNDS",
          message: "Résultat hors des bornes plausibles estimées pour ce WOD.",
        });
      }
      subScore = est.subScore;
      percentile = est.percentile;
      attributesAffected = est.attributesAffected as AttributeKey[];
    } else {
      const scored = await this.scoreClient.computeSubScore({
        wodId,
        sex: profile.sex,
        scoreType: wod.scoreType,
        rawResult: body.rawResult,
        distanceMeters: body.distanceMeters,
        scaled: body.rxCompliant === false, // non-Rx (mouvements adaptés) → décote côté score-service
      });
      subScore = scored.subScore;
      percentile = scored.percentile;
      attributesAffected = scored.attributesAffected as AttributeKey[];
    }

    // Anti-triche (cf. results.service / cahier §5.5) : saut > +30 % du sous-score vs meilleur effort
    // ALL-TIME ET résultat au niveau quasi-élite (percentile ≥ 0.85) → flaggé pending_review (exclu
    // des classements/Index). 1er effort jamais flaggé. Mêmes seuils que l'autre voie de log.
    const allTimeBest = await this.prisma.wodResult.aggregate({
      where: { userId, wodId, review: "ok", subScore: { not: null } },
      _max: { subScore: true },
    });
    const prevBest = allTimeBest._max.subScore;
    const isAnomaly =
      subScore !== null && prevBest != null && prevBest > 0 && subScore > prevBest * 1.3 && (percentile ?? 0) >= 0.85;

    const data = {
      userId,
      wodId,
      sex: profile.sex,
      rawResult: body.rawResult,
      distanceMeters: body.distanceMeters ?? null,
      subScore,
      percentile,
      attributesAffected,
      source: "declared" as const,
      scoringVersionId: SCORING_VERSION_UUID,
      rxCompliant: body.rxCompliant ?? true,
      performedAt: new Date(),
      review: (isAnomaly ? "pending_review" : "ok") as "pending_review" | "ok",
    };
    // Idempotent si une clé est fournie (retry réseau / double-tap mobile) → pas de doublon.
    const existing = body.idempotencyKey
      ? await this.prisma.wodResult.findUnique({
          where: { userId_idempotencyKey: { userId, idempotencyKey: body.idempotencyKey } },
          select: { id: true },
        })
      : null;
    const created = body.idempotencyKey
      ? await this.prisma.wodResult.upsert({
          where: { userId_idempotencyKey: { userId, idempotencyKey: body.idempotencyKey } },
          create: { ...data, idempotencyKey: body.idempotencyKey },
          update: {}, // rejoué → on NE modifie rien (le 1er enregistrement fait foi)
        })
      : await this.prisma.wodResult.create({ data });
    // N'incrémente le compteur QUE pour une vraie première écriture (jamais sur un rejeu idempotent).
    if (!existing) {
      await this.prisma.wod.update({ where: { id: wodId }, data: { resultCount: { increment: 1 } } });
    }
    const recomputed = await this.profileScoring.recomputeForUser(userId);

    // Feed : PR (nouveau meilleur) ou simple log. PAS d'événement sur un rejeu idempotent (sinon
    // double post dans le feed). Un effort flaggé anti-triche ne génère pas de PR non plus.
    const best = await this.prisma.wodResult.aggregate({
      where: { userId, wodId, review: "ok", subScore: { not: null } },
      _max: { subScore: true },
    });
    const isPr = !isAnomaly && subScore !== null && best._max.subScore === subScore;
    // Anti-spam feed : on ne poste QUE les PR (nouveau record). Un simple log ne génère
    // plus aucun événement « wod_logged » (aligné sur results.service). Pas de post sur rejeu.
    if (!existing && isPr) {
      await this.feedEvents.emit(userId, "pr", {
        wodId,
        wodName: wod.name,
        subScore,
        rawResult: body.rawResult,
      });
    }

    // Classement de progression hebdo (B1) — best-effort. Pas sur un rejeu.
    if (!existing)
      await this.progress
        .awardForResult(userId, created.sex, {
          wodResultId: created.id,
          wodId,
          subScore,
          performedAt: created.performedAt,
        })
      .catch(() => undefined);

    // Points de LIGUE mensuelle — best-effort, pas sur un rejeu. C'est LA voie utilisée par
    // l'app mobile : sans cet appel, faire le « WOD de la semaine » ne donnait AUCUN point
    // (seule l'autre voie, ResultsService.log, créditait la Ligue — bug vécu le 03/07 sur
    // La Flèche : l'utilisateur n'apparaissait jamais au classement du mois).
    if (!existing)
      await this.leaguePoints
        .awardForResult(userId, created.sex, {
          wodResultId: created.id,
          wodId,
          subScore,
          performedAt: created.performedAt,
          review: created.review,
        })
        .catch(() => undefined);

    return {
      result: { id: created.id, wodId, rawResult: body.rawResult, subScore: ovrSub(subScore), rxCompliant: created.rxCompliant },
      profile: recomputed,
    };
  }
}
