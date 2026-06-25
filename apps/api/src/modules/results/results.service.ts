import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { ProfileScoringService, type PersistedProfile } from "../profile/profile-scoring.service";
import { StreakService } from "../engagement/streak.service";
import { BadgesService } from "../engagement/badges.service";
import { FeedEventsService } from "../social/feed-events.service";
import { ProgressService } from "../progress/progress.service";
import { LeaguePointsService } from "../league/league-points.service";
import type { BadgeDef } from "../engagement/badges.data";
import { SCORING_VERSION_UUID } from "../../common/constants";
import type { LogResultRequest } from "./results.dto";

export interface LogResultResponse {
  result: {
    id: string;
    wodId: string;
    rawResult: number;
    subScore: number | null;
    percentile: number | null;
    performedAt: string;
  };
  /** Profil recalculé (l'Index a pu bouger). */
  profile: PersistedProfile;
  /** Badges débloqués par ce log (pour célébration côté app). */
  unlockedBadges: BadgeDef[];
}

/**
 * Log d'un WOD : note l'effort via le score-service (bornes anti-triche §5.5),
 * persiste le résultat, puis recalcule l'Index/radar (no-drop). L'Index ne descend jamais
 * sur un moins bon résultat : le score-service garde le meilleur effort par attribut.
 */
@Injectable()
export class ResultsService {
  private readonly logger = new Logger(ResultsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly profileScoring: ProfileScoringService,
    private readonly streak: StreakService,
    private readonly badges: BadgesService,
    private readonly feedEvents: FeedEventsService,
    private readonly progress: ProgressService,
    private readonly league: LeaguePointsService,
  ) {}

  async log(userId: string, req: LogResultRequest): Promise<LogResultResponse> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    // Note l'effort (propage 422 si hors bornes physiologiques, 404 si WOD inconnu).
    const scored = await this.scoreClient.computeSubScore({
      wodId: req.wodId,
      sex: profile.sex,
      scoreType: req.scoreType,
      rawResult: req.rawResult,
      distanceMeters: req.distanceMeters,
    });

    // Heure SERVEUR (le client ne fournit plus performedAt) → empêche de truquer défis/streaks.
    const performedAt = new Date();

    // Anti-triche (décision verrouillée « justesse non négociable », cf. cahier §5.5). On flagge un
    // effort suspect en `pending_review` → exclu des classements/rivaux/badges/Index (tout filtre
    // review:'ok') jusqu'à revue. Signature de triche : un saut > +30 % du sous-score vs le MEILLEUR
    // effort ALL-TIME (pas seulement 7 j → ferme le trou du « tricheur patient ») ET un résultat qui
    // atterrit au niveau quasi-élite (percentile ≥ 0.85). La double condition évite de pénaliser un
    // débutant qui progresse vite vers un niveau encore moyen (p20→p50 : non flaggé). 1er effort
    // jamais flaggé (aucune base de comparaison).
    const allTimeBest = await this.prisma.wodResult.aggregate({
      where: { userId, wodId: req.wodId, review: "ok", subScore: { not: null } },
      _max: { subScore: true },
    });
    const prevBest = allTimeBest._max.subScore;
    const ANOMALY_RATIO = 1.3; // +30 %
    const ANOMALY_MIN_PERCENTILE = 0.85; // ne flagge que les sauts vers le quasi-élite
    const isAnomaly =
      prevBest != null &&
      prevBest > 0 &&
      scored.subScore > prevBest * ANOMALY_RATIO &&
      scored.percentile >= ANOMALY_MIN_PERCENTILE;

    const data = {
      wodId: req.wodId,
      sex: profile.sex,
      rawResult: req.rawResult,
      distanceMeters: req.distanceMeters ?? null,
      subScore: scored.subScore,
      percentile: scored.percentile,
      attributesAffected: scored.attributesAffected,
      source: "declared" as const,
      scoringVersionId: SCORING_VERSION_UUID,
      performedAt,
      review: (isAnomaly ? "pending_review" : "ok") as "pending_review" | "ok",
    };
    // Idempotent si une clé est fournie (retry réseau mobile) ; sinon création simple (historique).
    const created = req.idempotencyKey
      ? await this.prisma.wodResult.upsert({
          where: { userId_idempotencyKey: { userId, idempotencyKey: req.idempotencyKey } },
          create: { userId, idempotencyKey: req.idempotencyKey, ...data },
          update: data,
        })
      : await this.prisma.wodResult.create({ data: { userId, ...data } });

    const recomputed = await this.profileScoring.recomputeForUser(userId);
    if (!recomputed) throw new NotFoundException({ code: "NOT_FOUND", message: "Recalcul impossible." });

