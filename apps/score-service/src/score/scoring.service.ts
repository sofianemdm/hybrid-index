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
  percentileFromInternal,
  quantile,
  subScoreFromPercentile,
} from "@hybrid-index/scoring-core";
import { WodsService } from "../wods/wods.service";
import type { WodDefinition } from "../wods/wod.types";
import { ScoringVersionService } from "./scoring-version.service";
import {
  estimateRound,
  totalTimeForRounds,
  totalVolumeForCap,
  estimateBlueprintTime,
  estimateBlueprintVolume,
  blueprintCoverage,
  predictionConfidence,
  SPREAD_BY_CONFIDENCE,
  type ResolvedBlock,
  type ResolvedBlueprintBlock,
  type AttrScores,
} from "./wod-time-engine";
import { WOD_BLUEPRINTS, blueprintMovementIds, blueprintMovementsExist, type WodBlueprint } from "../wods/wod-blueprints.data";

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
  "benchmark_zero", "run_5k", "run_3k", "run_1k", "max_pushups", "max_air_squats_2min", "burpees_7min", "ergo_skill",
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
    // Effort « Scaled » (mouvements adaptés, ex. pompes sur genoux) : légère décote du sous-score
    // (honnêteté). Jamais sur les courses (le client n'envoie pas `scaled` pour elles).
    const adjusted = req.scaled ? Math.round(subScore * 0.9) : subScore;
    return {
      subScore: adjusted,
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
    // OVR /100 (cohérence avec l'affichage de l'Index).
    const current = hybridIndex(radar, req.goal, unlockedCount).ratingInt ?? 40;

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
    const projected = hybridIndex(projectedRadar, req.goal, projectedCount).ratingInt ?? 40;

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
    // Résolution + validation des mouvements en amont (mouvement inconnu ⇒ 400, quel que soit le
    // format). Garantit aussi qu'on ne traverse jamais le moteur avec un bloc non résolu.
    for (const block of req.blocks) {
      if (!MOVEMENTS_BY_ID.get(block.movementId)) {
        throw new BadRequestException({ code: "VALIDATION_ERROR", message: `Mouvement inconnu : ${block.movementId}` });
      }
    }

    // FORCE / CHARGE (scoreType 'load') : le modèle de temps ne s'applique pas. On estime des
    // paliers EN KG à partir de la charge des mouvements chargés (charge saisie, sinon Rx de réf =
    // loadFactor × poids de corps), modulés par niveau. Branche dédiée → §A « Création de séance AAA ».
    if (req.scoreType === "load") {
      return this.estimateLoad(req);
    }

    const dir: 1 | -1 = req.scoreType === "time" ? -1 : 1;
    const levels = ["champion", "intermediate", "occasional"] as const;
    const predicted: Record<(typeof levels)[number], number> = { champion: 0, intermediate: 0, occasional: 0 };
    const attrShare = new Map<string, number>();
    // Travail comptable par tour, en UNITÉS NATIVES : reps + mètres + calories + secondes. Sert de
    // base à l'estimation des formats à volume (AMRAP/EMOM/…), y compris ceux SANS reps discrètes
    // (course/cal/temps) qui dégénéraient à 0 auparavant. §B du chantier.
    let workPerRound = 0;

    // Blocs résolus (mouvement validé en amont + quantité native + charge). La quantité native
    // reproduit l'ordre de priorité d'origine (reps → distance → cal → durée). Le moteur de temps
    // (`wod-time-engine.ts`) consomme cette décomposition canonique — UNE seule mécanique partagée.
    const resolvedBlocks: ResolvedBlock[] = req.blocks.map((block) => ({
      movement: MOVEMENTS_BY_ID.get(block.movementId)!, // déjà validé en amont
      amount: block.reps ?? block.distanceMeters ?? block.calories ?? block.durationSec ?? 0,
      loadKg: block.loadKg,
    }));

    for (const level of levels) {
      // Moteur unifié en mode « niveau » : reproduit à l'identique l'ancien calcul inline (Inc. 1,
      // iso-comportement). La pénalité de charge relative / capacité par mouvement arriveront en Inc. 2.
      const round = estimateRound(resolvedBlocks, req.sex, { kind: "level", level });
      if (level === "champion") workPerRound = round.workPerRound;
      const rounds = req.rounds ?? 1;
      if (req.scoreType === "time") {
        predicted[level] = totalTimeForRounds(round.roundTimeSec, rounds, level);
      } else {
        // AMRAP / volume : nb de tours tenables dans le cap × travail natif par tour. `workPerRound`
        // agrège reps + mètres + cal + secondes (cf. §B), donc un AMRAP cardio produit un volume > 0
        // au lieu de dégénérer. Clamp final : jamais 0/NaN (au moins 1 unité de travail).
        const cap = req.timeCapSec ?? 600;
        predicted[level] = totalVolumeForCap(round.roundTimeSec, workPerRound, cap);
      }
      if (level === "intermediate") {
        const tot = round.roundTimeSec || 1;
        for (const { attrs, cost } of round.lineCosts) {
          const share = cost / tot;
          for (const t of attrs) attrShare.set(t.attribute, (attrShare.get(t.attribute) ?? 0) + share * t.weight);
        }
      }
    }

    // Garde-fou de finitude (§C) : si un paramètre dégénéré a produit NaN/±Inf/≤0, on retombe sur un
    // plancher minimal (1) AVANT la monotonicité — aucune valeur non finie ne peut atteindre la
    // pointTable ni l'affichage.
    for (const level of levels) {
      if (!Number.isFinite(predicted[level]) || predicted[level] <= 0) predicted[level] = 1;
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

  /**
   * Estimation de CHARGE (scoreType 'load') — §A. On ancre sur la charge de travail des mouvements
   * CHARGÉS du WOD (category 'weightlifting') : charge saisie par l'utilisateur si présente, sinon
   * la charge Rx de réf du mouvement (`loadFactor × poids de corps de réf`). Moyenne des blocs
   * chargés = palier INTERMÉDIAIRE, d'où on décline par multiplicateur de niveau (champion lève
   * plus, occasionnel moins).
   * Si AUCUN mouvement chargé (que du poids de corps) ⇒ on ne peut pas ancrer une charge crédible :
   * état NON ESTIMABLE explicite (references à 0, subScore null, confidence 'low') plutôt qu'un
   * chiffre faux. dir = +1 (plus de kg = mieux). Sortie bornée, finie, monotone, par construction.
   */
  private estimateLoad(req: internalScore.ComputeEstimateRequest): internalScore.ComputeEstimateResponse {
    const BW = req.sex === "male" ? 80 : 65;
    // Charge Rx de référence (kg) du WOD : moyenne des `loadFactor × BW` des blocs réellement chargés.
    const refLoads: number[] = [];
    const attrShare = new Map<string, number>();
    for (const block of req.blocks) {
      const m = MOVEMENTS_BY_ID.get(block.movementId)!; // déjà validé en amont
      // Un mouvement ANCRE une charge externe seulement s'il porte une barre/haltère
      // (category 'weightlifting'). Les mouvements au poids de corps ont aussi un `loadFactor`
      // (fraction du corps soulevé) mais on ne peut PAS en déduire une charge en kg → ils ne
      // comptent pas comme ancre. Sinon « 5 air squats » fabriquerait une fausse charge.
      const anchorsLoad = m.category === "weightlifting" && m.loadFactor && m.loadFactor > 0;
      if (anchorsLoad) {
        // Si l'utilisateur a saisi une charge, elle prime comme ancre (sinon Rx de réf du mouvement).
        refLoads.push(block.loadKg && block.loadKg > 0 ? block.loadKg : m.loadFactor! * BW);
      }
      for (const t of m.attributes) attrShare.set(t.attribute, (attrShare.get(t.attribute) ?? 0) + t.weight);
    }

    const versionId = this.versions.getActiveVersionId();
    // Aucun mouvement chargé → NON ESTIMABLE (pas de chiffre faux). references à 0 (sentinelle),
    // subScore null, confidence 'low'. Le front affiche un message « charge non estimable ».
    if (refLoads.length === 0) {
      return {
        subScore: null,
        percentile: null,
        attributesAffected: [],
        references: [
          { level: "champion", rawResult: 0 },
          { level: "intermediate", rawResult: 0 },
          { level: "occasional", rawResult: 0 },
        ],
        confidence: "low",
        outOfBounds: false,
        scoringVersionId: versionId,
      };
    }

    // Ancre = charge de travail « intermédiaire » du WOD pour le SCHÉMA prescrit (moyenne des blocs
    // chargés). C'est la charge qu'un pratiquant intermédiaire utilise tel quel ; on en décline les
    // paliers par multiplicateur de niveau. Multiplicateurs calibrés (sport-science) : intermédiaire = 1.
    const refLoad = refLoads.reduce((a, b) => a + b, 0) / refLoads.length;
    const LEVEL_MULT = { champion: 1.45, intermediate: 1.0, occasional: 0.62 } as const;
    const clampKg = (kg: number) => {
      // Bornes plausibles (kg) : jamais ≤ 0 / NaN ; plafond physiologique large (3.5× poids de corps).
      if (!Number.isFinite(kg) || kg <= 0) return 1;
      return Math.min(BW * 3.5, kg);
    };
    const predicted = {
      champion: clampKg(Math.round(refLoad * LEVEL_MULT.champion)),
      intermediate: clampKg(Math.round(refLoad * LEVEL_MULT.intermediate)),
      occasional: clampKg(Math.round(refLoad * LEVEL_MULT.occasional)),
    };
    // Monotonicité stricte (plus de kg = mieux) : champion > intermédiaire > occasionnel. Le rattrapage
    // du champion reste BORNÉ par le plafond (jamais > 3.5× poids de corps, même sur une entrée absurde).
    if (!(predicted.champion > predicted.intermediate)) predicted.champion = Math.min(BW * 3.5, predicted.intermediate + 1);
    if (!(predicted.intermediate > predicted.occasional)) predicted.occasional = Math.max(1, predicted.intermediate - 1);

    const model = {
      kind: "pointTable" as const,
      dir: 1 as const,
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
      const hardMin = predicted.occasional * 0.3;
      const hardMax = predicted.champion * 1.5;
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
      scoringVersionId: versionId,
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
    // IDs canoniques des mouvements (blueprint) → le guide mobile ne devine plus par le nom FR.
    return {
      wodId,
      scoreType: wod.scoreType,
      male: levels.male,
      female: levels.female,
      movementIds: blueprintMovementIds(wodId),
    };
  }

  /**
   * PRÉDICTION inverse : « d'après ton niveau, tu ferais ~X » sur un WOD de référence.
   * On INVERSE la chaîne raw → percentile → subScore :
   *   1. userInternal = MOYENNE SIMPLE des sous-scores (/1000) des attributs CIBLES du WOD qui sont
   *      `unlocked` (un attribut estimé compte, du moment qu'il est débloqué). Aucun cible débloqué
   *      ⇒ predictedRaw = null (on ne prédit pas dans le vide).
   *   2. p = percentileFromInternal(userInternal) (inverse analytique de sigmoid-v1).
   *   3. predictedRaw = quantile(p, modèle_du_sexe), clampé dans [hardMin, hardMax], arrondi entier.
   * WOD inconnu OU course à distance libre (pas de résultat brut unique) ⇒ predictedRaw = null.
   */
  predictResult(req: internalScore.PredictResultRequest): internalScore.PredictResultResponse {
    const wod = this.wods.find(req.wodId);
    // WOD inconnu, ou course à distance libre (distance+temps via Riegel : pas de « raw » unique
    // à afficher sur une fiche) ⇒ on ne prédit pas. On renvoie un scoreType par défaut cohérent.
    if (!wod || req.wodId === FREE_RUN_ID) {
      return { predictedRaw: null, scoreType: wod?.scoreType ?? "time" };
    }

    // Attributs CIBLES du WOD effectivement débloqués chez l'utilisateur.
    const targets = new Set(wod.targetAttributes.map((t) => t.attribute));
    const unlockedTargetScores = req.attributeScores
      .filter((a) => targets.has(a.attribute) && a.unlocked)
      .map((a) => a.score);
    if (unlockedTargetScores.length === 0) {
      return { predictedRaw: null, scoreType: wod.scoreType };
    }

    const ref = wod.bySex[req.sex];

    // CŒUR (Inc. 2) — MODÈLE « PRO » PAR MOUVEMENT. Si le benchmark a un blueprint canonique
    // exploitable, on estime le temps/volume via le moteur en MODE ATHLÈTE : capacité par mouvement
    // (la FORCE entre via `m.attributes`, même hors `targetAttributes`) + pénalité de charge
    // relative (1RM estimé). C'est le correctif « 40 kg trop lourd ». La distribution de population
    // (`ref.model`) ne GÉNÈRE plus l'estimation : elle devient un GARDE-FOU DE BORNES (clamp final).
    const resolved = this.resolveBlueprintBlocks(req.wodId, req.sex);
    if (resolved) {
      // Scores d'attribut de l'athlète : on n'utilise QUE les attributs débloqués (un attribut
      // verrouillé ne compte pas — cohérent avec le repli population).
      const scores: AttrScores = {};
      for (const a of req.attributeScores) if (a.unlocked) scores[a.attribute] = a.score;
      const blocks = resolved.blocks;
      let estimate: number;
      if (resolved.blueprint.amrap && wod.scoreType !== "time") {
        estimate = estimateBlueprintVolume(blocks, req.sex, scores, resolved.blueprint.amrap.timeCapSec, resolved.blueprint.amrap.scoreUnit);
      } else {
        estimate = estimateBlueprintTime(blocks, req.sex, scores);
      }
      if (Number.isFinite(estimate) && estimate > 0) {
        // GARDE-FOU POPULATION (B.4) : on borne l'estimation dans [hardMin, hardMax] ET dans la
        // fourchette plausible de la distribution (quantiles 0.01/0.99) — jamais d'absurdité. Les
        // bornes sont dir-agnostiques : on prend les extrêmes des deux quantiles + hardMin/hardMax.
        const q1 = quantile(0.01, ref.model);
        const q99 = quantile(0.99, ref.model);
        const lo = Math.min(ref.hardMin, ref.hardMax, q1, q99);
        const hi = Math.max(ref.hardMin, ref.hardMax, q1, q99);
        const bounded = Math.min(hi, Math.max(lo, estimate));
        // INC. 3 — FOURCHETTE (B.6). On enveloppe le mid d'une fourchette dont la largeur dépend de
        // la CONFIANCE (couverture des attributs estimés × nb de blocs chargés = source d'erreur).
        // Les bornes restent dans le garde-fou population [lo, hi]. Le mid (predictedRaw) NE change
        // PAS → rétro-compatibilité aller-retour préservée.
        const unlockedAttrs = new Set(req.attributeScores.filter((a) => a.unlocked).map((a) => a.attribute));
        const coverage = blueprintCoverage(blocks, unlockedAttrs);
        const chargedBlocks = blocks.filter((b) => b.loadKg != null).length;
        const confidence = predictionConfidence(coverage, chargedBlocks);
        const spread = SPREAD_BY_CONFIDENCE[confidence];
        const mid = Math.round(bounded);
        const predictedLow = Math.round(Math.min(hi, Math.max(lo, bounded * (1 - spread))));
        const predictedHigh = Math.round(Math.min(hi, Math.max(lo, bounded * (1 + spread))));
        return { predictedRaw: mid, predictedLow, predictedHigh, confidence, scoreType: wod.scoreType };
      }
      // Estimation dégénérée (improbable) ⇒ repli population ci-dessous (jamais de crash/NaN).
    }

    // REPLI POPULATION (WOD sans blueprint : course pure, max-reps 1 série, 1RM…) : on garde la
    // prédiction historique. Moyenne SIMPLE des sous-scores cibles débloqués (tous d'égale
    // importance) → percentile → quantile(modèle), borné dans [hardMin, hardMax].
    const userInternal = unlockedTargetScores.reduce((s, v) => s + v, 0) / unlockedTargetScores.length;
    const p = percentileFromInternal(userInternal);
    const raw = quantile(p, ref.model);
    const clamped = Math.min(ref.hardMax, Math.max(ref.hardMin, raw));
    return { predictedRaw: Math.round(clamped), scoreType: wod.scoreType };
  }

  /**
   * Décompose un benchmark via son BLUEPRINT canonique en blocs résolus prêts pour le moteur de
   * temps (`wod-time-engine.ts`). Renvoie `null` si le WOD n'a PAS de blueprint exploitable (course
   * pure, max-reps 1 série, charge 1RM…) → l'appelant RETOMBE sur la prédiction population.
   *
   * INC. 1 — ce chemin est CÂBLÉ mais N'ALTÈRE PAS encore les valeurs prédites (iso-comportement) :
   * `predictResult` continue de renvoyer la prédiction population. Le moteur consommera réellement
   * ce blueprint à l'Inc. 2 (mode « athlète » + pénalité de charge). On valide ici que le blueprint
   * est résoluble (mouvements connus) — un blueprint cassé ⇒ repli silencieux, jamais de crash.
   */
  private resolveBlueprintBlocks(wodId: string, sex: "male" | "female"): { blocks: ResolvedBlueprintBlock[]; blueprint: WodBlueprint } | null {
    const blueprint = WOD_BLUEPRINTS[wodId];
    if (!blueprint || !blueprintMovementsExist(blueprint)) return null;
    const blocks: ResolvedBlueprintBlock[] = [];
    for (const b of blueprint.blocks) {
      const movement = MOVEMENTS_BY_ID.get(b.movementId);
      if (!movement) return null; // garde-fou : repli sur la population si un mouvement manque
      // Reps PAR TOUR conservées (le moteur coûte tour par tour : reps variables type 21-15-9).
      blocks.push({ movement, repsPerRound: b.repsPerRound, loadKg: b.loadKg ? b.loadKg[sex] : undefined });
    }
    return { blocks, blueprint };
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
    rating: number | null;
    ratingInt: number | null;
    percentile: number;
    isProvisional: boolean;
    isEstimated: boolean;
    radarCoverage: number;
  }): internalScore.ComputeIndexResponse {
    return {
      value: result.value,
      rating: result.rating,
      ratingInt: result.ratingInt,
      percentile: result.percentile,
      isProvisional: result.isProvisional,
      isEstimated: result.isEstimated,
      radarCoverage: result.radarCoverage,
      scoringVersionId: this.versions.getActiveVersionId(),
    };
  }
}
