import { Injectable, NotFoundException } from "@nestjs/common";
import { ATTRIBUTE_KEYS, type internalScore } from "@hybrid-index/contracts";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ScoreClient } from "../../infra/score-client/score-client.service";
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
  constructor(
    private readonly prisma: PrismaService,
    private readonly scoreClient: ScoreClient,
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
}
