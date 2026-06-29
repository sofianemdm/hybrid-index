import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { ATTRIBUTE_KEYS, type internalScore } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
import { StreakService, type StreakState } from "../engagement/streak.service";
import { SESSIONS, allSessions, sessionsForAttribute, weeklySession, type Session } from "./sessions.data";
import type { AttributeKey } from "@hybrid-index/contracts";

export interface CoachResponse {
  targetAttribute: string;
  projection: internalScore.ComputeProjectionResponse;
  sessions: Session[];
}

/** Une séance de la bibliothèque annotée de son poids pour l'attribut demandé. */
export interface LibrarySession {
  id: string;
  name: string;
  primaryAttribute: AttributeKey;
  secondaryAttributes: AttributeKey[];
  requiresEquipment: boolean;
  durationMin: number;
  intensity: Session["intensity"];
  description: string;
  weight: number;
}

export interface LibraryResponse {
  attribute: string;
  sessions: LibrarySession[];
}

export interface CompleteSessionResponse {
  /** Vrai si une NOUVELLE complétion a été enregistrée ; faux si déjà faite aujourd'hui (idempotent). */
  recorded: boolean;
  sessionId: string;
  completedAt: string;
  /** Série après crédit (présente si le recalcul a réussi). */
  streak?: { current: number; best: number; thisWeekCount: number; weekValidated: boolean };
  /** Vrai si la série a bien été créditée (recalcul OK). On ne ment jamais au client. */
  streakCredited: boolean;
}

/** Projette une séance (annotée de son `weight`) sur la forme JSON attendue par le mobile. */
function toLibrarySession(s: Session & { weight: number }): LibrarySession {
  return {
    id: s.id,
    name: s.name,
    primaryAttribute: s.primaryAttribute,
    secondaryAttributes: s.secondaryAttributes,
    requiresEquipment: s.requiresEquipment,
    durationMin: s.durationMin,
    intensity: s.intensity,
    description: s.description,
    weight: s.weight,
  };
}

/**
 * Coach : l'utilisateur cible un attribut faible → on calcule l'Index PROJETÉ (autorité
 * score-service) et on propose des séances ciblées (filtrées selon le matériel disponible).
 */
@Injectable()
export class CoachService {
  private readonly logger = new Logger(CoachService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
    private readonly streak: StreakService,
  ) {}

  async coach(userId: string, attribute?: string): Promise<CoachResponse> {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    const scores = await this.prisma.attributeScore.findMany({ where: { userId } });
    const byAttr = new Map(scores.map((s) => [s.attribute, s]));
    const attributeScores = ATTRIBUTE_KEYS.map((a) => {
      const s = byAttr.get(a);
      return { attribute: a, score: s?.score ?? 0, unlocked: s?.unlocked ?? false, isEstimated: s?.isEstimated ?? false };
    });

    // Cible : l'attribut demandé, sinon le plus faible parmi les attributs débloqués.
    const unlocked = attributeScores.filter((a) => a.unlocked);
    const target =
      (attribute as (typeof ATTRIBUTE_KEYS)[number] | undefined) ??
      (unlocked.length > 0
        ? unlocked.reduce((min, a) => (a.score < min.score ? a : min)).attribute
        : ATTRIBUTE_KEYS[0]);

    const projection = await this.scoreClient.computeProjection({
      goal: profile.goal,
      targetAttribute: target,
      attributeScores,
    });

    const noGear = profile.equipmentPref === "none";
    const sessions = SESSIONS.filter(
      (s) => s.primaryAttribute === target && (!noGear || !s.requiresEquipment),
    ).slice(0, 8);

    return { targetAttribute: target, projection, sessions };
  }

  /**
   * Bibliothèque de séances qui touchent `attribute`, triée par poids (cf. seances-attributs-spec).
   * Filtre matériel selon la préférence du profil (`equipmentPref === "none"` ⇒ sans matériel).
   */
  async library(userId: string, attribute: AttributeKey): Promise<LibraryResponse> {
    const noGear = await this.noGearFor(userId);
    return { attribute, sessions: sessionsForAttribute(attribute, noGear).map(toLibrarySession) };
  }

