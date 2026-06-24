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
import type { WodPrescription } from "./wod-prescription.types";
import { WOD_REFERENCES } from "./wod-references.data";

/** Sous-score interne /1000 → note d'affichage /100 (null si absent). */
const ovrSub = (v: number | null): number | null => (v == null ? null : Math.round(ratingFromInternal(v)));

/** Les 4 séances PHARES (marquee benchmarks) — mises en avant, où tout le monde se mesure. */
export const FLAGSHIP_WOD_IDS = ["hyrox_sprint", "grace", "benchmark_zero", "ergo_skill"];
/** Épreuves « Autre » : jouables et classées, mais rangées à part de l'écran Séances. */
export const OTHER_WOD_IDS = ["hyrox_solo", "isabel", "murph", "track_10000m", "half_marathon", "marathon"];

/** WODs présents en base (FK des résultats) mais MASQUÉS du catalogue/des séances. `run_free_distance`
 *  reste le mécanisme interne de la course d'onboarding (distance libre + Riegel), pas une séance.
 *  `max_air_squats` (« une série ») : retiré des séances (le 2 min `max_air_squats_2min` reste). */
export const HIDDEN_WOD_IDS = ["run_free_distance", "max_air_squats"];

/** Attributs qu'un WOD ne donne qu'en ESTIMÉ (proxy poids du corps, ou séance d'estimation
 *  globale) : ils ne « comptent » donc PAS pour préciser cette qualité dans le plan de complétion
 *  (sinon on re-proposerait à l'infini une séance qui ne mesure pas vraiment l'attribut). */
