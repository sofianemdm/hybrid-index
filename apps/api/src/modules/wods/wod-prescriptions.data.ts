/**
 * Registre des PRESCRIPTIONS concrètes des 17 séances de référence HYBRID INDEX.
 * « Ce que c'est » + « ce que tu dois faire », avec poids RX (standard) et version allégée (L1),
 * homme ET femme. Profondeur « Essentiel » : pas de standards de mouvement détaillés, pas de pacing.
 *
 * Source d'autorité : agent sport-science.
 * - Benchmarks CrossFit (Fran, Grace, Jackie, Helen, Karen, Cindy) : standards CANONIQUES,
 *   livres convertis aux paliers de barre réalistes (43/30, 61/43, 20/15, 9/6, 24/16 kg…).
 * - Séances maison (Sprint HYROX, Benchmark Zéro, Machine & Mur, courses) : structures alignées
 *   sur les médianes de score de `apps/score-service/src/wods/wods.data.ts`.
 *
 * Contenu fixe (pas de migration DB).
 */
import type { WodPrescription } from "./wod-prescription.types";

const SCORE_TIME = "Tu enregistres ton temps total pour finir la séance.";
const SCORE_REPS = "Tu enregistres ton nombre total de répétitions.";

export const WOD_PRESCRIPTIONS: Record<string, WodPrescription> = {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. Sprint HYROX (maison, avec matériel) — médiane H 900 s (~15 min) / F 1020 s
  //    Structure cardio HYROX type : course + machine ergo + wall balls, en triplet.
  // ─────────────────────────────────────────────────────────────────────────
  hyrox_sprint: {
    summary:
      "Séance cardio façon HYROX : 3 TOURS de (500 m course + 500 m rameur + 20 wall balls), enchaînés " +
      "sans repos. Au total : 1500 m course + 1500 m rameur + 60 wall balls. Teste ton moteur sous fatigue.",
    format: "3 tours pour le temps",
    timeCapSec: 1500,
    blocks: [
      { reps: "3 tours :", movement: "à enchaîner sans repos" },
      { reps: "→ 500 m", movement: "Course" },
      { reps: "→ 500 m", movement: "Rameur", detail: "ou 400 m SkiErg" },
      { reps: "→ 20", movement: "Wall balls" },
    ],
    weights: [
      {
        movement: "Wall ball",
        rxMale: 9,
        rxFemale: 6,
        scaledMale: 6,
        scaledFemale: 4,
        unit: "kg",
        note: "cible 3 m (H) / 2,70 m (F)",
      },
    ],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Fran (benchmark) — 21-15-9 Thrusters + Tractions, Thruster 43/30 kg.
  // ─────────────────────────────────────────────────────────────────────────
  fran: {
    summary:
      "Le benchmark CrossFit le plus connu : un couplet thrusters / tractions en 21-15-9. " +
      "Court, intense et brûlant. Référence universelle de puissance et d'endurance musculaire.",
    format: "21-15-9, pour le temps",
    timeCapSec: 600,
    blocks: [
      { reps: "21-15-9", movement: "Thrusters" },
      { reps: "21-15-9", movement: "Tractions" },
    ],
    weights: [
      {
        movement: "Thruster",
        rxMale: 43,
        rxFemale: 30,
        scaledMale: 30,
        scaledFemale: 20,
        unit: "kg",
        note: "barre",
      },
    ],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Grace (benchmark) — 30 Épaulés-jetés, 61/43 kg.
  // ─────────────────────────────────────────────────────────────────────────
  grace: {
    summary:
      "30 épaulés-jetés pour le temps. Test de puissance et de filière lactique : aller vite " +
      "sur une charge modérée sans casser le rythme.",
    format: "30 répétitions, pour le temps",
    timeCapSec: 300,
    blocks: [{ reps: "30", movement: "Épaulés-jetés", detail: "clean & jerk" }],
    weights: [
      {
        movement: "Épaulé-jeté",
        rxMale: 61,
        rxFemale: 43,
        scaledMale: 43,
        scaledFemale: 30,
        unit: "kg",
        note: "barre",
      },
    ],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Jackie (benchmark) — 1000 m Rameur, 50 Thrusters barre à vide (20/15), 30 Tractions.
  // ─────────────────────────────────────────────────────────────────────────
  jackie: {
    summary:
      "Enchaînement rameur, thrusters à la barre olympique vide et tractions. Mélange complet : " +
      "moteur cardio puis endurance musculaire jambes et tirage.",
    format: "Pour le temps",
    timeCapSec: 900,
    blocks: [
      { reps: "1000 m", movement: "Rameur" },
      { reps: "50", movement: "Thrusters", detail: "barre à vide" },
      { reps: "30", movement: "Tractions" },
    ],
    weights: [
      {
        movement: "Thruster",
        rxMale: 20,
        rxFemale: 15,
        scaledMale: 15,
        scaledFemale: 10,
        unit: "kg",
        note: "barre olympique à vide",
      },
    ],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 5. 2000 m Rameur (avec matériel) — pur ergo.
  // ─────────────────────────────────────────────────────────────────────────
  row_2k: {
    summary:
      "Le test de référence sur rameur Concept2 : 2000 m le plus vite possible. Mesure directe " +
      "et fiable de ton moteur cardio.",
    format: "2000 m, pour le temps",
    timeCapSec: 720,
    blocks: [{ reps: "2000 m", movement: "Rameur" }],
    weights: [],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Helen (benchmark) — 3 tours : 400 m course, 21 Swings KB 24/16, 12 Tractions.
  // ─────────────────────────────────────────────────────────────────────────
  helen: {
    summary:
      "3 tours de course, swings kettlebell et tractions. Triplet équilibré entre cardio, hanches " +
      "et tirage — un classique du conditionnement hybride.",
    format: "3 tours, pour le temps",
    timeCapSec: 1320,
    blocks: [
      { reps: "400 m", movement: "Course" },
      { reps: "21", movement: "Swings kettlebell" },
      { reps: "12", movement: "Tractions" },
    ],
    weights: [
      {
        movement: "Swing kettlebell",
        rxMale: 24,
        rxFemale: 16,
        scaledMale: 16,
        scaledFemale: 12,
        unit: "kg",
        note: "kettlebell",
      },
    ],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 7. Karen (benchmark) — 150 Wall balls, 9/6 kg, cible 3 m / 2,70 m.
  // ─────────────────────────────────────────────────────────────────────────
  karen: {
    summary:
      "150 wall balls pour le temps. Test mental et physique : un seul mouvement, jambes et épaules " +
      "qui brûlent, à tenir sans s'arrêter.",
    format: "150 répétitions, pour le temps",
    timeCapSec: 900,
    blocks: [{ reps: "150", movement: "Wall balls" }],
    weights: [
      {
        movement: "Wall ball",
        rxMale: 9,
        rxFemale: 6,
        scaledMale: 6,
        scaledFemale: 4,
        unit: "kg",
        note: "cible 3 m (H) / 2,70 m (F)",
      },
    ],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 8. Cindy (benchmark) — AMRAP 20 min : 5 Tractions, 10 Pompes, 15 Air squats.
  //    scoreType reps : nombre de tours/reps.
  // ─────────────────────────────────────────────────────────────────────────
  cindy: {
    summary:
      "AMRAP 20 minutes au poids du corps : tractions, pompes, air squats. Test d'endurance " +
      "musculaire et de moteur — combien de tours peux-tu enchaîner ?",
    format: "AMRAP 20 min",
    timeCapSec: 1200,
    blocks: [
      { reps: "5", movement: "Tractions" },
      { reps: "10", movement: "Pompes" },
      { reps: "15", movement: "Air squats" },
    ],
    weights: [],
    scoringNote:
      "Tu enregistres ton nombre total de tours (un tour = 5 tractions + 10 pompes + 15 air squats).",
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 9. Benchmark Zéro (maison, SANS matériel) — médiane H ~480 s / F ~570 s.
  //    Poids du corps uniquement. Triplet engine / endurance musculaire / hybride.
  // ─────────────────────────────────────────────────────────────────────────
  benchmark_zero: {
    summary:
      "La séance test 100 % sans matériel : burpees, pompes et air squats en dégressif, sans rien " +
      "d'autre que ton corps. Conçue pour mesurer ton hybride où que tu sois.",
    format: "21-15-9, pour le temps",
    timeCapSec: 900,
    blocks: [
      { reps: "21-15-9", movement: "Burpees" },
      { reps: "21-15-9", movement: "Pompes" },
      { reps: "42-30-18", movement: "Air squats", detail: "le double des autres mouvements" },
    ],
    weights: [],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 10. 5 km Course (sans matériel).
  // ─────────────────────────────────────────────────────────────────────────
  run_5k: {
    summary:
      "5 kilomètres en course à pied, le plus vite possible. Test d'endurance aérobie de référence, " +
      "réalisable partout.",
    format: "5 km, pour le temps",
    blocks: [{ reps: "5 km", movement: "Course" }],
    weights: [],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 11. 1 km Course (sans matériel).
  // ─────────────────────────────────────────────────────────────────────────
  run_1k: {
    summary:
      "1 kilomètre en course à pied à pleine intensité. Test de vitesse et de moteur sur effort court.",
    format: "1 km, pour le temps",
    blocks: [{ reps: "1 km", movement: "Course" }],
    weights: [],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 12. Max pompes strictes (sans matériel) — une série.
  // ─────────────────────────────────────────────────────────────────────────
  max_pushups: {
    summary:
      "Maximum de pompes strictes en une seule série, sans repos au sol. Test d'endurance musculaire " +
      "du haut du corps (proxy de force).",
    format: "Une série jusqu'à l'échec, pour le nombre",
    blocks: [{ reps: "Max", movement: "Pompes", detail: "strictes, une série non-stop" }],
    weights: [],
    scoringNote: SCORE_REPS,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 13. Max air squats en 2 min (sans matériel).
  // ─────────────────────────────────────────────────────────────────────────
  max_air_squats_2min: {
    summary:
      "Maximum d'air squats en 2 minutes. Test de puissance et d'endurance musculaire des jambes " +
      "sur effort court et intense.",
    format: "AMRAP 2 min, pour le nombre",
    timeCapSec: 120,
    blocks: [{ reps: "Max en 2 min", movement: "Air squats" }],
    weights: [],
    scoringNote: SCORE_REPS,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 14. Test burpees 7 min (sans matériel).
  // ─────────────────────────────────────────────────────────────────────────
  burpees_7min: {
    summary:
      "Maximum de burpees en 7 minutes. Test de moteur tout-corps et de mental : tenir une cadence " +
      "régulière sans exploser.",
    format: "AMRAP 7 min, pour le nombre",
    timeCapSec: 420,
    blocks: [{ reps: "Max en 7 min", movement: "Burpees" }],
    weights: [],
    scoringNote: SCORE_REPS,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 15. Machine & Mur (maison, avec matériel) — médiane H 660 s / F 780 s.
  //    Machine ergo + wall walks + toes-to-bar. Strength / endurance musc. / engine / power.
  // ─────────────────────────────────────────────────────────────────────────
  ergo_skill: {
    summary:
      "Séance gymnastique et machine : calories au rameur, montées au mur (wall walks) et relevés " +
      "de jambes à la barre. Teste ton gainage, ton tirage et ton moteur en même temps.",
    format: "3 tours, pour le temps",
    timeCapSec: 1200,
    blocks: [
      { reps: "20 cal", movement: "Rameur", detail: "ou SkiErg / Assault Bike" },
      { reps: "5", movement: "Wall walks", detail: "montées au mur" },
      { reps: "10", movement: "Relevés de jambes à la barre", detail: "toes-to-bar" },
    ],
    weights: [],
    scoringNote: SCORE_TIME,
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 16. Course distance libre (sans matériel) — le score gère la distance.
  // ─────────────────────────────────────────────────────────────────────────
  run_free_distance: {
    summary:
      "Une course sur la distance de ton choix : le score s'adapte automatiquement à la distance " +
      "parcourue. Idéal pour enregistrer une sortie libre et mesurer ton moteur.",
    format: "Distance au choix, pour le temps",
    blocks: [{ reps: "Distance libre", movement: "Course", detail: "tu renseignes la distance" }],
    weights: [],
    scoringNote:
      "Tu enregistres ta distance et ton temps total ; le score est calculé en fonction de ton allure.",
  },

  // ─────────────────────────────────────────────────────────────────────────
  // 17. Max air squats (une série, sans matériel).
  // ─────────────────────────────────────────────────────────────────────────
  max_air_squats: {
    summary:
      "Maximum d'air squats en une seule série non-stop, sans repos. Test d'endurance musculaire " +
      "des jambes et de résistance mentale.",
    format: "Une série jusqu'à l'arrêt, pour le nombre",
    blocks: [{ reps: "Max", movement: "Air squats", detail: "une série non-stop" }],
    weights: [],
    scoringNote: SCORE_REPS,
  },

  // ───────────── Épreuves « Autre » (réelles, jouables) ─────────────
  hyrox_solo: {
    summary: "L'épreuve HYROX solo : 8 km de course fractionnés, entrelacés avec 8 stations fonctionnelles, le tout enchaîné pour le temps.",
    format: "8 × 1 km + 8 stations, pour le temps",
    blocks: [
      { reps: "8 ×", movement: "1 km course", detail: "avant chaque station" },
      { reps: "1000 m", movement: "SkiErg" },
      { reps: "50 m", movement: "Poussée de traîneau" },
      { reps: "50 m", movement: "Tirage de traîneau" },
      { reps: "80 m", movement: "Burpee-sauts" },
      { reps: "1000 m", movement: "Rameur" },
      { reps: "200 m", movement: "Port de sacs (farmers)" },
      { reps: "100 m", movement: "Fentes lestées" },
      { reps: "100", movement: "Wall balls" },
    ],
    weights: [
      { movement: "Wall ball", rxMale: 9, rxFemale: 6, scaledMale: 6, scaledFemale: 4, unit: "kg" },
    ],
    scoringNote: SCORE_TIME,
  },
  isabel: {
    summary: "Benchmark CrossFit : 30 arrachés (snatch) le plus vite possible. Puissance et technique d'haltérophilie sous fatigue.",
    format: "30 répétitions, pour le temps",
    blocks: [{ reps: "30", movement: "Arrachés (snatch)" }],
    weights: [{ movement: "Snatch", rxMale: 61, rxFemale: 43, scaledMale: 43, scaledFemale: 30, unit: "kg", note: "barre" }],
    scoringNote: SCORE_TIME,
  },
  murph: {
    summary: "Hero WOD : course, puis tractions/pompes/squats (fractionnés librement), puis course — classiquement avec gilet lesté.",
    format: "Pour le temps (gilet conseillé)",
    blocks: [
      { reps: "1,6 km", movement: "Course" },
      { reps: "100", movement: "Tractions" },
      { reps: "200", movement: "Pompes" },
      { reps: "300", movement: "Air squats" },
      { reps: "1,6 km", movement: "Course" },
    ],
    weights: [{ movement: "Gilet lesté", rxMale: 9, rxFemale: 6, scaledMale: 0, scaledFemale: 0, unit: "kg", note: "0 = sans gilet" }],
    scoringNote: SCORE_TIME,
  },
  track_10000m: {
    summary: "10 000 mètres sur piste : 25 tours, l'épreuve reine du fond.",
    format: "10 000 m, pour le temps",
    blocks: [{ reps: "10 000 m", movement: "Course (piste)" }],
    weights: [],
    scoringNote: SCORE_TIME,
  },
  half_marathon: {
    summary: "Le semi-marathon : 21,1 km sur route, l'équilibre vitesse/endurance.",
    format: "21,0975 km, pour le temps",
    blocks: [{ reps: "21,1 km", movement: "Course (route)" }],
    weights: [],
    scoringNote: SCORE_TIME,
  },
  marathon: {
    summary: "Le marathon : 42,195 km sur route, l'épreuve mythique de l'endurance.",
    format: "42,195 km, pour le temps",
    blocks: [{ reps: "42,195 km", movement: "Course (route)" }],
    weights: [],
    scoringNote: SCORE_TIME,
  },
};
