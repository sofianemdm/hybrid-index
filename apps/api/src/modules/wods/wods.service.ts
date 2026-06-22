import { Injectable, NotFoundException, UnprocessableEntityException } from "@nestjs/common";
import type { AttributeKey, Sex, WodType } from "@prisma/client";
import type { internalScore } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { ProfileScoringService, type PersistedProfile } from "../profile/profile-scoring.service";
import { FeedEventsService } from "../social/feed-events.service";
import { ProgressService } from "../progress/progress.service";
import { SCORING_VERSION_UUID } from "../../common/constants";
import type { EstimateWodRequest } from "./wod-estimate.dto";
import type { CreateWodRequest, LogWodResultRequest } from "./create-wod.dto";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { WOD_PRESCRIPTIONS } from "./wod-prescriptions.data";
import { WOD_REFERENCES } from "./wod-references.data";

/** Sous-score interne /1000 → note d'affichage /100 (null si absent). */
const ovrSub = (v: number | null): number | null => (v == null ? null : Math.round(ratingFromInternal(v)));

/** Les 4 séances PHARES (marquee benchmarks) — mises en avant, où tout le monde se mesure. */
export const FLAGSHIP_WOD_IDS = ["hyrox_sprint", "grace", "benchmark_zero", "ergo_skill"];
/** Épreuves « Autre » : jouables et classées, mais rangées à part de l'écran Séances. */
export const OTHER_WOD_IDS = ["hyrox_solo", "isabel", "murph", "track_10000m", "half_marathon", "marathon"];

/** WODs présents en base (FK des résultats) mais MASQUÉS du catalogue/des séances. `run_free_distance`
 *  reste le mécanisme interne de la course d'onboarding (distance libre + Riegel), pas une séance. */
export const HIDDEN_WOD_IDS = ["run_free_distance"];

