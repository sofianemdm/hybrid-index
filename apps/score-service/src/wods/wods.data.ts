import { lognormalFromMedian } from "@hybrid-index/scoring-core";
import type { DistributionModel } from "@hybrid-index/scoring-core";
import type { WodDefinition } from "./wod.types";

/**
 * Registre seedé des 15 WODs de référence (cf. sport-science §1, §2.2, §2.3).
 * Source d'autorité du calcul de sous-score. Les distributions `low` confidence
 * (Benchmark Zéro #9, burpees #14, air squats #13) seront recalibrées sur la communauté (N≥200/sexe).
 *
 * Convention : `time` → dir -1 (plus bas meilleur) ; `reps` → dir +1 (plus haut meilleur).
 * Cas particulier Grace : la source donne moyenne arithmétique + σ → µ_ln = ln(mean) − σ_ln²/2
 * (pour reproduire le worked example A). Les autres log-normaux prennent R50 comme médiane.
 */

const lnArithMean = (mean: number, sigmaLn: number): DistributionModel => ({
  kind: "lognormal",
  muLn: Math.log(mean) - sigmaLn ** 2 / 2,
  sigmaLn,
  dir: -1,
});

const normal = (mu: number, sigma: number): DistributionModel => ({ kind: "normal", mu, sigma, dir: 1 });

const points = (nodes: Array<[number, number]>): DistributionModel => ({
  kind: "pointTable",
  dir: -1,
  nodes: nodes.map(([p, r]) => ({ p, r })),
});

