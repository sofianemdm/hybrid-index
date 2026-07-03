import { Injectable, Logger } from "@nestjs/common";
import { ATTRIBUTE_KEYS, type internalScore, RANK_BANDS, rankFromIndex } from "@hybrid-index/contracts";
import { coverageAdjustedValue, indexPercentile, POP_BAND_ORDER, ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { RedisService } from "../../infra/redis/redis.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { FeedEventsService } from "../social/feed-events.service";
import { PushService } from "../engagement/push.service";
import { NEXT_RANK_CLOSE_THRESHOLD } from "../engagement/notifications.data";
import { SCORING_VERSION_UUID } from "../../common/constants";
import { confidenceFor, ProfileViewService, toPersistedProfile, weakestOf, type PersistedProfile } from "./profile-view.service";

const RANK_ORDER = ["rookie", "bronze", "silver", "gold", "platinum", "diamond", "elite"];

/** Preuve sociale à deux populations (cf. spec gamification). Jamais mélangées. */
// Types + helpers de VUE (PersistedProfile, SocialProof, toPersistedProfile, confidenceFor,
// weakestOf) : déplacés dans profile-view.service.ts (dégraissage 03/07). Ré-exportés ci-dessous
// pour ne pas casser les importeurs existants (onboarding, results, wods, me).
export type { PersistedProfile, SocialProof } from "./profile-view.service";

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

function weeksSince(date: Date): number {
  return Math.max(0, Math.floor((Date.now() - date.getTime()) / WEEK_MS));
}

/**
 * Recalcule (no-drop, autorité = score-service) le HYBRID INDEX et le radar d'un utilisateur
 * à partir de TOUS ses résultats persistés, puis persiste index + attributs et met à jour
 * le classement Redis. Réutilisé par l'onboarding (reveal) et le log d'un WOD.
 */
@Injectable()
export class ProfileScoringService {
  private readonly logger = new Logger(ProfileScoringService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly redis: RedisService,
    private readonly feedEvents: FeedEventsService,
    private readonly push: PushService,
    private readonly view: ProfileViewService, // preuve sociale/présentation (chemin de lecture)
  ) {}

  async recomputeForUser(userId: string): Promise<PersistedProfile | null> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) return null;

    const results = await this.prisma.wodResult.findMany({
      // Seuls les résultats validés (review:'ok') comptent dans l'Index — un effort flaggé
      // anti-triche (pending_review) ne gonfle ni l'Index ni le radar (cohérent avec les classements).
      where: { userId, review: "ok" },
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
    // Plus aucun résultat → on REMET À ZÉRO le profil (sinon l'Index resterait figé après
    // suppression de toutes les séances). Supprime Index + attributs + entrée de classement.
    if (results.length === 0) {
      await this.resetProfile(userId, profile.sex);
      return null;
    }

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
    if (attributeScores.length === 0) {
      await this.resetProfile(userId, profile.sex);
      return null;
    }
    const index = await this.scoreClient.computeIndex({ sex: profile.sex, goal: profile.goal, attributeScores });

    // Ajustement de couverture partielle : la valeur STOCKÉE (clé de tri du classement + OVR + rang)
    // intègre la pénalité tant que le radar n'est pas complet (à 6/6 c'est un no-op). On garantit
    // ainsi que classement et note affichée sont cohérents (un profil incomplet ne « dépasse » plus
    // un profil complet au score inférieur). cf. coverageAdjustedValue (scoring-core).
    const adjValue = coverageAdjustedValue(index.value, index.radarCoverage);
    const unlocked = index.radarCoverage > 0;
    const adjIndex: internalScore.ComputeIndexResponse = {
      ...index,
      value: adjValue,
      percentile: indexPercentile(adjValue),
      rating: unlocked ? ratingFromInternal(adjValue) : null,
      ratingInt: unlocked ? Math.round(ratingFromInternal(adjValue)) : null,
    };

    const computedProfile: internalScore.ComputeProfileResponse = { index: adjIndex, radar: mergedRadar };
    const existingIndex = await this.prisma.hybridIndex.findUnique({
      where: { userId },
      select: { populationBand: true, leaguePosition: true },
    });
    const previousBand = existingIndex?.populationBand ?? null;
    const previousLeaguePosition = existingIndex?.leaguePosition ?? null;
    const isFirstIndex = existingIndex === null; // tout premier Index de ce compte → arrivée en communauté
    const socialProof = await this.view.buildSocialProof(profile.sex, profile.goal, mergedRadar, adjIndex.percentile);
    await this.persist(userId, profile.sex, computedProfile, socialProof.population);
    const result = toPersistedProfile(computedProfile, socialProof);

    // Position courante dans la ligue (même calcul autoritatif que persist : nb d'athlètes du même
    // sexe au-dessus + 1). Calculée UNE fois ici puis réutilisée pour (a) la détection d'auto-
    // dépassement renvoyée à l'auteur et (b) le push « tu as été doublé » vers le voisin.
    const aboveNow = await this.prisma.hybridIndex.count({
      where: { value: { gt: adjIndex.value }, user: { profile: { sex: profile.sex as never } } },
    });
    const newLeaguePosition = aboveNow + 1;

    // Lever #1 (cahier §4.3) : si l'auteur vient de GRIMPER au classement, il a doublé au moins un
    // athlète → on remonte le flag à SON client (best-effort, jamais bloquant) pour déclencher la
    // célébration « Tu as doublé X ! ». `topName` = l'athlète le plus haut qu'il vient de passer
    // (= celui désormais juste sous lui).
    result.overtook = await this.detectOvertake(userId, profile.sex, adjIndex, previousLeaguePosition, newLeaguePosition).catch(
      (e) => {
        this.logger.warn(`Détection dépassement KO (${userId}) : ${e}`);
        return null;
      },
    );

    // Ré-engagement push (best-effort, JAMAIS bloquant) : ce recalcul vient d'un nouveau résultat,
    // c'est le bon moment pour (a) prévenir l'athlète qu'un rang est tout proche et (b) prévenir
    // celui que ce résultat vient de DOUBLER au classement. Le gating (cooldown/quietHours/opt-out)
    // et le no-op si push inactif sont gérés en aval par PushService.
    await this.fireReengagementPush(userId, profile.sex, adjIndex, previousLeaguePosition, newLeaguePosition).catch((e) =>
      this.logger.warn(`Push ré-engagement KO (${userId}) : ${e}`),
    );

    // Annonce d'arrivée : UN seul événement de feed (jamais la grappe de badges du 1er calcul).
    // On l'émet UNIQUEMENT quand l'Index est COMPLET (non estimé) : un Index encore estimé
    // (auto-évaluation pompes/squat à l'onboarding, valeur provisoire) ne doit pas afficher au feed
    // « X nous rejoint avec un index de Y » avec une note qui bougera. Il sera annoncé au 1er
    // recalcul qui le rend non estimé (ex. premier WOD réel chronométré loggé).
    if (isFirstIndex && !adjIndex.isEstimated && adjIndex.ratingInt != null) {
      await this.feedEvents.emit(userId, "member_joined", { index: adjIndex.ratingInt }).catch(() => undefined);
    }

    // Gains de compétence : no-drop ⇒ delta ≥ 0 ; on n'expose QUE les vrais gains (delta > 0).
    result.gains = mergedRadar
      .filter((a) => a.unlocked)
      .map((a) => ({
        attribute: a.attribute,
        // Gain exprimé en /100 (cohérent avec l'affichage des attributs).
        delta: Math.round(ratingFromInternal(a.score)) - Math.round(ratingFromInternal(beforeScore.get(a.attribute) ?? 0)),
      }))
      .filter((g) => g.delta > 0);
    result.weakest = weakestOf(mergedRadar);

    // Célébration : uniquement quand on MONTE de bande population (jamais à la descente).
    result.bandCelebration = bandImproved(previousBand, socialProof.population.band)
      ? { from: previousBand, to: socialProof.population.band }
      : null;
    return result;
  }

  /**
   * Déclencheurs push de ré-engagement consécutifs à un recalcul d'Index (après un résultat).
   * Tout est best-effort et borné ; PushService applique ensuite le gating (cooldown/quietHours/
   * opt-out/dailyCap) et no-ope si le push est inactif.
   *
   * 1) `near-rank` : si l'athlète est à ≤ NEXT_RANK_CLOSE_THRESHOLD points (/100) du rang suivant
   *    (même logique exacte que le flux in-app engagement.service.ts), on le lui signale.
   * 2) `rank-overtaken` : si ce résultat l'a fait MONTER au classement (nouvelle position < ancienne),
   *    l'athlète qui occupe désormais la place juste EN DESSOUS de lui vient d'être doublé → on le
   *    prévient. CHOIX BORNÉ (perf) : on ne notifie ce voisin direct QUE si le dépassement a lieu
   *    dans le top 50 (newPos <= 50) — au-delà, l'enjeu de classement est faible et le coût d'une
   *    requête supplémentaire à chaque log ne se justifie pas. Un seul voisin notifié (le plus
   *    concerné), jamais toute la grappe des places décalées.
   */
  private async fireReengagementPush(
    userId: string,
    sex: string,
    adjIndex: internalScore.ComputeIndexResponse,
    previousLeaguePosition: number | null,
    newPosition: number,
  ): Promise<void> {
    // (1) Prochain rang tout proche — seuil partagé avec le flux in-app (source unique).
    if (adjIndex.ratingInt != null) {
      const ovr = adjIndex.ratingInt;
      const next = RANK_BANDS.find((b) => b.min > ovr);
      if (next) {
        const pts = Math.ceil(next.min - ovr);
        if (pts > 0 && pts <= NEXT_RANK_CLOSE_THRESHOLD) {
          await this.push.notifyNearRank(userId, pts).catch(() => undefined);
        }
      }
    }

    // (2) Quelqu'un vient d'être doublé — borné au top 50 (cf. doc méthode).
    const RANK_OVERTAKEN_MAX_POSITION = 50;
    if (
      previousLeaguePosition != null &&
      newPosition < previousLeaguePosition && // l'athlète a GRIMPÉ
      newPosition <= RANK_OVERTAKEN_MAX_POSITION
    ) {
      // Le voisin direct doublé = celui à la valeur immédiatement INFÉRIEURE (même sexe) : il occupe
      // désormais la position juste sous l'athlète qui vient de monter.
      const overtaken = await this.prisma.hybridIndex.findFirst({
        where: { value: { lt: adjIndex.value }, user: { profile: { sex: sex as never } } },
        orderBy: [{ value: "desc" }, { userId: "asc" }],
        select: { userId: true },
      });
      if (overtaken && overtaken.userId !== userId) {
        await this.push.notifyRankOvertaken(overtaken.userId).catch(() => undefined);
      }
    }
  }

  /**
   * Lever #1 (cahier §4.3) — auto-dépassement renvoyé à l'AUTEUR du résultat. Si sa nouvelle
   * position de ligue est meilleure que l'ancienne, il vient de doubler `count` athlètes de même
   * sexe ; `topName` est le pseudo du plus haut d'entre eux (= celui désormais juste sous lui), qui
   * porte le message « Tu as doublé X ! ». Best-effort : tout échec → null (jamais bloquant pour le
   * log). Retourne null si l'auteur n'a pas grimpé (1er Index, ex æquo, ou descente impossible ici).
   */
  private async detectOvertake(
    userId: string,
    sex: string,
    adjIndex: internalScore.ComputeIndexResponse,
    previousLeaguePosition: number | null,
    newPosition: number,
  ): Promise<{ count: number; topName: string } | null> {
    // Pas d'ancienne position (tout premier Index) ou pas de montée → rien à célébrer.
    if (previousLeaguePosition == null || newPosition >= previousLeaguePosition) return null;
    const count = previousLeaguePosition - newPosition; // nb de places gagnées = athlètes doublés
    // Le plus haut athlète doublé = celui à la valeur immédiatement INFÉRIEURE (même sexe), désormais
    // juste sous l'auteur. Tie-break userId asc → choix stable, cohérent avec fireReengagementPush.
    const justBelow = await this.prisma.hybridIndex.findFirst({
      where: { value: { lt: adjIndex.value }, user: { profile: { sex: sex as never } } },
      orderBy: [{ value: "desc" }, { userId: "asc" }],
      select: { userId: true },
    });
    if (!justBelow || justBelow.userId === userId) return null;
    const p = await this.prisma.profile.findUnique({
      where: { userId: justBelow.userId },
      select: { displayName: true },
    });
    const topName = p?.displayName?.trim();
    if (!topName) return null; // sans pseudo, pas de message nommé → on n'invente rien
    return { count, topName };
  }

  /** Remet le profil de score à l'état « aucune donnée » (plus de séance) : supprime l'Index,
   *  les attributs et l'entrée de classement. Le profil (sexe/objectif/rang) reste, le rang
   *  repasse à « rookie ». Idempotent. */
  private async resetProfile(userId: string, sex: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.hybridIndex.deleteMany({ where: { userId } }),
      this.prisma.attributeScore.deleteMany({ where: { userId } }),
      this.prisma.profile.update({ where: { userId }, data: { rank: "rookie" } }),
    ]);
    await this.redis.remove(sex, userId).catch(() => undefined);
  }

  /** Profil VIDE d'un utilisateur onboardé sans aucun effort loggé (bouton « Je n'ai aucune de ces
   *  info »). Pas d'Index (plancher, non mesuré), radar entièrement verrouillé, HORS classement
   *  (aucune leaguePosition). L'UI affiche l'état « Index pas encore révélé ». */
  private async persist(
    userId: string,
    sex: string,
    computed: internalScore.ComputeProfileResponse,
    population: { percentile: number; band: string },
  ): Promise<void> {
    const idx = computed.index;
    // Le rang est calculé sur la note d'AFFICHAGE /100 (idx.ratingInt), pas la valeur interne /1000.
    const rank = rankFromIndex(idx.ratingInt ?? 40);
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

}

/** Ordre des bandes population, de la meilleure à la moins bonne. */
// Source unique : POP_BAND_ORDER dérivé de DISPLAY_BANDS (scoring-core). L'ancien tableau codé en
// dur listait pop_top_20/30 (jamais produits) et omettait 15/25/35 → célébrations muettes (BUG-006).
const BAND_ORDER = POP_BAND_ORDER;

/** Vrai si `next` est une bande STRICTEMENT meilleure que `prev` (montée). */
function bandImproved(prev: string | null, next: string): boolean {
  if (prev === null) return false; // 1er calcul : pas de célébration (c'est le reveal qui porte le wow)
  const pi = BAND_ORDER.indexOf(prev);
  const ni = BAND_ORDER.indexOf(next);
  if (pi < 0 || ni < 0) return false;
  return ni < pi;
}
