import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException, UnprocessableEntityException } from "@nestjs/common";
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
import { isScalable, type WodPrescription } from "./wod-prescription.types";
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
// Inclut les 5 WODs « Ligue du mois » (cf. LEAGUE_WOD_IDS) : ils ne s'affichent QUE comme « WOD de la
// semaine » via la Ligue, jamais dans le catalogue Séances ni le plan de complétion de l'Index.
export const HIDDEN_WOD_IDS = [
  "run_free_distance",
  "max_air_squats",
  "league_sprint_ladder",
  "league_engine_12",
  "league_grind_squats",
  "league_power_amrap",
  "league_hybrid_chipper",
];

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

  /** Garde-fou anti-spam de création de WOD : nb max de WODs custom créés par un utilisateur sur une
   *  heure glissante. @nestjs/throttler n'est pas configuré → garde-fou applicatif (count createdAt). */
  static readonly MAX_CUSTOM_WODS_PER_HOUR = 10;

  /** Crée un WOD personnalisé (attributs ciblés dérivés du moteur d'estimation). */
  async create(userId: string, body: CreateWodRequest): Promise<unknown> {
    // Anti-abus : refuse si l'utilisateur a déjà créé trop de WODs sur la dernière heure (spam /
    // pollution du catalogue communautaire). Pas de throttler global dans l'app → contrôle applicatif.
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentCount = await this.prisma.wod.count({
      where: { createdById: userId, isCustom: true, createdAt: { gte: oneHourAgo } },
    });
    if (recentCount >= WodsService.MAX_CUSTOM_WODS_PER_HOUR) {
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
    return this.detail(wod.id, userId);
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
    return this.detail(wodId, userId);
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
          // Nouvel arrivant : on propose UNIQUEMENT le Profil Express d'abord (1 séance qui estime
          // les 6 qualités → Index complet estimé). Les séances de PRÉCISION viennent APRÈS l'avoir fait.
          return {
            missing,
            sessions: [{ wodId: pe.id, name: pe.name, requiresEquipment: pe.requiresEquipment, covers: [...remaining] }],
          };
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
      chipper: "Pour le temps",
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

  /**
   * Bloc « guidé » dérivé pour le LECTEUR de séance (Mode guidé), exposé à TOUS (énoncé public,
   * non sensible). Aucune migration : tout vient de `wod.type` / `wod.rounds` / `timeCapSec` et des
   * `blocks` de la prescription. La structure work/rest n'étant PAS stockée en base, `work[]` n'est
   * rempli QUE pour Tabata (constantes canoniques 20/10) ; les autres formats à fenêtres (EMOM/
   * intervalles) sont reconstruits côté client à partir de `rounds`/`capSec`. C'est l'ajout API
   * minimal du plan : il garantit que le client dispose toujours de `format` + `rounds` + `capSec`.
   */
  private buildGuided(
    wod: { type: string; rounds: number | null; timeCapSec: number | null },
    prescription: WodPrescription | null,
  ): {
    format: string;
    rounds: number | null;
    capSec: number | null;
    work: Array<{ kind: "work" | "rest"; durationSec: number }>;
    cues: string[];
  } {
    const capSec = prescription?.timeCapSec ?? wod.timeCapSec ?? null;
    // Consignes = chaque ligne de l'énoncé, « reps mouvement (détail) », pour l'affichage au repos.
    const cues = (prescription?.blocks ?? []).map((b) => {
      const head = [b.reps, b.movement].filter((s) => s && s.trim().length > 0).join(" ").trim();
      return b.detail && b.detail.trim().length > 0 ? `${head} (${b.detail.trim()})` : head;
    });
    // work[] : uniquement les fenêtres CANONIQUES connues sans donnée structurée (Tabata 20/10).
    const work: Array<{ kind: "work" | "rest"; durationSec: number }> = [];
    if (wod.type === "tabata") {
      work.push({ kind: "work", durationSec: 20 }, { kind: "rest", durationSec: 10 });
    }
    return { format: wod.type, rounds: wod.rounds ?? null, capSec, work, cues };
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

    // IDENTIFIANTS CANONIQUES des mouvements de la séance, dans l'ordre et sans doublon. Le guide des
    // mouvements (mobile) s'en sert pour NE PLUS deviner par le nom FR de la prescription.
    //  - WOD CUSTOM   → movementId des blocs enregistrés (wod.movements jsonb), ordonnés/dédupliqués ;
    //  - benchmark/Ligue → movementIds du blueprint, fournis par le score-service (cf. plus bas) ;
    //  - sinon (course pure, max-reps…) → [].
    let movementIds: string[] = [];
    if (wod.isCustom) {
      const seen = new Set<string>();
      for (const b of (wod.movements as Array<{ movementId?: unknown }>) ?? []) {
        const id = typeof b?.movementId === "string" ? b.movementId : null;
        if (id && !seen.has(id)) {
          seen.add(id);
          movementIds.push(id);
        }
      }
    }

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
        const ml = triple(m.references);
        const fl = triple(f.references);
        // Estimation NON disponible (ex. charge sans mouvement chargé) → paliers à 0 des deux côtés :
        // on n'affiche AUCUN palier plutôt qu'un « 0 kg » trompeur (cf. §A « Création de séance AAA »).
        const allZero = (l: { champion: number; intermediate: number; occasional: number }) =>
          l.champion <= 0 && l.intermediate <= 0 && l.occasional <= 0;
        levels = allZero(ml) && allZero(fl) ? null : { male: ml, female: fl };
      } catch {
        levels = null;
      }
    } else {
      try {
        const wodLevels = await this.scoreClient.getWodLevels(id);
        levels = wodLevels;
        // movementIds canoniques du blueprint, transportés par la même réponse (pas de round-trip
        // supplémentaire). Absents (back ancien) ⇒ [] (course pure / WOD sans blueprint).
        movementIds = wodLevels.movementIds ?? [];
      } catch {
        levels = null; // barème indisponible (score-service down) → movementIds reste []
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

    // Énoncé concret : barème de référence, ou reconstruit pour un WOD communautaire.
    const prescription: WodPrescription | null =
      WOD_PRESCRIPTIONS[wod.id] ?? (wod.isCustom ? await this.buildCustomPrescription(wod).catch(() => null) : null);

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
      // Vrai uniquement si l'utilisateur connecté est le créateur d'un WOD communautaire : le mobile
      // n'affiche les actions Éditer/Supprimer QUE dans ce cas (mêmes garde-fous que PATCH/DELETE).
      isMine: wod.isCustom && userId != null && wod.createdById === userId,
      levels,
      // IDs canoniques des mouvements (blueprint pour benchmark/Ligue, blocs pour custom, [] sinon) :
      // le guide des mouvements du mobile les résout directement, sans deviner par le nom.
      movementIds,
      myBest,
      myHistory, // mes prestations passées sur cette séance (récent → ancien)
      // Énoncé concret de la séance (mouvements + poids) : barème de référence, ou reconstruit
      // depuis les mouvements enregistrés pour un WOD communautaire (« comment faire la séance »).
      prescription,
      // Bloc dérivé pour le LECTEUR de séance guidée (format + rounds + cap + cues + fenêtres
      // canoniques). Exposé à TOUS (énoncé public). Le client construit son `GuidedPlan` dessus,
      // avec repli sur `type`/`timeCapSec` si ce bloc venait à manquer (vieux back).
      guided: this.buildGuided(wod, prescription),
      // Source unique de vérité pour le toggle Rx/Allégé côté mobile : un WOD n'est
      // « scalable » que s'il porte au moins une charge adaptable (isScalable de la prescription).
      scalable: prescription ? isScalable(prescription) : false,
      // Cibles « Référence Pro » (données publiques) à viser sur cette séance.
      references: WOD_REFERENCES[wod.id] ?? [],
      // Payload BRUT pour ré-ouvrir le constructeur pré-rempli (mêmes champs que CreateWodRequest).
      // Fourni UNIQUEMENT au créateur d'un WOD custom (sinon inutile, et on ne divulgue pas les blocs
      // d'édition d'autrui). `movements` est déjà au format des blocs du builder.
      editPayload:
        wod.isCustom && userId != null && wod.createdById === userId
          ? {
              name: wod.name,
              type: wod.type,
              scoreType: wod.scoreType,
              requiresEquipment: wod.requiresEquipment,
              timeCapSec: wod.timeCapSec,
              rounds: wod.rounds,
              blocks: wod.movements,
            }
          : null,
    };
  }

  /**
   * Prédiction « d'après ton niveau, tu ferais ~X » sur un WOD de référence, pour la fiche du WOD.
   * Charge les scores d'attribut + le sexe de l'utilisateur, délègue l'inversion au score-service.
   * WOD introuvable → 404. `predictedRaw` peut être `null` (aucun attribut cible débloqué, ou WOD
   * non prédictible côté score-service : custom/free-run) — le mobile affiche alors un état neutre.
   */
  async prediction(id: string, userId: string): Promise<internalScore.PredictResultResponse> {
    const wod = await this.prisma.wod.findUnique({ where: { id }, select: { id: true, scoreType: true } });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });

    const profile = await this.prisma.profile.findUnique({ where: { userId }, select: { sex: true } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    // Pas d'estimation « pour toi » tant que l'Index n'est pas COMPLET : prédire depuis des attributs
    // estimés/incomplets ne serait pas crédible. Même définition de « complet » que reveal_screen.dart :
    // ni provisoire, ni estimé, radar 6/6. Tant que ce n'est pas le cas → predictedRaw null (le mobile
    // masque la carte). L'utilisateur doit d'abord se construire un Index complet (~quelques séances).
    const idx = await this.prisma.hybridIndex.findUnique({
      where: { userId },
      select: { isProvisional: true, isEstimated: true, radarCoverage: true },
    });
    const indexComplete = idx != null && !idx.isProvisional && !idx.isEstimated && idx.radarCoverage >= 6;
    if (!indexComplete) {
      return { predictedRaw: null, scoreType: wod.scoreType as internalScore.PredictResultResponse["scoreType"] };
    }

    const scores = await this.prisma.attributeScore.findMany({
      where: { userId },
      select: { attribute: true, score: true, unlocked: true },
    });

    return this.scoreClient.predictResult({
      wodId: id,
      sex: profile.sex,
      attributeScores: scores.map((s) => ({ attribute: s.attribute, score: s.score, unlocked: s.unlocked })),
    });
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
      // Tie-break déterministe : à perf égale, le plus petit userId. MÊME règle que le calcul de
      // « ma position » (`me` ci-dessous) → liste et position ne divergent jamais (audit BUG-007/008).
      orderBy: [{ rawResult: better }, { userId: "asc" }],
      distinct: ["userId"], // meilleur effort par utilisateur (premier dans l'ordre = sa meilleure perf)
      take: 100,
      select: { userId: true, subScore: true, rawResult: true },
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

    // « Ma position » sur ce WOD, MÊME hors top 100 (Strava/Garmin l'épinglent toujours). On la
    // calcule sur le meilleur effort par utilisateur, avec le même tie-break que la liste.
    let me: { position: number; rawResult: number; subScore: number | null } | null = null;
    if (userId) {
      const baseWhere = { wodId: id, sex: sex as Sex, review: "ok" as const, subScore: { not: null }, rxCompliant: rx };
      const myBest = await this.prisma.wodResult.findFirst({
        where: { ...baseWhere, userId },
        orderBy: [{ rawResult: better }, { performedAt: "asc" }],
        select: { rawResult: true, subScore: true },
      });
      if (myBest) {
        // Meilleur effort de chaque utilisateur (min pour le temps, max sinon), puis on compte ceux
        // STRICTEMENT devant moi. On agrège les deux (_min/_max) pour éviter une clé undefined.
        const groups = await this.prisma.wodResult.groupBy({
          by: ["userId"],
          where: baseWhere,
          _min: { rawResult: true },
          _max: { rawResult: true },
        });
        const myVal = Number(myBest.rawResult);
        const isBetter = (v: number) => (better === "asc" ? v < myVal : v > myVal);
        let above = 0;
        for (const g of groups) {
          if (g.userId === userId) continue;
          const v = Number((better === "asc" ? g._min.rawResult : g._max.rawResult) ?? myVal);
          if (isBetter(v)) above++;
          else if (v === myVal && g.userId < userId) above++; // ex æquo → tie-break userId asc
        }
        me = { position: above + 1, rawResult: myVal, subScore: ovrSub(myBest.subScore) };
      }
    }

    return {
      wodId: id,
      sex,
      me,
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
