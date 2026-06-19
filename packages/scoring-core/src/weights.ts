import type { AttributeKey, Goal } from "@hybrid-index/contracts";

/**
 * Jeux de poids w_A par objectif (`weights-v1`, cf. sport-science §6.2).
 * Changer d'objectif ne modifie jamais les sous-scores — seulement l'agrégation.
 * VERSIONNÉ avec la courbe (scoringVersion côté service).
 */
export const WEIGHTS_VERSION = "weights-v1";

export const WEIGHTS_V1: Record<Goal, Record<AttributeKey, number>> = {
  hyrox: {
    engine: 1.5,
    speed: 1.0,
    strength: 0.7,
    power: 1.0,
    muscular_endurance: 1.3,
    hybrid: 1.5,
  },
  crossfit_strength: {
    engine: 0.8,
    speed: 0.8,
    strength: 1.5,
    power: 1.5,
    muscular_endurance: 1.2,
    hybrid: 1.0,
  },
  all_round: {
    engine: 1.0,
    speed: 1.0,
    strength: 1.0,
    power: 1.0,
    muscular_endurance: 1.0,
    hybrid: 1.0,
  },
};
