import { Injectable } from "@nestjs/common";
import { ATTRIBUTE_KEYS, type AttributeKey, type Goal, type Sex, type internalScore, rankFromIndex, rankProgress } from "@hybrid-index/contracts";
import { type AttributeResult, bandFromP, popPercentileIndex } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { FeedEventsService } from "../social/feed-events.service";
import { SCORING_VERSION_UUID } from "../../common/constants";

const RANK_ORDER = ["rookie", "bronze", "silver", "gold", "platinum", "diamond", "elite"];

/** Preuve sociale à deux populations (cf. spec gamification). Jamais mélangées. */
export interface SocialProof {
  /** « Humanité » : toujours présent, toujours valorisant. */
  population: { topPercent: number | null; band: string; percentile: number };
  /** « App » : visible UNIQUEMENT si top 30% ET ligue crédible (≥ 200). Sinon masqué. */
  app: { visible: boolean; topPercent: number | null; percentile: number | null };
}

/** Seuils d'affichage du percentile app (cf. spec : silence total hors top 30%, ligue < 200). */
const APP_VISIBLE_PERCENTILE = 0.7;
const MIN_LEAGUE_FOR_APP = 200;

/** Profil de score persisté renvoyé au mobile (index + radar lisible + preuve sociale). */
export interface PersistedProfile {
  index: {
    value: number;
    percentile: number;
    rank: string;
    isProvisional: boolean;
    isEstimated: boolean;
    radarCoverage: number;
    /** Progression vers le rang suivant (goal-gradient). next null = rang max. */
    rankProgress: { current: string; next: string | null; pointsToNext: number | null; progress: number };
  };
  radar: Array<{ attribute: string; score: number; unlocked: boolean; isEstimated: boolean }>;
  socialProof: SocialProof;
  /** Attributs ayant PROGRESSÉ au dernier recalcul (no-drop ⇒ delta > 0). Vide sur un simple GET. */
  gains: Array<{ attribute: string; delta: number }>;
  /** Attribut débloqué le plus faible (= point faible à cibler), ou null si aucun débloqué. */
  weakest: string | null;
  /** Renseigné après un recalcul qui fait MONTER de bande population (déclenche la célébration UI). */
  bandCelebration?: { from: string | null; to: string } | null;
}

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

function weeksSince(date: Date): number {
  return Math.max(0, Math.floor((Date.now() - date.getTime()) / WEEK_MS));
}

function confidenceFor(coverage: number, isEstimated: boolean): string {
  if (coverage >= 5 && !isEstimated) return "high";
  if (coverage >= 3) return "medium";
  return "low";
}

/**
 * Recalcule (no-drop, autorité = score-service) le HYBRID INDEX et le radar d'un utilisateur
 * à partir de TOUS ses résultats persistés, puis persiste index + attributs et met à jour
 * le classement Redis. Réutilisé par l'onboarding (reveal) et le log d'un WOD.
 */
