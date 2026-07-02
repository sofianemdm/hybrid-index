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
      { attribute: "speed", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(1080, 0.28), hardMin: 600, hardMax: 1800, proReference: 660 },
      female: { model: lognormalFromMedian(1200, 0.28), hardMin: 660, hardMax: 1980, proReference: 750 },
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
      male: { model: lognormalFromMedian(660, 0.34), hardMin: 105, hardMax: 1500, proReference: 135 },
      female: { model: lognormalFromMedian(780, 0.34), hardMin: 135, hardMax: 1800, proReference: 165 },
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
      male: { model: lognormalFromMedian(360, 0.36), hardMin: 55, hardMax: 1200, proReference: 90 },
      female: { model: lognormalFromMedian(420, 0.36), hardMin: 80, hardMax: 1500, proReference: 120 },
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
          [0.1, 870],
          [0.25, 660],
          [0.5, 570],
          [0.75, 465],
          [0.9, 390],
          [0.99, 315],
        ]),
        hardMin: 270,
        hardMax: 1800,
        proReference: 315,
      },
      female: {
        model: points([
          [0.1, 990],
          [0.25, 750],
          [0.5, 650],
          [0.75, 535],
          [0.9, 445],
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
      male: { model: lognormalFromMedian(450, 0.18), hardMin: 330, hardMax: 720, proReference: 370 },
      female: { model: lognormalFromMedian(510, 0.18), hardMin: 390, hardMax: 810, proReference: 435 },
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
      male: { model: lognormalFromMedian(750, 0.30), hardMin: 390, hardMax: 1320, proReference: 433 },
      female: { model: lognormalFromMedian(840, 0.30), hardMin: 450, hardMax: 1500, proReference: 510 },
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
          [0.1, 1080],
          [0.25, 840],
          [0.5, 690],
          [0.75, 540],
          [0.9, 420],
          [0.99, 300],
        ]),
        hardMin: 240,
        hardMax: 1500,
        proReference: 300,
      },
      female: {
        model: points([
          [0.1, 1230],
          [0.25, 990],
          [0.5, 825],
          [0.75, 645],
          [0.9, 510],
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
      male: { model: normal(12, 5.0), hardMin: 3, hardMax: 36, proReference: 27 },
      female: { model: normal(10, 4.2), hardMin: 2, hardMax: 30, proReference: 23 },
    },
  },

  // ---------------- 7 WODs SANS matériel ----------------
  {
    // « Profil Express » : séance d'entrée SANS MATÉRIEL couvrant les 6 qualités → débloque le
    // radar COMPLET mais en ESTIMÉ. Chaque attribut sera ensuite affiné/écrasé par une vraie
    // séance ciblée (réel > estimé, D2). Distribution calée sur le moteur d'estimation recalibré.
    id: "profil_express",
    name: "Profil Express",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "engine", estimated: true },
      { attribute: "speed", estimated: true },
      { attribute: "strength", estimated: true },
      { attribute: "power", estimated: true },
      { attribute: "muscular_endurance", estimated: true },
      { attribute: "hybrid", estimated: true },
    ],
    bySex: {
      male: {
        model: points([
          [0.1, 640],
          [0.5, 400],
          [0.9, 240],
          [0.99, 205],
        ]),
        hardMin: 185,
        hardMax: 1340,
        proReference: 210,
      },
      female: {
        model: points([
          [0.1, 760],
          [0.5, 470],
          [0.9, 272],
          [0.99, 232],
        ]),
        hardMin: 210,
        hardMax: 1670,
        proReference: 238,
      },
    },
  },
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
          [0.1, 1140],
          [0.25, 885],
          [0.5, 720],
          [0.75, 570],
          [0.9, 450],
          [0.99, 345],
        ]),
        hardMin: 270,
        hardMax: 1800,
        proReference: 345,
      },
      female: {
        model: points([
          [0.1, 1260],
          [0.25, 990],
          [0.5, 828],
          [0.75, 660],
          [0.9, 525],
          [0.99, 390],
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
          [0.1, 2640],
          [0.5, 1800],
          [0.9, 1200],
          [0.99, 1020],
        ]),
        hardMin: 810,
        hardMax: 3600,
        proReference: 1050,
      },
      female: {
        model: points([
          [0.1, 2940],
          [0.5, 2040],
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
      male: { model: lognormalFromMedian(990, 0.30), hardMin: 430, hardMax: 2400, proReference: 600 },
      female: { model: lognormalFromMedian(1140, 0.30), hardMin: 480, hardMax: 2700, proReference: 690 },
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
      male: { model: lognormalFromMedian(330, 0.35), hardMin: 145, hardMax: 720, proReference: 180 },
      female: { model: lognormalFromMedian(390, 0.35), hardMin: 165, hardMax: 840, proReference: 210 },
    },
  },
  {
    // 400 m : sprint-endurance anaérobie, allure strictement plus rapide qu'au 1 km. Vitesse dominante
    // + moteur. Distributions sport-science (allure médiane 32,5 s/100 m H, bornes sous le record mondial).
    id: "run_400",
    name: "400 m Course",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "speed", estimated: false },
      { attribute: "engine", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(130, 0.34), hardMin: 50, hardMax: 300, proReference: 68 },
      female: { model: lognormalFromMedian(154, 0.34), hardMin: 56, hardMax: 340, proReference: 76 },
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
      male: { model: normal(20, 13), hardMin: 0, hardMax: 110, proReference: 60 },
      female: { model: normal(10, 8), hardMin: 0, hardMax: 80, proReference: 35 },
    },
  },
  {
    id: "max_air_squats_2min",
    name: "Max squats en 2 min",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "power", estimated: false },
    ],
    bySex: {
      male: { model: normal(42, 16), hardMin: 10, hardMax: 130, proReference: 85 },
      female: { model: normal(38, 15), hardMin: 10, hardMax: 125, proReference: 80 },
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
      male: { model: normal(58, 24), hardMin: 15, hardMax: 160, proReference: 125 },
      female: { model: normal(48, 21), hardMin: 12, hardMax: 145, proReference: 110 },
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
      male: { model: lognormalFromMedian(750, 0.31), hardMin: 330, hardMax: 1500, proReference: 360 },
      female: { model: lognormalFromMedian(840, 0.31), hardMin: 360, hardMax: 1680, proReference: 420 },
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
      male: { model: lognormalFromMedian(1980, 0.30), hardMin: 780, hardMax: 3300, proReference: 1050 },
      female: { model: lognormalFromMedian(2280, 0.30), hardMin: 855, hardMax: 3600, proReference: 1170 },
    },
  },
  {
    // Max squats à vide en UNE série, à l'échec (≠ max_air_squats_2min plafonné). Endurance
    // musculaire dominante + Force estimée (proxy bodyweight, analogie D2). sport-science 20 juin.
    id: "max_air_squats",
    name: "Max squats (une série, à l'échec)",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "strength", estimated: true },
    ],
    bySex: {
      male: { model: normal(65, 38), hardMin: 15, hardMax: 300, proReference: 150 },
      female: { model: normal(55, 34), hardMin: 15, hardMax: 280, proReference: 135 },
    },
  },
  {
    // Max tractions strictes en UNE série (pronation, sans élan), à l'échec. Mesure de FORCE de
    // tirage réelle (le tirage vertical dos/biceps est l'étalon haut-du-corps, la majorité plafonne
    // < 15 reps → chaque rep mobilise un % élevé de la force) + endurance musculaire. ≠ pompes :
    // strength en RÉEL ici (pas un simple proxy). Distribution sport-science 24 juin (normes
    // calisthénie/ACSM). Forte asymétrie → normal tronqué à 0.
    id: "max_strict_pullups",
    name: "Max tractions strictes (une série)",
    scoreType: "reps",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "strength", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
    ],
    bySex: {
      male: { model: normal(6, 7), hardMin: 0, hardMax: 50, proReference: 30 },
      female: { model: normal(2, 3.5), hardMin: 0, hardMax: 35, proReference: 18 },
    },
  },
  {
    // Back squat 1RM en CHARGE ABSOLUE (kg), 1 rép max. L'app n'ayant pas le poids de corps ici, on
    // note la charge absolue, normalisée PAR SEXE (décision verrouillée → intègre la morphologie
    // H/F). Force des membres inférieurs = mesure de FORCE pure (estimated:false). power ajouté en
    // ESTIMÉ : un 1RM élevé conditionne la puissance mais un test à 1 rép lente ne mesure pas la
    // vitesse. Distribution sport-science 24 juin (tables ExRx/Strength Level « Intermediate »).
    id: "squat_1rm",
    name: "Squat 1RM (charge max, 1 rép)",
    scoreType: "load",
    requiresEquipment: true,
    isBenchmark: true,
    targetAttributes: [
      { attribute: "strength", estimated: false },
      { attribute: "power", estimated: true },
    ],
    bySex: {
      male: { model: normal(85, 42), hardMin: 20, hardMax: 320, proReference: 220 },
      female: { model: normal(52, 28), hardMin: 15, hardMax: 220, proReference: 145 },
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
      male: { model: lognormalFromMedian(5700, 0.255), hardMin: 3000, hardMax: 9000, proReference: 3119 },
      female: { model: lognormalFromMedian(6300, 0.255), hardMin: 3150, hardMax: 9600, proReference: 3265 },
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
      male: { model: lognormalFromMedian(165, 0.46), hardMin: 45, hardMax: 600, proReference: 55 },
      female: { model: lognormalFromMedian(210, 0.46), hardMin: 55, hardMax: 700, proReference: 70 },
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
      male: { model: lognormalFromMedian(3300, 0.32), hardMin: 1850, hardMax: 6000, proReference: 2000 },
      female: { model: lognormalFromMedian(3600, 0.30), hardMin: 2100, hardMax: 6600, proReference: 2400 },
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
      male: { model: lognormalFromMedian(3300, 0.32), hardMin: 1500, hardMax: 6000, proReference: 1571 },
      female: { model: lognormalFromMedian(3600, 0.31), hardMin: 1680, hardMax: 6600, proReference: 1734 },
    },
  },
  {
    // Semi-marathon. WR H 57:20 (Kiplimo), F 1:02:52 (Gidey). proReference = WR.
    // Médiane FINISHER grand public ≈ 1h57 H / 2h10 F ; sigmaLn 0.20 → P10 (débutant) ≈
    // 2h35 H / 2h52 F. σ alignée sur le marathon pour une queue lente réaliste.
    // Sources : RunRepeat « Half-Marathon Statistics » (percentiles de finish par sexe).
    id: "half_marathon",
    name: "Semi-marathon",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: { model: lognormalFromMedian(7000, 0.24), hardMin: 3300, hardMax: 14400, proReference: 3440 },
      female: { model: lognormalFromMedian(7800, 0.24), hardMin: 3650, hardMax: 16200, proReference: 3772 },
    },
  },
  {
    // Marathon. WR H 2:00:35 (Kiptum), F 2:09:56 (Chepngetich). proReference = WR.
    // Médiane FINISHER grand public ≈ 4h20 H / 4h40 F ; sigmaLn 0.20 → P10 (débutant qui
    // termine, souvent près de la barrière horaire) ≈ 5h35 H / 6h00 F. La σ 0.22 d'avant
    // resserrait trop la queue lente (le « débutant » tombait à ~5h00, irréaliste).
    // Sources : RunRepeat « Marathon Statistics » + Marastats/IAAF (percentiles de finish).
    id: "marathon",
    name: "Marathon",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [{ attribute: "engine", estimated: false }],
    bySex: {
      male: { model: lognormalFromMedian(15600, 0.24), hardMin: 7000, hardMax: 36000, proReference: 7170 },
      female: { model: lognormalFromMedian(16800, 0.24), hardMin: 7600, hardMax: 39600, proReference: 7796 },
    },
  },

  // ---------------- 5 WODs « LIGUE DU MOIS » (sans matériel, 8–15 min, 1 qualité/semaine) ----------------
  // Dédiés à la Ligue (isBenchmark:false = CACHÉS du catalogue via HIDDEN_WOD_IDS, PAS exclus de
  // l'Index : leurs perfs comptent pour le radar/l'Index comme tout WOD). Barèmes estimation `low`, à
  // recalibrer N≥200/sexe après le 1er mois. Spec : docs/wods-ligue-mensuelle.md (sport-science).
  {
    // Semaine 1 — VITESSE. Intervalles de course en échelle (100-200-300-400-300-200-100 = 1500 m),
    // 1 min de récup imposée entre chaque sprint (6 récups) et CHRONO CONTINU : le score = temps TOTAL,
    // récups d'1 min COMPRISES (choix produit 01/07 : plus simple à chronométrer). Recalibrage 01/07 :
    // +360 s (6×60 s de récup fixe) ajoutés à toutes les valeurs ; médiane = pratiquant régulier
    // ~13:30 total (M) / ~14:30 (F) ; champion hybride élite ~10:30 (M) / ~11:10 (F) ; débutant motivé
    // ~16:30 (M) / ~18:00 (F). σ RESSERRÉ 0.16 (les 6 min de récup FIXE réduisent l'écart relatif :
    // le temps de course varie mais la part récup, constante, comprime la dispersion → 0.30 → 0.16).
    id: "league_sprint_ladder",
    name: "La Flèche",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [
      { attribute: "speed", estimated: false },
      { attribute: "engine", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(810, 0.16), hardMin: 610, hardMax: 1260, proReference: 630 },
      female: { model: lognormalFromMedian(870, 0.16), hardMin: 650, hardMax: 1380, proReference: 670 },
    },
  },
  {
    // Semaine 2 — ENDURANCE (moteur aérobie). AMRAP 12 min, tour ≥3 min (400m course + 20 air squats
    // + 15 burpees = 35 reps/tour). Score = REPS totales (air squats + burpees) ; la course est imposée
    // mais NE COMPTE PAS dans le score (choix produit : saisie simple). Recalibrage 29/06 : un tour
    // complet « 400 m + 35 reps » prend ~2:45-3:15, donc médiane = pratiquant régulier ≈ 4 tours = 140
    // reps (M) / ~3 tours = 100 reps (F, course plus lente) ; champion hybride ≈ 6 tours = 215/160 ;
    // débutant ≈ 2 tours = 70-75/52. σ ≈ 0.3·µ (dispersion typique d'un AMRAP cardio reps).
    id: "league_engine_12",
    name: "Le Moteur",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [
      { attribute: "engine", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "hybrid", estimated: false },
    ],
    bySex: {
      male: { model: normal(140, 42), hardMin: 40, hardMax: 320, proReference: 215 },
      female: { model: normal(100, 32), hardMin: 30, hardMax: 250, proReference: 160 },
    },
  },
  {
    // Semaine 3 — FORCE-ENDURANCE (bas du corps). AMRAP 12 min, tour ≥3 min (40 fentes + 30 squats +
    // 20 sit-ups + 16 pistols = 106 reps/tour). Score = reps totales. Recalibrage 29/06 : les pistols
    // (lents, ~0.3 rep/s régulier) bornent le débit, un tour complet prend ~3:30-4:00 ⇒ médiane =
    // pratiquant régulier ≈ 3 tours = 320 reps (M) / ~2,2 tours = 235 (F) ; champion ≈ 5 tours = 540/415 ;
    // débutant ≈ 1,5 tour = 160/120 (pistols souvent scalés, d'où la queue basse). σ ≈ 0.35·µ.
    id: "league_grind_squats",
    name: "Le Pilier",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [
      { attribute: "muscular_endurance", estimated: false },
      { attribute: "strength", estimated: true },
    ],
    bySex: {
      male: { model: normal(320, 110), hardMin: 90, hardMax: 760, proReference: 540 },
      female: { model: normal(235, 82), hardMin: 70, hardMax: 560, proReference: 415 },
    },
  },
  {
    // Semaine 4 — PUISSANCE. AMRAP 12 min, tour ≥3 min (30 squat jumps + 25 burpee broad jumps =
    // 55 reps/tour, 100 % explosif). Score = reps totales. Jamais d'EMOM (décision produit).
    // Recalibrage 29/06 : format 100 % explosif → forte dégradation, un tour propre prend ~3:30-4:00 ⇒
    // médiane = pratiquant régulier ≈ 3 tours = 170 reps (M) / ~2 tours = 105 (F) ; champion ≈ 6 tours
    // = 330/200 (rare maintien de la détente) ; débutant ≈ 1,7 tour = 95/58. σ ≈ 0.37·µ (puissance =
    // qualité la plus dispersée).
    id: "league_power_amrap",
    name: "La Détente",
    scoreType: "reps",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [
      { attribute: "power", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
    ],
    bySex: {
      male: { model: normal(170, 62), hardMin: 50, hardMax: 480, proReference: 330 },
      female: { model: normal(105, 40), hardMin: 30, hardMax: 300, proReference: 200 },
    },
  },
  {
    // Semaine 5 — HYBRIDE (chipper for time, cap 15 min). Le profil complet/équilibré brille.
    // Recalibrage 29/06 : chipper long (course + gym + explosif), médiane = pratiquant régulier qui
    // boucle en ~12:00 (M, 720 s) / ~13:10 (F, 790 s) sous le cap ; champion hybride ≈ 7:10 (M, 430 s) /
    // ~7:50 (F, 470 s) ; débutant proche du cap (~17:00 → ramené à 1020/1080 s, beaucoup tapent le cap).
    // σ 0.30/0.28 : queue lente réaliste mais bornée par le cap 15 min.
    id: "league_hybrid_chipper",
    name: "Le Chaos",
    scoreType: "time",
    requiresEquipment: false,
    isBenchmark: false,
    targetAttributes: [
      { attribute: "hybrid", estimated: false },
      { attribute: "engine", estimated: false },
      { attribute: "muscular_endurance", estimated: false },
    ],
    bySex: {
      male: { model: lognormalFromMedian(720, 0.30), hardMin: 360, hardMax: 1200, proReference: 430 },
      female: { model: lognormalFromMedian(790, 0.28), hardMin: 420, hardMax: 1200, proReference: 470 },
    },
  },
];

export const WODS_BY_ID: ReadonlyMap<string, WodDefinition> = new Map(WODS.map((w) => [w.id, w]));
