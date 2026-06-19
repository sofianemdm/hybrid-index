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
    id: "pft_hyrox",
    name: "PFT HYROX",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "power", estimated: false },
      { attribute: "hybrid", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(5100, 0.18), hardMin: 840, hardMax: 3600, proReference: 3300 },
      female: { model: lognormalFromMedian(5700, 0.18), hardMin: 960, hardMax: 4200, proReference: 3660 },
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
          [0.1, 780],
          [0.25, 600],
          [0.5, 540],
          [0.75, 480],
          [0.9, 450],
          [0.99, 360],
        ]),
        hardMin: 300,
        hardMax: 1800,
        proReference: 360,
      },
      female: {
        model: points([
          [0.1, 900],
          [0.25, 720],
          [0.5, 630],
          [0.75, 540],
          [0.9, 510],
          [0.99, 420],
        ]),
        hardMin: 360,
        hardMax: 2100,
        proReference: 420,
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
          [0.5, 570],
          [0.75, 420],
          [0.9, 390],
          [0.99, 240],
        ]),
        hardMin: 210,
        hardMax: 1500,
        proReference: 240,
      },
      female: {
        model: points([
          [0.1, 900],
          [0.25, 720],
          [0.5, 630],
          [0.75, 480],
          [0.9, 450],
          [0.99, 300],
        ]),
        hardMin: 240,
        hardMax: 1680,
        proReference: 300,
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
      male: { model: normal(16, 4.0), hardMin: 3, hardMax: 32, proReference: 23 },
      female: { model: normal(13, 3.5), hardMin: 2, hardMax: 28, proReference: 20 },
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
          [0.1, 1200],
          [0.25, 960],
          [0.5, 810],
          [0.75, 690],
          [0.9, 600],
          [0.99, 540],
        ]),
        hardMin: 390,
        hardMax: 2100,
        proReference: 540,
      },
      female: {
        model: points([
          [0.1, 1380],
          [0.25, 1140],
          [0.5, 960],
          [0.75, 810],
          [0.9, 720],
          [0.99, 630],
        ]),
        hardMin: 450,
        hardMax: 2400,
        proReference: 630,
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
          [0.1, 3202],
          [0.5, 1878],
          [0.9, 1326],
          [0.99, 1069],
        ]),
        hardMin: 810,
        hardMax: 4200,
        proReference: 1050,
      },
      female: {
        model: points([
          [0.1, 3391],
          [0.5, 2184],
          [0.9, 1516],
          [0.99, 1169],
        ]),
        hardMin: 900,
        hardMax: 4500,
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
    id: "max_situps_2min",
    name: "Max sit-ups en 2 min",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [{ attribute: "muscular_endurance", estimated: false }],
    bySex: {
      male: { model: normal(50, 11), hardMin: 10, hardMax: 105, proReference: 80 },
      female: { model: normal(45, 11), hardMin: 10, hardMax: 105, proReference: 80 },
    },
  },
];

export const WODS_BY_ID: ReadonlyMap<string, WodDefinition> = new Map(WODS.map((w) => [w.id, w]));