export const WODS: ReadonlyArray<WodDefinition> = [
  // ---------------- 8 WODs AVEC matériel ----------------
  {
    id: "hyrox_sprint",
    name: "Sprint HYROX",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "power", estimated: false },
      { attribute: "hybrid", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(960, 0.16), hardMin: 600, hardMax: 1800, proReference: 660 },
      female: { model: lognormalFromMedian(1080, 0.16), hardMin: 660, hardMax: 1980, proReference: 750 },
    },
  },
  {
    id: "fran",
    name: "Fran",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "power", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(345, 0.3), hardMin: 105, hardMax: 1500, proReference: 135 },
      female: { model: lognormalFromMedian(390, 0.3), hardMin: 135, hardMax: 1800, proReference: 165 },
    },
  },
  {
    id: "grace",
    name: "Grace",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "power", estimated: false },
      { attribute: "strength", estimated: false },
    ],
    bySex: {
      male: { model: lnArithMean(203, 0.43), hardMin: 55, hardMax: 1200, proReference: 90 },
      female: { model: lnArithMean(236, 0.39), hardMin: 80, hardMax: 1500, proReference: 120 },
    },
  },
  {
    id: "jackie",
    name: "Jackie",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "power", estimated: false },
      { attribute: "strength", estimated: false },
    ],
    bySex: {
      male: {
        model: points([
          [0.1, 720],
          [0.25, 540],
          [0.5, 480],
          [0.75, 420],
          [0.9, 375],
          [0.99, 315],
        ]),
        hardMin: 270,
        hardMax: 1800,
        proReference: 315,
      },
      female: {
        model: points([
          [0.1, 840],
          [0.25, 630],
          [0.5, 555],
          [0.75, 480],
          [0.9, 435],
          [0.99, 360],
        ]),
        hardMin: 315,
        hardMax: 2100,
        proReference: 360,
      },
    },
  },
  {
    id: "row_2k",
    name: "2000 m Rameur",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: { model: lognormalFromMedian(450, 0.085), hardMin: 330, hardMax: 720, proReference: 370 },
      female: { model: lognormalFromMedian(510, 0.085), hardMin: 390, hardMax: 810, proReference: 435 },
    },
  },
  {
    id: "helen",
    name: "Helen",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "hybrid", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(590, 0.16), hardMin: 390, hardMax: 1320, proReference: 433 },
      female: { model: lognormalFromMedian(674, 0.16), hardMin: 450, hardMax: 1500, proReference: 510 },
    },
  },
  {
    id: "karen",
    name: "Karen",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "power", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
    ],
    bySex: {
      male: {
        model: points([
          [0.1, 840],
          [0.25, 660],
          [0.5, 555],
          [0.75, 450],
          [0.9, 390],
          [0.99, 300],
        ]),
        hardMin: 240,
        hardMax: 1500,
        proReference: 300,
      },
      female: {
        model: points([
          [0.1, 960],
          [0.25, 780],
          [0.5, 660],
          [0.75, 540],
          [0.9, 465],
          [0.99, 360],
        ]),
        hardMin: 270,
        hardMax: 1680,
        proReference: 360,
      },
    },
  },
  {
    id: "cindy",
    name: "Cindy",
    scoreType: "reps",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "engine", estimated: false },
    ],
    bySex: {
      male: { model: normal(15, 4.0), hardMin: 3, hardMax: 36, proReference: 27 },
      female: { model: normal(12, 3.5), hardMin: 2, hardMax: 30, proReference: 23 },
    },
  },

  // ---------------- 7 WODs SANS matériel ----------------
  {
    id: "benchmark_zero",
    name: "Benchmark Zéro",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "hybrid", estimated: false },
    ],
    bySex: {
      male: {
        model: points([
          [0.1, 900],
          [0.25, 720],
          [0.5, 570],
          [0.75, 480],
          [0.9, 405],
          [0.99, 330],
        ]),
        hardMin: 270,
        hardMax: 1800,
        proReference: 345,
      },
      female: {
        model: points([
          [0.1, 1020],
          [0.25, 810],
          [0.5, 645],
          [0.75, 540],
          [0.9, 465],
          [0.99, 375],
        ]),
        hardMin: 300,
        hardMax: 2040,
        proReference: 390,
      },
    },
  },
  {
    id: "run_5k",
    name: "5 km Course",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: {
        model: points([
          [0.1, 2400],
          [0.5, 1620],
          [0.9, 1170],
          [0.99, 1020],
        ]),
        hardMin: 810,
        hardMax: 3600,
        proReference: 1050,
      },
      female: {
        model: points([
          [0.1, 2700],
          [0.5, 1860],
          [0.9, 1350],
          [0.99, 1170],
        ]),
        hardMin: 900,
        hardMax: 3900,
        proReference: 1170,
      },
    },
  },
  {
    id: "run_1k",
    name: "1 km Course",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "speed", estimated: false },
      { attribute: "engine", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(300, 0.22), hardMin: 145, hardMax: 720, proReference: 180 },
      female: { model: lognormalFromMedian(360, 0.22), hardMin: 165, hardMax: 840, proReference: 210 },
    },
  },
  {
    id: "max_pushups",
    name: "Max pompes strictes",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      // Proxy bodyweight → Force estimée (D2) ; mesure légitime d'endurance musculaire.
      { attribute: "strength", estimated: true },
      { attribute: "muscular_endurance", estimated: false },
    ],
    bySex: {
      male: { model: normal(25, 11), hardMin: 0, hardMax: 110, proReference: 60 },
      female: { model: normal(12, 7), hardMin: 0, hardMax: 80, proReference: 35 },
    },
  },
  {
    id: "max_air_squats_2min",
    name: "Max air squats en 2 min",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "power", estimated: false },
    ],
    bySex: {
      male: { model: normal(50, 12), hardMin: 10, hardMax: 130, proReference: 85 },
      female: { model: normal(45, 11), hardMin: 10, hardMax: 125, proReference: 80 },
    },
  },
  {
    id: "burpees_7min",
    name: "Test burpees 7 min",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "power", estimated: false },
      { attribute: "hybrid", estimated: false },
    ],
    bySex: {
      male: { model: normal(70, 18), hardMin: 15, hardMax: 160, proReference: 125 },
      female: { model: normal(60, 16), hardMin: 12, hardMax: 145, proReference: 110 },
    },
  },
  {
    id: "ergo_skill",
    name: "Machine & Mur",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "strength", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "engine", estimated: false },
      { attribute: "power", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(600, 0.19), hardMin: 330, hardMax: 1500, proReference: 360 },
      female: { model: lognormalFromMedian(690, 0.19), hardMin: 360, hardMax: 1680, proReference: 420 },
    },
  },
  {
    // Course à DISTANCE LIBRE : l'utilisateur saisit (distance_m, time_s). Le score-service
    // normalise via Riegel (t_5k = time × (5000/distance)^1.06) puis score contre cette
    // distribution 5 km (sport-science, 20 juin). Bornes réelles dérivées de l'allure et tag
    // `speed` conditionnel (distance ≤ 1 km) gérés dans la couche de scoring, PAS ici.
    id: "run_free_distance",
    name: "Course distance libre",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: { model: lognormalFromMedian(1620, 0.22), hardMin: 780, hardMax: 3300, proReference: 1050 },
      female: { model: lognormalFromMedian(1860, 0.22), hardMin: 855, hardMax: 3600, proReference: 1170 },
    },
  },
  {
    // Max squats à vide en UNE série, à l'échec (≠ max_air_squats_2min plafonné). Endurance
    // musculaire dominante + Force estimée (proxy bodyweight, analogie D2). sport-science 20 juin.
    id: "max_air_squats",
    name: "Max air squats (une série, à l'échec)",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "strength", estimated: true },
    ],
    bySex: {
      male: { model: normal(80, 30), hardMin: 15, hardMax: 300, proReference: 150 },
      female: { model: normal(70, 27), hardMin: 15, hardMax: 280, proReference: 135 },
    },
  },
];

export const WODS_BY_ID: ReadonlyMap<string, WodDefinition> = new Map(WODS.map((w) => [w.id, w]));
