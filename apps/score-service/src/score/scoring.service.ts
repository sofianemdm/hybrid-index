import { BadRequestException, Injectable, NotFoundException, UnprocessableEntityException } from "@nestjs/common";
import { WOD_LEVELS } from "../wods/wod-levels.data";
import { MOVEMENTS, MOVEMENTS_BY_ID } from "../wods/movements.data";
import { ATTRIBUTE_KEYS, type internalScore } from "@hybrid-index/contracts";
import {
  type AttributeResult,
  type ScoredEffort,
  computeRadar,
  hybridIndex,
  percentile as percentileOf,
  subScoreFromPercentile,
} from "@hybrid-index/scoring-core";
import { WodsService } from "../wods/wods.service";
import type { WodDefinition } from "../wods/wod.types";
import { ScoringVersionService } from "./scoring-version.service";

/**
 * Service de calcul du score, adossé à la logique pure `@hybrid-index/scoring-core`.
 * Toute formule vit dans scoring-core ; ici on orchestre (registre WOD, bornes, version).
 */
/** Identifiant de la course à distance libre (traitement Riegel spécifique). */
const FREE_RUN_ID = "run_free_distance";
/** Exposant de la formule de Riegel (sport-science 20 juin) : t2 = t1·(d2/d1)^1.06. */
const RIEGEL_EXPONENT = 1.06;
const FREE_RUN_MIN_M = 400;
const FREE_RUN_MAX_M = 42_200;
/** Allures plancher (la plus rapide plausible) et plafond (la plus lente) en s/km. */
const PACE_FLOOR_S_PER_KM: Record<"male" | "female", number> = { male: 156, female: 171 };
const PACE_CEILING_S_PER_KM = 720;

/** Les 15 WODs de référence pour le Grand Chelem (endgame) — hors course libre / air squats 1 série. */
const GRAND_SLAM_WODS = [
  "hyrox_sprint", "fran", "grace", "jackie", "row_2k", "helen", "karen", "cindy",
  "benchmark_zero", "run_5k", "run_1k", "max_pushups", "max_air_squats_2min", "burpees_7min", "ergo_skill",
];

type EffortTag = { attribute: internalScore.RadarAttribute["attribute"]; estimated: boolean };

@Injectable()
export class ScoringService {
  constructor(
    private readonly wods: WodsService,
    private readonly versions: ScoringVersionService,
  ) {}

