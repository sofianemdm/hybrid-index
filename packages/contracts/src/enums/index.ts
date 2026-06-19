import { z } from "zod";

/**
 * Enums métier HYBRID INDEX — source de vérité unique (cf. docs/architecture.md §1.2).
 * Définis une seule fois ici, exposés via OpenAPI, régénérés côté Dart.
 */

/** Sexe = SEULE dimension de normalisation du score (décision verrouillée). */
export const Sex = z.enum(["male", "female"]);
export type Sex = z.infer<typeof Sex>;

/**
 * Les 6 attributs du radar. Ordre canonique (cf. sport-science §6.2).
 * Identifiants en anglais (décision D7) ; libellés FR via i18n côté affichage.
 * Correspondance FR : engine=Engine · speed=Vitesse · strength=Force · power=Puissance ·
 * muscular_endurance=Endurance musculaire · hybrid=Hybride.
 */
export const AttributeKey = z.enum([
  "engine",
  "speed",
  "strength",
  "power",
  "muscular_endurance",
  "hybrid",
]);
export type AttributeKey = z.infer<typeof AttributeKey>;

export const ATTRIBUTE_KEYS = AttributeKey.options;

/** Type d'un WOD (cf. §6.1). */
export const WodType = z.enum([
  "for_time",
  "amrap",
  "emom",
  "chipper",
  "strength",
  "interval",
]);
export type WodType = z.infer<typeof WodType>;

/** Nature de la métrique de score d'un WOD. */
export const ScoreType = z.enum(["time", "reps", "load", "distance"]);
export type ScoreType = z.infer<typeof ScoreType>;

/** Préférence de matériel (persistante). */
export const EquipmentPref = z.enum(["none", "equipped", "both"]);
export type EquipmentPref = z.infer<typeof EquipmentPref>;

/** Objectif de l'athlète → jeu de poids w_A de l'Index (cf. sport-science §6.2). */
export const Goal = z.enum(["hyrox", "crossfit_strength", "all_round"]);
export type Goal = z.infer<typeof Goal>;

/** Visibilité d'un profil. "public" verrouillé au MVP ; champ prévu pour l'avenir. */
export const Visibility = z.enum(["public", "private"]);
export type Visibility = z.infer<typeof Visibility>;

/** Provenance d'un résultat (anti-triche §5.5 ; "verified" préparé pour la Phase 3). */
export const ResultSource = z.enum(["declared", "verified"]);
export type ResultSource = z.infer<typeof ResultSource>;

/** Provenance d'une distribution de référence (cold-start §5.3). */
export const DistributionSource = z.enum(["public", "community"]);
export type DistributionSource = z.infer<typeof DistributionSource>;

/**
 * Rangs = paliers du Hybrid Index (cf. cahier §9.2, gamification §3.1).
 * Bornes : [min, max). Élite est inclusif jusqu'à 1000.
 */
export const Rank = z.enum([
  "rookie",
  "bronze",
  "silver",
  "gold",
  "platinum",
  "diamond",
  "elite",
]);
export type Rank = z.infer<typeof Rank>;

export interface RankBand {
  rank: Rank;
  min: number;
  /** Borne haute exclusive, sauf elite (inclusive à 1000). */
  max: number;
}

/** Source d'autorité des bornes de rang — DOIT rester identique à gamification.md §3.1. */
export const RANK_BANDS: readonly RankBand[] = [
  { rank: "rookie", min: 0, max: 150 },
  { rank: "bronze", min: 150, max: 300 },
  { rank: "silver", min: 300, max: 450 },
  { rank: "gold", min: 450, max: 600 },
  { rank: "platinum", min: 600, max: 750 },
  { rank: "diamond", min: 750, max: 900 },
  { rank: "elite", min: 900, max: 1000 },
] as const;

export const INDEX_MIN = 0;
export const INDEX_MAX = 1000;