    // Feed : PR (nouveau meilleur sur ce WOD) ou simple log.
    const best = await this.prisma.wodResult.aggregate({
      where: { userId, wodId: req.wodId, review: "ok", subScore: { not: null } },
      _max: { subScore: true },
    });
    const wodMeta = await this.prisma.wod.findUnique({ where: { id: req.wodId }, select: { name: true } });
    const isPr = scored.subScore === best._max.subScore;
    await this.feedEvents.emit(userId, isPr ? "pr" : "wod_logged", {
      wodId: req.wodId,
      wodName: wodMeta?.name ?? req.wodId,
      subScore: scored.subScore,
      rawResult: req.rawResult,
    });

    // Engagement : met à jour la série et attribue les badges nouvellement mérités.
    // Best-effort : un échec ne doit pas faire échouer le log, mais on le LOGGE (pas de silence).
    await this.streak.evaluateAndGet(userId).catch((e) => this.logger.warn(`Streak échouée (${userId}) : ${e}`));
    const unlockedBadges = await this.badges.evaluate(userId).catch((e) => {
      this.logger.warn(`Badges échoués (${userId}) : ${e}`);
      return [] as BadgeDef[];
    });
    // Classement de progression hebdomadaire (B1) — best-effort.
    await this.progress
      .awardForResult(userId, profile.sex, {
        wodResultId: created.id,
        wodId: req.wodId,
        subScore: scored.subScore,
        performedAt: created.performedAt,
      })
      .catch((e) => this.logger.warn(`Progress échoué (${userId}) : ${e}`));

    // Synergie « 1 log → 2 usages » : le même résultat alimente aussi la Ligue mensuelle (best-effort).
    await this.league
      .awardForResult(userId, profile.sex, {
        wodResultId: created.id,
        wodId: req.wodId,
        subScore: scored.subScore,
        performedAt: created.performedAt,
        review: created.review,
      })
      .catch((e) => this.logger.warn("Ligue échouée (" + userId + ") : " + e));

    return {
      result: {
        id: created.id,
        wodId: created.wodId,
        rawResult: Number(created.rawResult),
        subScore: created.subScore == null ? null : Math.round(ratingFromInternal(created.subScore)), // /100
        percentile: created.percentile === null ? null : Number(created.percentile),
        performedAt: created.performedAt.toISOString(),
      },
      profile: recomputed,
      unlockedBadges,
    };
  }

  /** Supprime un résultat (propriété vérifiée) puis recalcule l'Index/radar (no-drop respecté). */
  async remove(userId: string, id: string): Promise<{ deleted: true; profile: PersistedProfile | null }> {
    const res = await this.prisma.wodResult.findUnique({ where: { id }, select: { userId: true } });
    if (!res || res.userId !== userId) {
      throw new NotFoundException({ code: "NOT_FOUND", message: "Résultat introuvable." });
    }
    await this.prisma.wodResult.delete({ where: { id } });
    // Le recalcul de l'Index (2 appels HTTP au score-service) est best-effort : la suppression a
    // déjà réussi, on ne doit JAMAIS renvoyer une erreur à l'utilisateur si le recalcul blip.
    let profile: PersistedProfile | null = null;
    try {
      profile = await this.profileScoring.recomputeForUser(userId);
    } catch (e) {
      this.logger.warn(`Recalcul après suppression échoué (${userId}/${id}) : ${e}`);
    }
    return { deleted: true, profile };
  }

  async list(userId: string): Promise<unknown[]> {
    const rows = await this.prisma.wodResult.findMany({
      where: { userId },
      orderBy: { performedAt: "desc" },
      take: 50,
      include: { wod: { select: { name: true, scoreType: true } } },
    });
    return rows.map((r) => ({
      id: r.id,
      wodId: r.wodId,
      wodName: r.wod.name,
      scoreType: r.wod.scoreType,
      rawResult: Number(r.rawResult),
      subScore: r.subScore == null ? null : Math.round(ratingFromInternal(r.subScore)), // /100
      percentile: r.percentile === null ? null : Number(r.percentile),
      performedAt: r.performedAt.toISOString(),
    }));
  }

  /** Records personnels : le meilleur effort (par sous-score) de chaque WOD loggé (A8 — PR Wall). */
  async personalRecords(userId: string): Promise<unknown[]> {
    const rows = await this.prisma.wodResult.findMany({
      where: { userId, review: "ok", subScore: { not: null } },
      orderBy: [{ subScore: "desc" }, { performedAt: "asc" }],
      include: { wod: { select: { name: true, scoreType: true } } },
    });
    const best = new Map<string, (typeof rows)[number]>();
    for (const r of rows) if (!best.has(r.wodId)) best.set(r.wodId, r);
    return [...best.values()].map((r) => ({
      wodId: r.wodId,
      wodName: r.wod.name,
      scoreType: r.wod.scoreType,
      rawResult: Number(r.rawResult),
      subScore: r.subScore == null ? 0 : Math.round(ratingFromInternal(r.subScore)), // /100
      performedAt: r.performedAt.toISOString(),
    }));
  }
}
