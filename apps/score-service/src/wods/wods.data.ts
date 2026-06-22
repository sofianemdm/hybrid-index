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
    // 3 km : ~9-16 min d'effort aérobie soutenu = moteur pur (comme le 5 km). sport-science 22 juin.
    id: "run_3k",
    name: "3 km Course",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: { model: lognormalFromMedian(990, 0.22), hardMin: 430, hardMax: 2400, proReference: 600 },
      female: { model: lognormalFromMedian(1170, 0.22), hardMin: 480, hardMax: 2700, proReference: 690 },
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

  // ---------------- Épreuves « Autre » jouables (sport-science, 22 juin) ----------------
  // Ajoutées comme séances classables. proReference = record/élite réel sourcé ; médiane =
  // amateur finisher médian. NE PAS confondre avec les 15 WODs benchmark de l'Index.
  {
    // HYROX solo (8×1 km course + 8 stations). Record H 51:59 (Roncevic), F 54:25 (Wietrzyk).
    // Médiane amateur finisher ≈ 1h30 H / 1h40 F (bases de temps HYROX publiques).
    id: "hyrox_solo",
    name: "HYROX (solo)",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: false,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "power", estimated: false },
      { attribute: "hybrid", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(5400, 0.21), hardMin: 3000, hardMax: 9000, proReference: 3119 },
      female: { model: lognormalFromMedian(6000, 0.21), hardMin: 3150, hardMax: 9600, proReference: 3265 },
    },
  },
  {
    // Isabel : 30 arrachés 61/43 kg. Sprint haltéro très dispersé. Élite H ~55 s / F ~70 s.
    // Médiane amateur ≈ 150 s H / 190 s F. proReference = niveau élite (≠ record absolu 51 s).
    id: "isabel",
    name: "Isabel",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: false,
    targetAttributes: [
      { attribute: "power", estimated: false },
      { attribute: "strength", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(150, 0.34), hardMin: 45, hardMax: 600, proReference: 55 },
      female: { model: lognormalFromMedian(190, 0.34), hardMin: 55, hardMax: 700, proReference: 70 },
    },
  },
  {
    // Murph (gilet) : 1,6 km + 100 tractions + 200 pompes + 300 squats + 1,6 km. Record ≈ 32:41
    // (Blenis). Médiane amateur ≈ 55 min H / 60 min F. proReference = élite gilet ≈ 2000/2400 s.
    id: "murph",
    name: "Murph",
    scoreType: "time",
    requiresEquipment: true,
    isBenchmark: false,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "hybrid", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(3300, 0.3), hardMin: 1850, hardMax: 6000, proReference: 2000 },
      female: { model: lognormalFromMedian(3600, 0.3), hardMin: 2100, hardMax: 6600, proReference: 2400 },
    },
  },
  {
    // 10 000 m piste. WR H 26:11 (Cheptegei), F 28:54 (Chebet). Médiane amateur ≈ 55 min H / 60 min F.
    // proReference = WR. sigmaLn 0.24 (haut de fourchette : WR très éloigné de l'amateur médian).
    id: "track_10000m",
    name: "10 000 m (piste)",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: { model: lognormalFromMedian(3300, 0.24), hardMin: 1500, hardMax: 6000, proReference: 1571 },
      female: { model: lognormalFromMedian(3600, 0.24), hardMin: 1680, hardMax: 6600, proReference: 1734 },
    },
  },
  {
    // Semi-marathon. WR H 57:20 (Kiplimo), F 1:02:52 (Gidey). Médiane amateur ≈ 2h H / 2h15 F.
    // proReference = WR. sigmaLn 0.22 (course longue ; WR super-élite donc loin de la médiane).
    id: "half_marathon",
    name: "Semi-marathon",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: { model: lognormalFromMedian(7200, 0.22), hardMin: 3300, hardMax: 14400, proReference: 3440 },
      female: { model: lognormalFromMedian(8100, 0.22), hardMin: 3650, hardMax: 16200, proReference: 3772 },
    },
  },
  {
    // Marathon. WR H 2:00:35 (Kiptum), F 2:09:56 (Chepngetich). Médiane amateur ≈ 4h30 H / 4h50 F.
    // proReference = WR. sigmaLn 0.22 (course longue ; WR super-élite).
    id: "marathon",
    name: "Marathon",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: { model: lognormalFromMedian(16200, 0.22), hardMin: 7000, hardMax: 36000, proReference: 7235 },
      female: { model: lognormalFromMedian(17400, 0.22), hardMin: 7600, hardMax: 39600, proReference: 7796 },
    },
  },
];

export const WODS_BY_ID: ReadonlyMap<string, WodDefinition> = new Map(WODS.map((w) => [w.id, w]));
