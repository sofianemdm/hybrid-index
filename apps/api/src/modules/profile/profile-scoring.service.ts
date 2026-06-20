import { Injectable } from "@nestjs/common";
import { ATTRIBUTE_KEYS, type internalScore, rankFromIndex } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { SCORING_VERSION_UUID } from "../../common/constants";

/** Profil de score persisté renvoyé au mobile (index + radar lisible). */
export interface PersistedProfile {
  index: {
    value: number;
    percentile: number;
    rank: string;
    isProvisional: boolean;
    isEstimated: boolean;
    radarCoverage: number;
  };
  radar: Array<{ attribute: string; score: number; unlocked: boolean; isEstimated: boolean }>;
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
    await this.persist(userId, profile.sex, computedProfile);
    return toPersistedProfile(computedProfile);
  }

  private async persist(userId: string, sex: string, computed: internalScore.ComputeProfileResponse): Promise<void> {
    const idx = computed.index;
    const rank = rankFromIndex(idx.value);

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
          scoringVersionId: SCORING_VERSION_UUID,
        },
        update: {
          value: idx.value,
          percentile: idx.percentile,
          isProvisional: idx.isProvisional,
          isEstimated: idx.isEstimated,
          radarCoverage: idx.radarCoverage,
          confidenceLevel: confidenceFor(idx.radarCoverage, idx.isEstimated),
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
  }

  async getMyProfile(userId: string): Promise<PersistedProfile | null> {
    const [index, scores] = await Promise.all([
      this.prisma.hybridIndex.findUnique({ where: { userId } }),
      this.prisma.attributeScore.findMany({ where: { userId } }),
    ]);
    if (!index) return null;

    const byAttr = new Map(scores.map((s) => [s.attribute, s]));
    return {
      index: {
        value: index.value,
        percentile: Number(index.percentile),
        rank: rankFromIndex(index.value),
        isProvisional: index.isProvisional,
        isEstimated: index.isEstimated,
        radarCoverage: index.radarCoverage,
      },
      radar: ATTRIBUTE_KEYS.map((attribute) => {
        const s = byAttr.get(attribute);
        return {
          attribute,
          score: s?.score ?? 0,
          unlocked: s?.unlocked ?? false,
          isEstimated: s?.isEstimated ?? false,
        };
      }),
    };
  }
}

function toPersistedProfile(computed: internalScore.ComputeProfileResponse): PersistedProfile {
  return {
    index: {
      value: computed.index.value,
      percentile: computed.index.percentile,
      rank: rankFromIndex(computed.index.value),
      isProvisional: computed.index.isProvisional,
      isEstimated: computed.index.isEstimated,
      radarCoverage: computed.index.radarCoverage,
    },
    radar: computed.radar.map((a) => ({
      attribute: a.attribute,
      score: a.score,
      unlocked: a.unlocked,
      isEstimated: a.isEstimated,
    })),
  };
}