  /**
   * Bibliothèque COMPLÈTE (filtre « Tout » du mobile) en UNE requête : toutes les séances curées,
   * dédupliquées, filtrées matériel, triées de façon stable (durée asc → nom). Remplace les 6
   * appels parallèles `library?attribute=…` côté client (anti N+1). `attribute` vaut "all" en
   * réponse (pas d'axe unique).
   */
  async libraryAll(userId: string): Promise<LibraryResponse> {
    const noGear = await this.noGearFor(userId);
    return { attribute: "all", sessions: allSessions(noGear).map(toLibrarySession) };
  }

  /** Préférence matériel du profil ⇒ true si l'utilisateur s'entraîne sans matériel. */
  private async noGearFor(userId: string): Promise<boolean> {
    const profile = await this.prisma.profile.findUnique({ where: { userId }, select: { equipmentPref: true } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });
    return profile.equipmentPref === "none";
  }

  /** La « séance de la semaine » (signature `weekly-forgeron`). */
  weekly(): { session: Session } {
    const session = weeklySession();
    if (!session) {
      throw new NotFoundException({ code: "NOT_FOUND", message: "Séance de la semaine introuvable." });
    }
    return { session };
  }

  /**
   * Marque une SÉANCE GUIDÉE comme faite (biblio coach / fin du chrono guidé). Persiste une
   * CoachSessionCompletion (trace consultable) PUIS crédite la SÉRIE hebdomadaire — SANS jamais
   * créer de wodResult ni toucher l'Athlete Index/radar/Ligue (une CoachSession n'a pas de barème).
   *
   * Idempotence raisonnable (anti-spam) : au plus UNE complétion comptée par (user, séance, jour).
   * Un second appel le même jour renvoie `recorded:false` mais réévalue la série (pas d'erreur).
   * Le crédit de série est best-effort : s'il échoue, on l'indique honnêtement (`streakCredited`).
   */
  async completeSession(userId: string, sessionId: string): Promise<CompleteSessionResponse> {
    // La séance doit exister dans le catalogue curé (pas de FK : ces séances ne vivent pas en base).
    const session = SESSIONS.find((s) => s.id === sessionId);
    if (!session) {
      throw new NotFoundException({ code: "NOT_FOUND", message: "Séance introuvable." });
    }
    // Le profil garantit un utilisateur onboardé (cohérent avec le reste du coach).
    const profile = await this.prisma.profile.findUnique({ where: { userId }, select: { userId: true } });
    if (!profile) throw new NotFoundException({ code: "NOT_FOUND", message: "Profil introuvable." });

    const now = new Date();
    // Jour UTC (DATE) — clé d'idempotence : 1 complétion comptée par séance et par jour.
    const completedDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));

    // upsert idempotent : crée si absent (recorded), sinon conserve la 1re complétion du jour.
    const existing = await this.prisma.coachSessionCompletion.findUnique({
      where: { userId_sessionId_completedDay: { userId, sessionId, completedDay } },
    });
    const completion =
      existing ??
      (await this.prisma.coachSessionCompletion.create({
        data: { userId, sessionId, completedDay, completedAt: now },
      }));
    const recorded = existing === null;

    // Crédit de série : on RÉUTILISE le hook existant (StreakService.evaluateAndGet) que les
    // wodResult utilisent déjà. activityCountInWeek compte désormais aussi les complétions guidées,
    // donc cette séance vaut une activité de la semaine. Best-effort : l'échec n'invalide pas la
    // complétion déjà persistée, mais on le signale (`streakCredited:false`) — on ne ment pas.
    let streak: StreakState | undefined;
    let streakCredited = false;
    try {
      streak = await this.streak.evaluateAndGet(userId, now);
      streakCredited = true;
    } catch (e) {
      this.logger.warn(`Série non créditée après séance guidée (${userId}/${sessionId}) : ${e}`);
    }

    return {
      recorded,
      sessionId,
      completedAt: completion.completedAt.toISOString(),
      streak: streak
        ? {
            current: streak.current,
            best: streak.best,
            thisWeekCount: streak.thisWeekCount,
            weekValidated: streak.weekValidated,
          }
        : undefined,
      streakCredited,
    };
  }
}