  /** Sous-score d'un effort sur un WOD de référence (R brut → percentile → courbe f). */
  computeSubScore(req: internalScore.ComputeSubScoreRequest): internalScore.ComputeSubScoreResponse {
    // Course à distance libre : normalisation Riegel + bornes par allure (cf. scoreFreeRun).
    if (req.wodId === FREE_RUN_ID) {
      const { subScore, percentile, tags } = this.scoreFreeRun(req.sex, req.rawResult, req.distanceMeters);
      return {
        subScore,
        percentile,
        attributesAffected: tags.map((t) => t.attribute),
        scoringVersionId: this.versions.getActiveVersionId(),
      };
    }

    const wod = this.wods.getOrThrow(req.wodId);

    if (wod.scoreType !== req.scoreType) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: `scoreType '${req.scoreType}' incompatible avec le WOD ${wod.id} ('${wod.scoreType}')`,
        details: { field: "scoreType", expected: wod.scoreType },
      });
    }

    const { subScore, percentile } = this.scoreEffort(wod, req.sex, req.rawResult);
    return {
      subScore,
      percentile,
      attributesAffected: wod.targetAttributes.map((t) => t.attribute),
      scoringVersionId: this.versions.getActiveVersionId(),
    };
  }

  /** Calcule un sous-score + percentile pour un WOD/sexe/résultat, avec contrôle des bornes (§5.5). */
  private scoreEffort(wod: WodDefinition, sex: internalScore.ComputeSubScoreRequest["sex"], rawResult: number) {
    const ref = wod.bySex[sex];
    // Anti-triche §5.5 : hors bornes physiologiques ⇒ refusé (exclu des classements).
    // NB : la détection d'ANOMALIE (saut > +30 % en 7 j → WOD_RESULT_ANOMALY) est STATEFULL
    // (inter-efforts) et relève de l'`api` (historique en base), pas du score-service pur.
    if (rawResult < ref.hardMin || rawResult > ref.hardMax) {
      throw new UnprocessableEntityException({
        code: "WOD_RESULT_OUT_OF_BOUNDS",
        message: `Résultat ${rawResult} hors bornes plausibles [${ref.hardMin}, ${ref.hardMax}] pour ${wod.id}/${sex}`,
        details: { field: "rawResult", min: ref.hardMin, max: ref.hardMax },
      });
    }
    const p = percentileOf(rawResult, ref.model);
    return { subScore: subScoreFromPercentile(p), percentile: p };
  }

  /**
   * Course à distance libre : l'utilisateur saisit (distance_m, time_s). On valide les bornes
   * d'allure (anti-triche, dérivées de la distance), on normalise vers un équivalent 5 km via
   * Riegel, puis on score contre la distribution 5 km. Tag `speed` ajouté si distance ≤ 1 km.
   * (Reco sport-science 20 juin.)
   */
  private scoreFreeRun(
    sex: internalScore.ComputeSubScoreRequest["sex"],
    timeSeconds: number,
    distanceMeters: number | undefined,
  ): { subScore: number; percentile: number; tags: EffortTag[] } {
    if (distanceMeters === undefined) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: "distanceMeters est requis pour une course à distance libre.",
        details: { field: "distanceMeters" },
      });
    }
    if (distanceMeters < FREE_RUN_MIN_M || distanceMeters > FREE_RUN_MAX_M) {
      throw new UnprocessableEntityException({
        code: "WOD_RESULT_OUT_OF_BOUNDS",
        message: `Distance ${distanceMeters} m hors plage supportée [${FREE_RUN_MIN_M}, ${FREE_RUN_MAX_M}].`,
        details: { field: "distanceMeters", min: FREE_RUN_MIN_M, max: FREE_RUN_MAX_M },
      });
    }
    const km = distanceMeters / 1000;
    const hardMin = km * PACE_FLOOR_S_PER_KM[sex];
    const hardMax = km * PACE_CEILING_S_PER_KM;
    if (timeSeconds < hardMin || timeSeconds > hardMax) {
      throw new UnprocessableEntityException({
        code: "WOD_RESULT_OUT_OF_BOUNDS",
        message: `Temps ${timeSeconds} s hors allure plausible pour ${km} km [${Math.round(hardMin)}, ${Math.round(hardMax)}] s.`,
        details: { field: "timeSeconds", min: Math.round(hardMin), max: Math.round(hardMax) },
      });
    }
    const t5kEquiv = timeSeconds * Math.pow(5000 / distanceMeters, RIEGEL_EXPONENT);
    const ref = this.wods.getOrThrow(FREE_RUN_ID).bySex[sex];
    const p = percentileOf(t5kEquiv, ref.model);
    const tags: EffortTag[] = [{ attribute: "engine", estimated: false }];
    if (distanceMeters <= 1000) tags.push({ attribute: "speed", estimated: false });
    return { subScore: subScoreFromPercentile(p), percentile: p, tags };
  }

  /**
   * Agrège l'Index à partir de scores d'attributs déjà calculés (cf. contrat interne).
   * NB : `req.sex` est reçu mais pas encore utilisé — la distribution d'Index est sex-agnostique
   * au démarrage (N(450,140), §6.4) ; le champ est conservé pour le futur percentile par sexe.
   */
  computeIndex(req: internalScore.ComputeIndexRequest): internalScore.ComputeIndexResponse {
    const radar: AttributeResult[] = req.attributeScores.map((a) => ({
      attribute: a.attribute,
      score: a.score,
      unlocked: true,
      isEstimated: a.isEstimated,
      isStale: false,
      bestAgeWeeks: null,
    }));
    return this.toIndexResponse(hybridIndex(radar, req.goal, req.attributeScores.length));
  }

  /**
   * Profil complet : à partir d'une liste d'efforts BRUTS, calcule chaque sous-score, agrège le
   * radar (no-drop D3, proxy Force D2) et l'Index pondéré. Utilisé par l'onboarding (reveal) et,
   * plus tard, par le re-calcul après chaque WOD logué.
   */
  computeProfile(req: internalScore.ComputeProfileRequest): internalScore.ComputeProfileResponse {
    const efforts: ScoredEffort[] = req.efforts.map((e) => {
      if (e.wodId === FREE_RUN_ID) {
        const { subScore, tags } = this.scoreFreeRun(req.sex, e.rawResult, e.distanceMeters);
        return { subScore, ageWeeks: e.ageWeeks, tags };
      }
      const wod = this.wods.getOrThrow(e.wodId);
      const { subScore } = this.scoreEffort(wod, req.sex, e.rawResult);
      return {
        subScore,
        ageWeeks: e.ageWeeks,
        tags: wod.targetAttributes.map((t) => ({ attribute: t.attribute, estimated: t.estimated })),
      };
    });

    const radar = computeRadar(ATTRIBUTE_KEYS, efforts);
    const index = this.toIndexResponse(hybridIndex(radar, req.goal, req.efforts.length));
    return {
      index,
      radar: radar.map((a) => ({
        attribute: a.attribute,
        score: a.score,
        unlocked: a.unlocked,
        isEstimated: a.isEstimated,
        isStale: a.isStale,
      })),
    };
  }

  /**
   * Index PROJETÉ : simule la montée de l'attribut ciblé (à son meilleur attribut, ou +100,
   * plafonné 1000) et recalcule l'Index via la fonction officielle `hybridIndex` (jamais de
   * recalcul parallèle ; on ne baisse jamais un score). Reco sport-science 20 juin.
   */
  computeProjection(req: internalScore.ComputeProjectionRequest): internalScore.ComputeProjectionResponse {
    const PROJECTION_STEP = 100;
    const radar: AttributeResult[] = req.attributeScores.map((a) => ({
      attribute: a.attribute,
      score: a.score,
      unlocked: a.unlocked,
      isEstimated: a.isEstimated,
      isStale: false,
      bestAgeWeeks: null,
    }));
    const unlockedCount = radar.filter((a) => a.unlocked).length;
    const current = hybridIndex(radar, req.goal, unlockedCount).value;

    const bestUnlocked = radar.filter((a) => a.unlocked).reduce((m, a) => Math.max(m, a.score), 0);
    const cur = radar.find((a) => a.attribute === req.targetAttribute);
    const currentScore = cur?.score ?? 0;
    const targetScore = Math.min(1000, Math.max(bestUnlocked, currentScore + PROJECTION_STEP));

    const projectedRadar: AttributeResult[] = radar.map((a) =>
      a.attribute === req.targetAttribute ? { ...a, score: Math.max(a.score, targetScore), unlocked: true } : a,
    );
    if (!cur) {
      projectedRadar.push({
        attribute: req.targetAttribute,
        score: targetScore,
        unlocked: true,
        isEstimated: true,
        isStale: false,
        bestAgeWeeks: null,
      });
    }
    const projectedCount = projectedRadar.filter((a) => a.unlocked).length;
    const projected = hybridIndex(projectedRadar, req.goal, projectedCount).value;

    return {
      current,
      projected,
      delta: Math.max(0, projected - current),
      targetAttribute: req.targetAttribute,
      targetScore,
    };
  }

  /**
   * Moteur d'estimation (sport-science) : décompose un WOD custom, prédit le temps/reps pour
   * champion/intermédiaire/occasionnel via la bibliothèque de mouvements (débit × charge × fatigue
   * × format), construit une distribution synthétique (pointTable) et réutilise la courbe f pour
   * noter un résultat. Confiance « estimated » tant que non calibré sur la communauté.
   */
  computeEstimate(req: internalScore.ComputeEstimateRequest): internalScore.ComputeEstimateResponse {
    const BW = req.sex === "male" ? 80 : 65;
    const dir: 1 | -1 = req.scoreType === "time" ? -1 : 1;
    const levels = ["champion", "intermediate", "occasional"] as const;
    const predicted: Record<(typeof levels)[number], number> = { champion: 0, intermediate: 0, occasional: 0 };
    const attrShare = new Map<string, number>();
    let repsPerRound = 0;

    for (const level of levels) {
      let roundTime = 0;
      const lineCosts: Array<{ attrs: { attribute: string; weight: number }[]; cost: number }> = [];
      for (const block of req.blocks) {
        const m = MOVEMENTS_BY_ID.get(block.movementId);
        if (!m) {
          throw new BadRequestException({ code: "VALIDATION_ERROR", message: `Mouvement inconnu : ${block.movementId}` });
        }
        const rate = m.rate[level][req.sex];
        const amount = block.reps ?? block.distanceMeters ?? block.calories ?? block.durationSec ?? 0;
        let cost: number;
        if (m.unit === "second") {
          cost = amount; // maintien : durée directe
        } else if (m.unit === "meter" && (m.id === "run" || m.id === "sprint")) {
          cost = (amount / rate) * Math.pow(Math.max(amount, 1) / 400, 0.06); // Riegel
        } else {
          const refLoad = m.loadFactor ? m.loadFactor * BW : 0;
          const loadMult = block.loadKg && refLoad > 0 ? 1 + 0.6 * Math.max(0, block.loadKg / refLoad - 1) : 1;
          const fatMult = Math.pow(Math.max(amount, 1) / 15, m.fatigueExponent - 1);
          cost = (amount / rate) * loadMult * fatMult;
        }
        roundTime += cost;
        lineCosts.push({ attrs: m.attributes, cost });
        if (level === "champion") repsPerRound += block.reps ?? 0;
      }
      roundTime += Math.max(0, req.blocks.length - 1) * 2.5; // transitions
      const rounds = req.rounds ?? 1;
      if (req.scoreType === "time") {
        predicted[level] = roundTime * rounds;
      } else {
        const cap = req.timeCapSec ?? 600;
        predicted[level] = Math.round((cap / Math.max(roundTime, 1)) * Math.max(repsPerRound, 1));
      }
      if (level === "intermediate") {
        const tot = roundTime || 1;
        for (const { attrs, cost } of lineCosts) {
          const share = cost / tot;
          for (const t of attrs) attrShare.set(t.attribute, (attrShare.get(t.attribute) ?? 0) + share * t.weight);
        }
      }
    }

    // Monotonicité stricte requise par la pointTable (cas dégénéré : WOD 100% durée).
    if (dir === -1) {
      if (!(predicted.occasional > predicted.intermediate)) predicted.intermediate = predicted.occasional * 0.6;
      if (!(predicted.intermediate > predicted.champion)) predicted.champion = predicted.intermediate * 0.6;
    } else {
      if (!(predicted.champion > predicted.intermediate)) predicted.intermediate = predicted.champion * 0.6;
      if (!(predicted.intermediate > predicted.occasional)) predicted.occasional = predicted.intermediate * 0.6;
    }

    const model = {
      kind: "pointTable" as const,
      dir,
      nodes: [
        { p: 0.15, r: predicted.occasional },
        { p: 0.5, r: predicted.intermediate },
        { p: 0.98, r: predicted.champion },
      ],
    };

    const totalShare = [...attrShare.values()].reduce((a, b) => a + b, 0) || 1;
    const attributesAffected = ATTRIBUTE_KEYS.filter((a) => (attrShare.get(a) ?? 0) / totalShare >= 0.12);

    let outOfBounds = false;
    let subScore: number | null = null;
    let pct: number | null = null;
    if (req.userResult !== undefined) {
      const hardMin = dir === -1 ? predicted.champion * 0.92 : predicted.occasional * 0.3;
      const hardMax = dir === -1 ? predicted.occasional * 2.5 : predicted.champion * 1.5;
      let value = req.userResult;
      if (value < hardMin || value > hardMax) {
        outOfBounds = true;
        value = Math.min(hardMax, Math.max(hardMin, value));
      }
      pct = percentileOf(value, model);
      subScore = subScoreFromPercentile(pct);
    }

    return {
      subScore,
      percentile: pct,
      attributesAffected,
      references: [
        { level: "champion", rawResult: predicted.champion },
        { level: "intermediate", rawResult: predicted.intermediate },
        { level: "occasional", rawResult: predicted.occasional },
      ],
      confidence: "estimated",
      outOfBounds,
      scoringVersionId: this.versions.getActiveVersionId(),
    };
  }

  /** Catalogue public des mouvements (sans paramètres internes de notation). */
  getMovements(): internalScore.MovementSummary[] {
    return MOVEMENTS.map((m) => ({
      id: m.id,
      name: m.name,
      category: m.category,
      unit: m.unit,
      requiresEquipment: m.requiresEquipment,
    }));
  }

  /** Paliers de référence (champion/intermédiaire/occasionnel) d'un WOD, par sexe. */
  getWodLevels(wodId: string): internalScore.WodLevelsResponse {
    const wod = this.wods.getOrThrow(wodId);
    const levels = WOD_LEVELS[wodId];
    if (!levels) {
      throw new NotFoundException({ code: "NOT_FOUND", message: `Aucun palier de référence pour ${wodId}.` });
    }
    return { wodId, scoreType: wod.scoreType, male: levels.male, female: levels.female };
  }

  /** Grand Chelem : compte les WODs de référence où le meilleur effort bat la référence pro. */
  computeGrandSlam(req: internalScore.ComputeGrandSlamRequest): internalScore.ComputeGrandSlamResponse {
    const byWod = new Map<string, number[]>();
    for (const b of req.bests) {
      const arr = byWod.get(b.wodId) ?? [];
      arr.push(b.rawResult);
      byWod.set(b.wodId, arr);
    }
    let beaten = 0;
    const remaining: string[] = [];
    for (const id of GRAND_SLAM_WODS) {
      const wod = this.wods.getOrThrow(id);
      const ref = wod.bySex[req.sex];
      const dir = ref.model.dir;
      const results = byWod.get(id) ?? [];
      // dir -1 (temps : plus bas = mieux) ; dir +1 (reps/charge : plus haut = mieux).
      const beats = results.some((r) => (dir === -1 ? r <= ref.proReference : r >= ref.proReference));
      if (beats) beaten += 1;
      else remaining.push(wod.name);
    }
    return { beaten, total: GRAND_SLAM_WODS.length, remaining };
  }

  private toIndexResponse(result: {
    value: number;
    percentile: number;
    isProvisional: boolean;
    isEstimated: boolean;
    radarCoverage: number;
  }): internalScore.ComputeIndexResponse {
    return {
      value: result.value,
      percentile: result.percentile,
      isProvisional: result.isProvisional,
      isEstimated: result.isEstimated,
      radarCoverage: result.radarCoverage,
      scoringVersionId: this.versions.getActiveVersionId(),
    };
  }
}