@Injectable()
export class ProfileScoringService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly redis: RedisService,
    private readonly feedEvents: FeedEventsService,
  ) {}

  async recomputeForUser(userId: string): Promise<PersistedProfile | null> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) return null;

    const results = await this.prisma.wodResult.findMany({
      where: { userId },
      select: {
        wodId: true,
        rawResult: true,
        distanceMeters: true,
        performedAt: true,
        subScore: true,
        attributesAffected: true,
        wod: { select: { isCustom: true } },
      },
    });
    if (results.length === 0) return null;

    // Snapshot du radar AVANT recalcul → feedback de compétence « +X sur l'attribut » (H1).
    const before = await this.prisma.attributeScore.findMany({
      where: { userId },
      select: { attribute: true, score: true },
    });
    const beforeScore = new Map(before.map((s) => [s.attribute as string, s.score]));

    // 1) WODs officiels (connus du registre score-service) → radar no-drop (autorité).
    const officialEfforts: internalScore.EffortInput[] = results
      .filter((r) => !r.wod.isCustom)
      .map((r) => ({
        wodId: r.wodId,
        rawResult: Number(r.rawResult),
        distanceMeters: r.distanceMeters ?? undefined,
        ageWeeks: weeksSince(r.performedAt),
      }));

    let radar: internalScore.RadarAttribute[];
    if (officialEfforts.length > 0) {
      const computed = await this.scoreClient.computeProfile({
        sex: profile.sex,
        goal: profile.goal,
        efforts: officialEfforts,
      });
      radar = computed.radar.map((a) => ({ ...a }));
    } else {
      radar = ATTRIBUTE_KEYS.map((attribute) => ({
        attribute,
        score: 0,
        unlocked: false,
        isEstimated: false,
        isStale: false,
      }));
    }

    // 2) WODs custom (notés par estimation) → fusion no-drop (jamais baisser), étiquetés estimés.
    const radarByAttr = new Map(radar.map((a) => [a.attribute, a]));
    for (const r of results) {
      if (!r.wod.isCustom || r.subScore === null) continue;
      for (const attr of r.attributesAffected) {
        const cur = radarByAttr.get(attr);
        if (!cur) continue;
        if (r.subScore > cur.score || !cur.unlocked) {
          cur.score = Math.max(cur.score, r.subScore);
          cur.unlocked = true;
          cur.isEstimated = true;
        }
      }
    }
    const mergedRadar = ATTRIBUTE_KEYS.map(
      (attribute) =>
        radarByAttr.get(attribute) ?? { attribute, score: 0, unlocked: false, isEstimated: false, isStale: false },
    );

    // 3) Index recalculé à partir du radar fusionné (autorité : computeIndex).
    const attributeScores = mergedRadar
      .filter((a) => a.unlocked)
      .map((a) => ({ attribute: a.attribute, score: a.score, isEstimated: a.isEstimated }));
    if (attributeScores.length === 0) return null;
    const index = await this.scoreClient.computeIndex({ sex: profile.sex, goal: profile.goal, attributeScores });

    const computedProfile: internalScore.ComputeProfileResponse = { index, radar: mergedRadar };
    const previousBand =
      (await this.prisma.hybridIndex.findUnique({ where: { userId }, select: { populationBand: true } }))
        ?.populationBand ?? null;
    const socialProof = await this.buildSocialProof(profile.sex, profile.goal, mergedRadar, index.percentile);
    await this.persist(userId, profile.sex, computedProfile, socialProof.population);
    const result = toPersistedProfile(computedProfile, socialProof);

    // Gains de compétence : no-drop ⇒ delta ≥ 0 ; on n'expose QUE les vrais gains (delta > 0).
    result.gains = mergedRadar
      .filter((a) => a.unlocked)
      .map((a) => ({ attribute: a.attribute, delta: a.score - (beforeScore.get(a.attribute) ?? 0) }))
      .filter((g) => g.delta > 0);
    result.weakest = weakestOf(mergedRadar);

    // Célébration : uniquement quand on MONTE de bande population (jamais à la descente).
    result.bandCelebration = bandImproved(previousBand, socialProof.population.band)
      ? { from: previousBand, to: socialProof.population.band }
      : null;
    return result;
  }

  /** Construit la preuve sociale (population toujours ; app seulement si top 30% ET ligue ≥ 200). */
  private async buildSocialProof(
    sex: string,
    goal: string,
    radar: ReadonlyArray<{ attribute: string; score: number; unlocked: boolean; isEstimated: boolean }>,
    appPercentile: number,
  ): Promise<SocialProof> {
    const results: AttributeResult[] = radar.map((a) => ({
      attribute: a.attribute as AttributeKey,
      score: a.score,
      unlocked: a.unlocked,
      isEstimated: a.isEstimated,
      isStale: false,
      bestAgeWeeks: null,
    }));
    const popP = popPercentileIndex(sex as Sex, goal as Goal, results);
    const band = bandFromP(popP);
    const leagueSize = await this.prisma.hybridIndex.count({ where: { user: { profile: { sex: sex as never } } } });
    const appVisible = appPercentile >= APP_VISIBLE_PERCENTILE && leagueSize >= MIN_LEAGUE_FOR_APP;
    return {
      population: { topPercent: band.topPercent, band: band.band, percentile: popP },
      app: {
        visible: appVisible,
        topPercent: appVisible ? Math.max(1, Math.ceil((1 - appPercentile) * 100)) : null,
        percentile: appVisible ? appPercentile : null,
      },
    };
  }

  private async persist(
    userId: string,
    sex: string,
    computed: internalScore.ComputeProfileResponse,
    population: { percentile: number; band: string },
  ): Promise<void> {
    const idx = computed.index;
    const rank = rankFromIndex(idx.value);
    const before = await this.prisma.profile.findUnique({ where: { userId }, select: { rank: true } });
    // Snapshot de position dans la ligue (athlètes du même sexe au-dessus + 1) — autoritatif Postgres.
    const above = await this.prisma.hybridIndex.count({
      where: { value: { gt: idx.value }, user: { profile: { sex: sex as never } } },
    });
    const leaguePosition = above + 1;

    await this.prisma.$transaction([
      this.prisma.hybridIndex.upsert({
        where: { userId },
        create: {
          userId,
          value: idx.value,
          percentile: idx.percentile,
          isProvisional: idx.isProvisional,
          isEstimated: idx.isEstimated,
          radarCoverage: idx.radarCoverage,
          confidenceLevel: confidenceFor(idx.radarCoverage, idx.isEstimated),
          populationPercentile: population.percentile,
          populationBand: population.band,
          leaguePosition,
          scoringVersionId: SCORING_VERSION_UUID,
        },
        update: {
          value: idx.value,
          percentile: idx.percentile,
          isProvisional: idx.isProvisional,
          isEstimated: idx.isEstimated,
          radarCoverage: idx.radarCoverage,
          confidenceLevel: confidenceFor(idx.radarCoverage, idx.isEstimated),
          populationPercentile: population.percentile,
          populationBand: population.band,
          leaguePosition,
          scoringVersionId: SCORING_VERSION_UUID,
          computedAt: new Date(),
        },
      }),
      ...computed.radar.map((a) =>
        this.prisma.attributeScore.upsert({
          where: { userId_attribute: { userId, attribute: a.attribute } },
          create: {
            userId,
            attribute: a.attribute,
            score: a.score,
            // Le contrat radar ne porte pas (encore) de percentile par attribut : on stocke une
            // approximation monotone (score/1000) plutôt qu'un 0 trompeur. À remplacer quand le
            // score-service exposera le percentile par attribut.
            percentile: a.score / 1000,
            unlocked: a.unlocked,
            isEstimated: a.isEstimated,
            isStale: a.isStale,
            scoringVersionId: SCORING_VERSION_UUID,
          },
          update: {
            score: a.score,
            percentile: a.score / 1000,
            unlocked: a.unlocked,
            isEstimated: a.isEstimated,
            isStale: a.isStale,
            scoringVersionId: SCORING_VERSION_UUID,
          },
        }),
      ),
      this.prisma.profile.update({ where: { userId }, data: { rank } }),
    ]);

    await this.redis.setIndex(sex, userId, idx.value);

    // Historique de progression (H3) : un point seulement quand la valeur change (courbe lisible).
    const lastHist = await this.prisma.hybridIndexHistory.findFirst({
      where: { userId },
      orderBy: { computedAt: "desc" },
      select: { value: true },
    });
    if (!lastHist || lastHist.value !== idx.value) {
      await this.prisma.hybridIndexHistory
        .create({
          data: {
            userId,
            value: idx.value,
            percentile: idx.percentile,
            scoringVersionId: SCORING_VERSION_UUID,
            reason: "recompute",
          },
        })
        .catch(() => undefined);
    }

    // Événement de feed : montée de rang (uniquement vers le haut).
    if (before && RANK_ORDER.indexOf(rank) > RANK_ORDER.indexOf(before.rank)) {
      await this.feedEvents.emit(userId, "rank_up", { rank, from: before.rank, index: idx.value });
    }
  }

  /** Série temporelle de l'Index (H3) pour la courbe de progression personnelle. */
  async getHistory(userId: string): Promise<Array<{ value: number; percentile: number; rank: string; at: string }>> {
    // Les 180 points les PLUS RÉCENTS (desc + take), puis remis en ordre chronologique pour la courbe.
    const rows = await this.prisma.hybridIndexHistory.findMany({
      where: { userId },
      orderBy: { computedAt: "desc" },
      take: 180,
      select: { value: true, percentile: true, computedAt: true },
    });
    return rows
      .reverse()
      .map((r) => ({
        value: r.value,
        percentile: Number(r.percentile),
        rank: rankFromIndex(r.value),
        at: r.computedAt.toISOString(),
      }));
  }

  async getMyProfile(userId: string): Promise<PersistedProfile | null> {
    const [profile, index, scores] = await Promise.all([
      this.prisma.profile.findUnique({ where: { userId }, select: { sex: true, goal: true } }),
      this.prisma.hybridIndex.findUnique({ where: { userId } }),
      this.prisma.attributeScore.findMany({ where: { userId } }),
    ]);
    if (!index || !profile) return null;

    const byAttr = new Map(scores.map((s) => [s.attribute, s]));
    const radar = ATTRIBUTE_KEYS.map((attribute) => {
      const s = byAttr.get(attribute);
      return {
        attribute,
        score: s?.score ?? 0,
        unlocked: s?.unlocked ?? false,
        isEstimated: s?.isEstimated ?? false,
      };
    });
    const socialProof = await this.buildSocialProof(profile.sex, profile.goal, radar, Number(index.percentile));
    return {
      index: {
        value: index.value,
        percentile: Number(index.percentile),
        rank: rankFromIndex(index.value),
        isProvisional: index.isProvisional,
        isEstimated: index.isEstimated,
        radarCoverage: index.radarCoverage,
        rankProgress: rankProgress(index.value),
      },
      radar,
      socialProof,
      gains: [], // pas de delta sur un simple GET (pas d'état « avant »)
      weakest: weakestOf(radar),
    };
  }
}

