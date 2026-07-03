import { Injectable } from "@nestjs/common";
import { ATTRIBUTE_KEYS, type AttributeKey, type Goal, type Sex, type internalScore, rankFromIndex, rankProgress } from "@hybrid-index/contracts";
import { type AttributeResult, bandFromP, popPercentileIndex, ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { buildRival } from "./rival.logic";

/**
 * LECTURE du profil (vue) — extrait de l'ex-ProfileScoringService (707 lignes) au dégraissage du
 * 03/07 : ici tout ce qui LIT/PRÉSENTE (getMyProfile, historique, preuve sociale, rival, profil
 * vide), là-bas tout ce qui CALCULE/ÉCRIT (recompute, persistance, célébrations). Les helpers
 * partagés (types, toPersistedProfile, confidenceFor, weakestOf) sont exportés d'ICI — la vue ne
 * dépend jamais du scoring (pas de cycle).
 */

export interface SocialProof {
  /** « Humanité » : toujours présent, toujours valorisant. */
  population: { topPercent: number | null; band: string; percentile: number };
  /** « App » : visible UNIQUEMENT si top 30% ET ligue crédible (≥ 200). Sinon masqué. */
  app: { visible: boolean; topPercent: number | null; percentile: number | null };
}

/** Seuils d'affichage du percentile app (cf. spec : silence total hors top 30%, ligue < 200). */
const APP_VISIBLE_PERCENTILE = 0.7;
const MIN_LEAGUE_FOR_APP = 200;

export interface PersistedProfile {
  index: {
    value: number; // OVR /100 (toujours présent ; plancher si non mesuré)
    rating?: number | null; // /100 à 1 décimale (null si non mesuré)
    internal?: number; // valeur interne /1000

    percentile: number;
    rank: string;
    isProvisional: boolean;
    isEstimated: boolean;
    radarCoverage: number;
    /** Progression vers le rang suivant (goal-gradient). next null = rang max. */
    rankProgress: { current: string; next: string | null; pointsToNext: number | null; progress: number };
  };
  radar: Array<{ attribute: string; score: number; unlocked: boolean; isEstimated: boolean; isStale?: boolean }>;
  socialProof: SocialProof;
  /** Rival amical : l'athlète juste AU-DESSUS dans la ligue (même sexe). null si leader ou ligue
   *  d'une personne. Ton toujours bienveillant côté UI ; jamais de honte. (Réintroduit sur décision
   *  du fondateur du 2026-06-23, annule D19 — cf. decisions-log.) */
  rival?: {
    displayName: string;
    rank: string;
    ovr: number; // OVR /100 du rival
    position: number; // place du rival dans la ligue
    gapPoints: number; // points d'Index pour le dépasser (>= 1)
  } | null;
  /** Attributs ayant PROGRESSÉ au dernier recalcul (no-drop ⇒ delta > 0). Vide sur un simple GET. */
  gains: Array<{ attribute: string; delta: number }>;
  /** Attribut débloqué le plus faible (= point faible à cibler), ou null si aucun débloqué. */
  weakest: string | null;
  /** Renseigné après un recalcul qui fait MONTER de bande population (déclenche la célébration UI). */
  bandCelebration?: { from: string | null; to: string } | null;
  /** Renseigné après un recalcul (suite à un résultat) qui fait MONTER l'auteur au classement de sa
   *  ligue : il vient de DOUBLER au moins un athlète de même sexe. Déclenche la célébration « Tu as
   *  doublé X ! » côté UI (lever #1 du cahier §4.3). null si l'auteur n'a pas grimpé. */
  overtook?: { count: number; topName: string } | null;
  /** Position dans la ligue (sexe), 1-indexée, + taille de la ligue. Rempli sur un GET de profil. */
  leaguePosition?: number;
  leagueTotal?: number;
}

export function confidenceFor(coverage: number, isEstimated: boolean): string {
  if (coverage >= 5 && !isEstimated) return "high";
  if (coverage >= 3) return "medium";
  return "low";
}

/** Vrai si l'utilisateur a validé OU passé l'onboarding (drapeau `consents.onboarded`). Sert à
 *  distinguer « jamais onboardé » (→ écran d'onboarding) de « onboardé sans Index » (→ app, profil vide). */
function isOnboarded(consents: unknown): boolean {
  return (
    typeof consents === "object" &&
    consents !== null &&
    (consents as Record<string, unknown>).onboarded === true
  );
}

export function toPersistedProfile(
  computed: internalScore.ComputeProfileResponse,
  socialProof: SocialProof,
): PersistedProfile {
  return {
    index: {
      value: computed.index.ratingInt ?? Math.round(ratingFromInternal(computed.index.value)), // OVR /100, jamais null
      rating: computed.index.rating ?? null,
      internal: computed.index.value, // valeur interne /1000 (tri/debug)
      percentile: computed.index.percentile,
      rank: rankFromIndex(computed.index.ratingInt ?? 40),
      isProvisional: computed.index.isProvisional,
      isEstimated: computed.index.isEstimated,
      radarCoverage: computed.index.radarCoverage,
      rankProgress: rankProgress(computed.index.ratingInt ?? 40),
    },
    radar: computed.radar.map((a) => ({
      attribute: a.attribute,
      score: a.unlocked ? Math.round(ratingFromInternal(a.score)) : 0, // /100
      unlocked: a.unlocked,
      isEstimated: a.isEstimated,
    })),
    socialProof,
    gains: [],
    weakest: weakestOf(computed.radar),
  };
}

/** Attribut débloqué au score le plus bas (= point faible), cohérent avec le coach. */
export function weakestOf(radar: ReadonlyArray<{ attribute: string; score: number; unlocked: boolean }>): string | null {
  const unlocked = radar.filter((a) => a.unlocked);
  if (unlocked.length === 0) return null;
  return unlocked.reduce((min, a) => (a.score < min.score ? a : min)).attribute;
}

@Injectable()
export class ProfileViewService {
  constructor(private readonly prisma: PrismaService) {}

  /** Construit la preuve sociale (population toujours ; app seulement si top 30% ET ligue ≥ 200). */
  async buildSocialProof(
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
      .map((r) => {
        const ratingInt = Math.round(ratingFromInternal(r.value));
        return {
          value: ratingInt, // historique affiché en /100
          percentile: Number(r.percentile),
          rank: rankFromIndex(ratingInt),
          at: r.computedAt.toISOString(),
        };
      });
  }

  /** Rival amical : l'athlète immédiatement au-dessus dans la ligue (même sexe). `above` = nb
   *  d'athlètes au-dessus de moi (donc 0 = je suis leader → pas de rival). Données brutes ; la
   *  copie bienveillante est composée côté UI. */
  private async computeRival(
    sex: string,
    myValue: number,
    above: number,
  ): Promise<PersistedProfile["rival"]> {
    if (above <= 0) return null; // leader de la ligue : pas de rival au-dessus
    // Rival = athlète à la valeur immédiatement SUPÉRIEURE (tie-break userId asc → choix stable).
    const rivalIdx = await this.prisma.hybridIndex.findFirst({
      where: { value: { gt: myValue }, user: { profile: { sex: sex as never } } },
      orderBy: [{ value: "asc" }, { userId: "asc" }],
      select: { userId: true, value: true },
    });
    if (!rivalIdx) return null;
    // VRAIE position du rival dans l'ordre total (value desc, userId asc) — cohérente avec le
    // classement. L'ancien `above` (count value>maValeur) surcomptait les ex æquo du rival (BUG-009).
    const rbase = { user: { profile: { sex: sex as never } } };
    const [rivalStrictlyAbove, rivalTiedEarlier] = await Promise.all([
      this.prisma.hybridIndex.count({ where: { ...rbase, value: { gt: rivalIdx.value } } }),
      this.prisma.hybridIndex.count({ where: { ...rbase, value: rivalIdx.value, userId: { lt: rivalIdx.userId } } }),
    ]);
    const rivalPosition = rivalStrictlyAbove + rivalTiedEarlier + 1;
    const rp = await this.prisma.profile.findUnique({
      where: { userId: rivalIdx.userId },
      select: { displayName: true, rank: true },
    });
    // Vue rival = logique pure et testée (cf. rival.logic.ts). On passe la vraie position du rival.
    return buildRival(myValue, rivalPosition, { value: rivalIdx.value, displayName: rp?.displayName ?? null, rank: rp?.rank ?? null });
  }

  /** Profil VIDE d'un utilisateur onboardé sans aucun effort loggé (bouton « Je n'ai aucune de ces
   *  info »). Pas d'Index (plancher, non mesuré), radar entièrement verrouillé, HORS classement
   *  (aucune leaguePosition). L'UI affiche l'état « Index pas encore révélé ». */
  private async buildEmptyProfile(sex: string, goal: string): Promise<PersistedProfile> {
    const radar = ATTRIBUTE_KEYS.map((attribute) => ({
      attribute,
      score: 0,
      unlocked: false,
      isEstimated: false,
      isStale: false,
    }));
    const socialProof = await this.buildSocialProof(sex, goal, radar, 0);
    const floorOvr = Math.round(ratingFromInternal(0));
    return {
      index: {
        value: floorOvr,
        rating: null, // non mesuré
        internal: 0,
        percentile: 0,
        rank: rankFromIndex(floorOvr),
        isProvisional: true,
        isEstimated: true,
        radarCoverage: 0, // 0 = aucun attribut mesuré → l'UI montre « Index pas encore révélé »
        rankProgress: rankProgress(floorOvr),
      },
      radar,
      socialProof,
      rival: null,
      gains: [],
      weakest: null,
      // leaguePosition / leagueTotal volontairement omis → hors classement tant qu'aucun effort.
    };
  }

  async getMyProfile(userId: string): Promise<PersistedProfile | null> {
    const [profile, index, scores, user] = await Promise.all([
      this.prisma.profile.findUnique({ where: { userId }, select: { sex: true, goal: true } }),
      this.prisma.hybridIndex.findUnique({ where: { userId } }),
      this.prisma.attributeScore.findMany({ where: { userId } }),
      this.prisma.user.findUnique({ where: { id: userId }, select: { consents: true } }),
    ]);
    if (!profile) return null;
    // Onboarding « passé » (bouton « Je n'ai aucune de ces info ») : l'utilisateur est ENTRÉ dans
    // l'app sans aucun effort → pas d'Index, hors classement, mais on ne le renvoie PAS à l'onboarding.
    // On renvoie un profil VIDE (radar verrouillé) plutôt qu'un 404, tant qu'il n'a rien loggé.
    if (!index) {
      return isOnboarded(user?.consents) ? this.buildEmptyProfile(profile.sex, profile.goal) : null;
    }

    const byAttr = new Map(scores.map((s) => [s.attribute, s]));
    const radar = ATTRIBUTE_KEYS.map((attribute) => {
      const s = byAttr.get(attribute);
      return {
        attribute,
        score: s?.score ?? 0,
        unlocked: s?.unlocked ?? false,
        isEstimated: s?.isEstimated ?? false,
        isStale: s?.isStale ?? false,
      };
    });
    const socialProof = await this.buildSocialProof(profile.sex, profile.goal, radar, Number(index.percentile));
    // Position dans la ligue (sexe), 1-indexée — autoritatif Postgres (live).
    const [above, leagueTotal] = await Promise.all([
      this.prisma.hybridIndex.count({ where: { value: { gt: index.value }, user: { profile: { sex: profile.sex } } } }),
      this.prisma.hybridIndex.count({ where: { user: { profile: { sex: profile.sex } } } }),
    ]);
    const rival = await this.computeRival(profile.sex, index.value, above);
    return {
      leaguePosition: above + 1,
      leagueTotal,
      rival,
      index: (() => {
        // `index` est une ligne DB (valeur interne /1000) → on dérive l'OVR /100.
        // `value` est TOUJOURS un entier non-null (contrat unique avec l'onboarding) ;
        // un index sans aucun attribut tombe au plancher, pas à null.
        // `index.value` est DÉJÀ la valeur ajustée par couverture (appliquée à la persistance).
        const ratingInt = Math.round(ratingFromInternal(index.value));
        return {
          value: ratingInt, // OVR /100 affiché
          rating: index.radarCoverage > 0 ? ratingFromInternal(index.value) : null,
          internal: index.value, // valeur interne /1000 (tri/debug)
          percentile: Number(index.percentile),
          rank: rankFromIndex(ratingInt),
          isProvisional: index.isProvisional,
          isEstimated: index.isEstimated,
          radarCoverage: index.radarCoverage,
          rankProgress: rankProgress(ratingInt),
        };
      })(),
      // Attributs affichés en /100 (cohérence OVR / carte FIFA) ; l'interne reste /1000.
      radar: radar.map((a) => ({ ...a, score: a.unlocked ? Math.round(ratingFromInternal(a.score)) : 0 })),
      socialProof,
      gains: [], // pas de delta sur un simple GET (pas d'état « avant »)
      weakest: weakestOf(radar),
    };
  }
}