@Injectable()
export class WodsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly profileScoring: ProfileScoringService,
    private readonly feedEvents: FeedEventsService,
    private readonly progress: ProgressService,
  ) {}

  /** Crée un WOD personnalisé (attributs ciblés dérivés du moteur d'estimation). */
  async create(userId: string, body: CreateWodRequest): Promise<unknown> {
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
    return this.detail(wod.id, userId);
  }

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
      });
      subScore = scored.subScore;
      percentile = scored.percentile;
      attributesAffected = scored.attributesAffected as AttributeKey[];
    }

    const created = await this.prisma.wodResult.create({
      data: {
        userId,
        wodId,
        sex: profile.sex,
        rawResult: body.rawResult,
        distanceMeters: body.distanceMeters ?? null,
        subScore,
        percentile,
        attributesAffected,
        source: "declared",
        scoringVersionId: SCORING_VERSION_UUID,
        rxCompliant: body.rxCompliant ?? true,
        performedAt: new Date(),
      },
    });
    await this.prisma.wod.update({ where: { id: wodId }, data: { resultCount: { increment: 1 } } });
    const recomputed = await this.profileScoring.recomputeForUser(userId);

    // Feed : PR (nouveau meilleur) ou simple log.
    const best = await this.prisma.wodResult.aggregate({
      where: { userId, wodId, review: "ok", subScore: { not: null } },
      _max: { subScore: true },
    });
    const isPr = subScore !== null && best._max.subScore === subScore;
    await this.feedEvents.emit(userId, isPr ? "pr" : "wod_logged", {
      wodId,
      wodName: wod.name,
      subScore,
      rawResult: body.rawResult,
    });

    // Classement de progression hebdo (B1) — best-effort.
    await this.progress
      .awardForResult(userId, created.sex, {
        wodResultId: created.id,
        wodId,
        subScore,
        performedAt: created.performedAt,
      })
      .catch(() => undefined);

    return {
      result: { id: created.id, wodId, rawResult: body.rawResult, subScore: ovrSub(subScore), rxCompliant: created.rxCompliant },
      profile: recomputed,
    };
  }

  /** Catalogue public des mouvements (pour le builder). */
  movements(): Promise<internalScore.MovementSummary[]> {
    return this.scoreClient.getMovements();
  }

  /** Estimation ad-hoc d'un WOD décomposé (aperçu live du builder). */
  estimate(req: EstimateWodRequest): Promise<internalScore.ComputeEstimateResponse> {
    return this.scoreClient.computeEstimate(req);
  }

  /** Catalogue des WODs (15 références + communautaires à venir). */
  /** Séances minimales (set cover glouton) couvrant les attributs encore NON débloqués, afin de
   *  révéler l'Index complet. Exclut les épreuves « Autre » et les WODs custom ; privilégie le
   *  sans-matériel à couverture égale. */
  async completionPlan(
    userId: string,
  ): Promise<{ missing: string[]; sessions: Array<{ wodId: string; name: string; requiresEquipment: boolean; covers: string[] }> }> {
    const ATTRS: AttributeKey[] = ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"];
    const attrs = await this.prisma.attributeScore.findMany({ where: { userId }, select: { attribute: true, unlocked: true } });
    const unlocked = new Set(attrs.filter((a) => a.unlocked).map((a) => a.attribute));
    const remaining = new Set<string>(ATTRS.filter((a) => !unlocked.has(a)));
    const missing = [...remaining];
    if (remaining.size === 0) return { missing: [], sessions: [] };

    const wods = await this.prisma.wod.findMany({
      where: { isCustom: false, id: { notIn: [...OTHER_WOD_IDS, ...HIDDEN_WOD_IDS] } },
      select: { id: true, name: true, requiresEquipment: true, targetAttributes: true },
      orderBy: { requiresEquipment: "asc" }, // à couverture égale, le sans-matériel d'abord
    });

    const sessions: Array<{ wodId: string; name: string; requiresEquipment: boolean; covers: string[] }> = [];
    const chosen = new Set<string>();
    while (remaining.size > 0) {
      let best: (typeof wods)[number] | null = null;
      let bestCover: string[] = [];
      for (const w of wods) {
        if (chosen.has(w.id)) continue;
        const cover = (w.targetAttributes as string[]).filter((t) => remaining.has(t));
        if (cover.length > bestCover.length) {
          best = w;
          bestCover = cover;
        }
      }
      if (!best || bestCover.length === 0) break;
      chosen.add(best.id);
      sessions.push({ wodId: best.id, name: best.name, requiresEquipment: best.requiresEquipment, covers: bestCover });
      bestCover.forEach((c) => remaining.delete(c));
    }
    return { missing, sessions };
  }

  async catalog(): Promise<unknown[]> {
    const wods = await this.prisma.wod.findMany({
      where: { id: { notIn: HIDDEN_WOD_IDS } },
      orderBy: [{ requiresEquipment: "asc" }, { name: "asc" }],
    });
    return wods.map((w) => ({
      id: w.id,
      name: w.name,
      type: w.type,
      scoreType: w.scoreType,
      requiresEquipment: w.requiresEquipment,
      targetAttributes: w.targetAttributes,
      isBenchmark: w.isBenchmark,
      isFlagship: FLAGSHIP_WOD_IDS.includes(w.id),
      isOther: OTHER_WOD_IDS.includes(w.id),
      isCustom: w.isCustom,
    }));
  }

  /** Fiche détaillée : métadonnées + paliers de référence (score-service) + ton meilleur effort. */
  async detail(id: string, userId?: string): Promise<unknown> {
    const wod = await this.prisma.wod.findUnique({ where: { id } });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });

    let levels: unknown = null;
    try {
      levels = await this.scoreClient.getWodLevels(id);
    } catch {
      levels = null; // WOD communautaire (pas de paliers officiels) ou score-service indisponible
    }

    let myBest: unknown = null;
    let myHistory: unknown[] = [];
    if (userId) {
      const baseWhere = { userId, wodId: id, review: "ok" as const, subScore: { not: null } };
      const [best, mine] = await Promise.all([
        // Meilleur effort sur TOUT l'historique (la donnée de fierté ne doit jamais régresser).
        this.prisma.wodResult.findFirst({ where: baseWhere, orderBy: { subScore: "desc" } }),
        // Les 30 prestations les plus récentes (affichage de l'historique).
        this.prisma.wodResult.findMany({ where: baseWhere, orderBy: { performedAt: "desc" }, take: 30 }),
      ]);
      myHistory = mine.map((r) => ({
        rawResult: Number(r.rawResult),
        subScore: ovrSub(r.subScore),
        rxCompliant: r.rxCompliant,
        performedAt: r.performedAt.toISOString(),
      }));
      if (best) {
        myBest = {
          rawResult: Number(best.rawResult),
          subScore: ovrSub(best.subScore),
          performedAt: best.performedAt.toISOString(),
        };
      }
    }

    return {
      id: wod.id,
      name: wod.name,
      type: wod.type,
      scoreType: wod.scoreType,
      requiresEquipment: wod.requiresEquipment,
      targetAttributes: wod.targetAttributes,
      isBenchmark: wod.isBenchmark,
      isFlagship: FLAGSHIP_WOD_IDS.includes(wod.id),
      isCustom: wod.isCustom,
      levels,
      myBest,
      myHistory, // mes prestations passées sur cette séance (récent → ancien)
      // Énoncé concret de la séance (mouvements + poids) pour les WODs de référence.
      prescription: WOD_PRESCRIPTIONS[wod.id] ?? null,
      // Cibles « Référence Pro » (données publiques) à viser sur cette séance.
      references: WOD_REFERENCES[wod.id] ?? [],
    };
  }

  /** Classement d'un WOD (meilleur effort par utilisateur, par sexe, variante Rx ou Scaled). */
  async leaderboard(id: string, sex: string, rx: boolean, userId?: string, memberIds?: string[]): Promise<unknown> {
    // Classement par PERFORMANCE RÉELLE (même WOD, même sexe, même variante) : le temps le plus bas
    // gagne pour un WOD chronométré, le plus de reps/charge sinon. On NE trie PAS sur subScore : il
    // peut diverger du temps réel pour les comptes de démonstration → l'ordre paraîtrait incohérent
    // avec les temps affichés. Le tri sur la perf brute est toujours cohérent avec l'affichage.
    const wod = await this.prisma.wod.findUnique({ where: { id }, select: { scoreType: true } });
    const better: "asc" | "desc" = wod?.scoreType === "time" ? "asc" : "desc";
    const rows = await this.prisma.wodResult.findMany({
      where: {
        wodId: id,
        sex: sex as Sex,
        review: "ok",
        subScore: { not: null },
        rxCompliant: rx,
        ...(memberIds ? { userId: { in: memberIds } } : {}), // filtre « Mon club » (C3)
      },
      orderBy: [{ rawResult: better }],
      distinct: ["userId"], // meilleur effort par utilisateur (premier dans l'ordre = sa meilleure perf)
      take: 100,
      select: { userId: true, subScore: true, rawResult: true },
    });
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: rows.map((r) => r.userId) } },
      select: { userId: true, displayName: true, rank: true },
    });
    const names = new Map(profiles.map((p) => [p.userId, p]));
    return {
      wodId: id,
      sex,
      entries: rows.map((r, i) => ({
        position: i + 1,
        userId: r.userId,
        displayName: names.get(r.userId)?.displayName ?? "—",
        rank: names.get(r.userId)?.rank ?? "rookie",
        rawResult: Number(r.rawResult),
        subScore: ovrSub(r.subScore),
        isMe: r.userId === userId,
      })),
    };
  }
}