/** Ordre des bandes population, de la meilleure à la moins bonne. */
const BAND_ORDER = ["pop_top_1", "pop_top_2", "pop_top_5", "pop_top_10", "pop_top_20", "pop_top_30", "pop_top_50", "pop_building"];

/** Vrai si `next` est une bande STRICTEMENT meilleure que `prev` (montée). */
function bandImproved(prev: string | null, next: string): boolean {
  if (prev === null) return false; // 1er calcul : pas de célébration (c'est le reveal qui porte le wow)
  const pi = BAND_ORDER.indexOf(prev);
  const ni = BAND_ORDER.indexOf(next);
  if (pi < 0 || ni < 0) return false;
  return ni < pi;
}

function toPersistedProfile(
  computed: internalScore.ComputeProfileResponse,
  socialProof: SocialProof,
): PersistedProfile {
  return {
    index: {
      value: computed.index.value,
      percentile: computed.index.percentile,
      rank: rankFromIndex(computed.index.value),
      isProvisional: computed.index.isProvisional,
      isEstimated: computed.index.isEstimated,
      radarCoverage: computed.index.radarCoverage,
      rankProgress: rankProgress(computed.index.value),
    },
    radar: computed.radar.map((a) => ({
      attribute: a.attribute,
      score: a.score,
      unlocked: a.unlocked,
      isEstimated: a.isEstimated,
    })),
    socialProof,
    gains: [],
    weakest: weakestOf(computed.radar),
  };
}

/** Attribut débloqué au score le plus bas (= point faible), cohérent avec le coach. */
function weakestOf(radar: ReadonlyArray<{ attribute: string; score: number; unlocked: boolean }>): string | null {
  const unlocked = radar.filter((a) => a.unlocked);
  if (unlocked.length === 0) return null;
  return unlocked.reduce((min, a) => (a.score < min.score ? a : min)).attribute;
}