const ESTIMATED_COVERAGE: Record<string, string[]> = {
  max_pushups: ["strength"],
  max_air_squats: ["strength"],
  profil_express: ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"],
};

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
    if (!existing) {
      await this.feedEvents.emit(userId, isPr ? "pr" : "wod_logged", {
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
    const attrs = await this.prisma.attributeScore.findMany({ where: { userId }, select: { attribute: true, unlocked: true, isEstimated: true } });
    // « À faire » = attribut verrouillé OU encore ESTIMÉ (ex. après Profil Express) : on propose des
    // séances ciblées pour le mesurer pour de vrai et préciser la note.
    const done = new Set(attrs.filter((a) => a.unlocked && !a.isEstimated).map((a) => a.attribute));
    const remaining = new Set<string>(ATTRS.filter((a) => !done.has(a)));
    const missing = [...remaining];
    if (remaining.size === 0) return { missing: [], sessions: [] };

    const wods = await this.prisma.wod.findMany({
      // On exclut « Autre », masqués, ET profil_express (il ne donne que de l'ESTIMÉ → ne précise rien).
      where: { isCustom: false, id: { notIn: [...OTHER_WOD_IDS, ...HIDDEN_WOD_IDS, "profil_express"] } },
      select: { id: true, name: true, requiresEquipment: true, targetAttributes: true },
      orderBy: { requiresEquipment: "asc" }, // à couverture égale, le sans-matériel d'abord
    });

    const sessions: Array<{ wodId: string; name: string; requiresEquipment: boolean; covers: string[] }> = [];
    const chosen = new Set<string>();
    // Nouvel arrivant : radar encore LARGEMENT incomplet (≥ 3 des 6 qualités non mesurées pour de
    // vrai) ET « Profil Express » pas encore fait → on le conseille EN PREMIER : une seule séance
    // sans matériel qui estime les 6 qualités, pour un Index de départ plus complet/fin. On ne le
    // re-propose plus une fois fait (il ne donne que de l'ESTIMÉ → resterait sinon dans `remaining`).
    if (remaining.size >= 3) {
      const alreadyDone = await this.prisma.wodResult.findFirst({
        where: { userId, wodId: "profil_express" },
        select: { id: true },
      });
      if (!alreadyDone) {
        const pe = await this.prisma.wod.findUnique({
          where: { id: "profil_express" },
          select: { id: true, name: true, requiresEquipment: true },
        });
        if (pe) {
          sessions.push({ wodId: pe.id, name: pe.name, requiresEquipment: pe.requiresEquipment, covers: [...remaining] });
          chosen.add(pe.id);
        }
      }
    }
    while (remaining.size > 0) {
      let best: (typeof wods)[number] | null = null;
      let bestCover: string[] = [];
      for (const w of wods) {
        if (chosen.has(w.id)) continue;
        const estOnly = ESTIMATED_COVERAGE[w.id] ?? [];
        const cover = (w.targetAttributes as string[]).filter((t) => remaining.has(t) && !estOnly.includes(t));
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

  /** Reconstruit l'énoncé (« déroulé ») d'un WOD communautaire à partir de ses mouvements stockés,
   *  pour que les autres utilisateurs voient comment le faire. */
  private async buildCustomPrescription(wod: {
    type: string;
    rounds: number | null;
    timeCapSec: number | null;
    scoreType: string;
    movements: unknown;
  }): Promise<WodPrescription> {
    const movements = await this.scoreClient.getMovements();
    const nameById = new Map(movements.map((m) => [m.id, m.name]));
    const FMT: Record<string, string> = {
      for_time: "Pour le temps",
      amrap: "AMRAP",
      emom: "EMOM",
      chipper: "Chipper",
      interval: "Intervalles",
      tabata: "Tabata",
      strength: "Force",
      distance: "Distance / temps",
    };
    const roundsPrefix = wod.rounds && wod.rounds > 1 ? `${wod.rounds} tours · ` : "";
    const capSuffix = wod.timeCapSec ? ` · cap ${Math.round(wod.timeCapSec / 60)} min` : "";
    const blocks = (wod.movements as Array<{ movementId: string; reps?: number; distanceMeters?: number; calories?: number; durationSec?: number; loadKg?: number }>).map((b) => {
      const reps =
        b.distanceMeters != null ? `${b.distanceMeters} m` : b.calories != null ? `${b.calories} cal` : b.durationSec != null ? `${b.durationSec} s` : `${b.reps ?? 0}`;
      return { reps, movement: nameById.get(b.movementId) ?? b.movementId, detail: b.loadKg ? `${b.loadKg} kg` : undefined };
    });
    const scoringNote =
      wod.scoreType === "time"
        ? "Tu enregistres ton temps total."
        : wod.scoreType === "load"
          ? "Tu enregistres la charge (kg)."
          : wod.scoreType === "distance"
            ? "Tu enregistres la distance / le temps."
            : "Tu enregistres ton nombre total de répétitions.";
    return {
      summary: `Séance créée par la communauté${wod.rounds && wod.rounds > 1 ? `, ${wod.rounds} tours` : ""}. Enchaîne les mouvements ci-dessous.`,
      format: `${roundsPrefix}${FMT[wod.type] ?? wod.type}${capSuffix}`,
      timeCapSec: wod.timeCapSec ?? undefined,
      blocks,
      weights: [],
      scoringNote,
    };
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
    if (wod.isCustom) {
      // WOD communautaire : pas de barème officiel → on REJOUE l'estimation (par sexe) à partir des
      // mouvements enregistrés pour fournir les paliers champion / intermédiaire / débutant
      // (cohérent avec l'aperçu du constructeur).
      try {
        const base = {
          scoreType: wod.scoreType,
          wodType: wod.type,
          timeCapSec: wod.timeCapSec ?? undefined,
          rounds: wod.rounds ?? undefined,
          blocks: wod.movements as internalScore.WodBlockInput[],
        };
        const [m, f] = await Promise.all([
          this.scoreClient.computeEstimate({ ...base, sex: "male" }),
          this.scoreClient.computeEstimate({ ...base, sex: "female" }),
        ]);
        const triple = (refs: internalScore.ComputeEstimateResponse["references"]) => {
          const get = (lvl: string) => Math.round(refs.find((r) => r.level === lvl)?.rawResult ?? 0);
          return { champion: get("champion"), intermediate: get("intermediate"), occasional: get("occasional") };
        };
        levels = { male: triple(m.references), female: triple(f.references) };
      } catch {
        levels = null;
      }
    } else {
      try {
        levels = await this.scoreClient.getWodLevels(id);
      } catch {
        levels = null; // barème indisponible (score-service down)
      }
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
      // Énoncé concret de la séance (mouvements + poids) : barème de référence, ou reconstruit
      // depuis les mouvements enregistrés pour un WOD communautaire (« comment faire la séance »).
      prescription: WOD_PRESCRIPTIONS[wod.id] ?? (wod.isCustom ? await this.buildCustomPrescription(wod).catch(() => null) : null),
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
      // Tie-break déterministe : à perf égale, l'effort le plus ANCIEN puis le plus petit userId →
      // ordre stable et reproductible (plus de positions qui « sautent » d'une requête à l'autre).
      orderBy: [{ rawResult: better }, { performedAt: "asc" }, { userId: "asc" }],
      distinct: ["userId"], // meilleur effort par utilisateur (premier dans l'ordre = sa meilleure perf)
      take: 100,
      select: { userId: true, subScore: true, rawResult: true, performedAt: true },
    });
    const userIds = rows.map((r) => r.userId);
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true, displayName: true, rank: true },
    });
    const names = new Map(profiles.map((p) => [p.userId, p]));
    // OVR /100 global de chaque athlète → grade affiché (cohérence du score, IC-01).
    const indices = await this.prisma.hybridIndex.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true, value: true },
    });
    const ovrByUser = new Map(indices.map((h) => [h.userId, Math.round(ratingFromInternal(h.value))]));
    return {
      wodId: id,
      sex,
      entries: rows.map((r, i) => ({
        position: i + 1,
        userId: r.userId,
        displayName: names.get(r.userId)?.displayName ?? "—",
        rank: names.get(r.userId)?.rank ?? "rookie",
        index: ovrByUser.get(r.userId) ?? null,
        rawResult: Number(r.rawResult),
        subScore: ovrSub(r.subScore),
        isMe: r.userId === userId,
      })),
    };
  }
}
