/* eslint-disable no-console */
import { PrismaClient, type AttributeKey, type Sex, type ScoreType, type WodType } from "@prisma/client";
import Redis from "ioredis";
import { rankFromIndex } from "@hybrid-index/contracts";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { BADGES } from "../src/modules/engagement/badges.data";

const SCORING_VERSION_UUID = "11111111-1111-1111-1111-111111111111";
const prisma = new PrismaClient();

/** Les 15 WODs de référence (ids alignés sur le score-service) — FK pour wod_result. */
const WODS: Array<{
  id: string;
  name: string;
  scoreType: ScoreType;
  requiresEquipment: boolean;
  targetAttributes: AttributeKey[];
  isBenchmark?: boolean; // défaut true ; false = WOD « Ligue » CACHÉ du catalogue (mais compte pour l'Index)
}> = [
  { id: "hyrox_sprint", name: "Sprint HYROX", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine", "power", "hybrid", "muscular_endurance"] },
  { id: "fran", name: "Fran", scoreType: "time", requiresEquipment: true, targetAttributes: ["muscular_endurance", "power"] },
  { id: "grace", name: "Grace", scoreType: "time", requiresEquipment: true, targetAttributes: ["power", "strength"] },
  { id: "jackie", name: "Jackie", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine", "muscular_endurance", "power", "strength"] },
  { id: "row_2k", name: "2000 m Rameur", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine"] },
  { id: "helen", name: "Helen", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine", "muscular_endurance", "hybrid"] },
  { id: "karen", name: "Karen", scoreType: "time", requiresEquipment: true, targetAttributes: ["power", "muscular_endurance"] },
  { id: "cindy", name: "Cindy", scoreType: "reps", requiresEquipment: true, targetAttributes: ["muscular_endurance", "engine"] },
  { id: "benchmark_zero", name: "Benchmark Zéro", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine", "muscular_endurance", "hybrid"] },
  { id: "profil_express", name: "Profil Express", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"] },
  { id: "run_5k", name: "5 km Course", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine"] },
  { id: "run_3k", name: "3 km Course", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine"] },
  { id: "run_1k", name: "1 km Course", scoreType: "time", requiresEquipment: false, targetAttributes: ["speed", "engine"] },
  { id: "max_pushups", name: "Max pompes strictes", scoreType: "reps", requiresEquipment: false, targetAttributes: ["strength", "muscular_endurance"] },
  { id: "max_air_squats_2min", name: "Max air squats en 2 min", scoreType: "reps", requiresEquipment: false, targetAttributes: ["muscular_endurance", "power"] },
  { id: "burpees_7min", name: "Test burpees 7 min", scoreType: "reps", requiresEquipment: false, targetAttributes: ["engine", "muscular_endurance", "power", "hybrid"] },
  { id: "ergo_skill", name: "Machine & Mur", scoreType: "time", requiresEquipment: true, targetAttributes: ["strength", "muscular_endurance", "engine", "power"] },
  { id: "run_free_distance", name: "Course distance libre", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine", "speed"] },
  { id: "max_air_squats", name: "Max air squats (une série)", scoreType: "reps", requiresEquipment: false, targetAttributes: ["muscular_endurance", "strength"] },
  { id: "max_strict_pullups", name: "Max tractions strictes (une série)", scoreType: "reps", requiresEquipment: true, targetAttributes: ["strength", "muscular_endurance"] },
  { id: "squat_1rm", name: "Squat 1RM (charge max, 1 rép)", scoreType: "load", requiresEquipment: true, targetAttributes: ["strength", "power"] },
  // Épreuves « Autre » (réelles, jouables, rangées à part de l'écran Séances).
  { id: "hyrox_solo", name: "HYROX (solo)", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine", "power", "hybrid", "muscular_endurance"] },
  { id: "isabel", name: "Isabel", scoreType: "time", requiresEquipment: true, targetAttributes: ["power", "strength"] },
  { id: "murph", name: "Murph", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine", "muscular_endurance", "hybrid"] },
  { id: "track_10000m", name: "10 000 m (piste)", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine"] },
  { id: "half_marathon", name: "Semi-marathon", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine"] },
  { id: "marathon", name: "Marathon", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine"] },
  // WODs « Ligue du mois » (sans matériel, 1 qualité/semaine) — isBenchmark:false = cachés du
  // catalogue (HIDDEN_WOD_IDS), mais leurs perfs comptent pour l'Index comme tout WOD.
  { id: "league_sprint_ladder", name: "La Flèche", scoreType: "time", requiresEquipment: false, targetAttributes: ["speed", "engine"], isBenchmark: false },
  { id: "league_engine_12", name: "Le Moteur", scoreType: "reps", requiresEquipment: false, targetAttributes: ["engine", "muscular_endurance", "hybrid"], isBenchmark: false },
  { id: "league_grind_squats", name: "Le Pilier", scoreType: "reps", requiresEquipment: false, targetAttributes: ["muscular_endurance", "strength"], isBenchmark: false },
  { id: "league_power_amrap", name: "La Détente", scoreType: "reps", requiresEquipment: false, targetAttributes: ["power", "muscular_endurance"], isBenchmark: false },
  { id: "league_hybrid_chipper", name: "Le Chaos", scoreType: "time", requiresEquipment: false, targetAttributes: ["hybrid", "engine", "muscular_endurance"], isBenchmark: false },
];

const ATTRS: AttributeKey[] = ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"];
// GOALS conservé : sert UNIQUEMENT à typer la discipline des « Références Pro » (élites, hors
// classement). Les faux comptes de remplissage du classement ont été retirés (app 100 % réelle).
const GOALS = ["hyrox", "crossfit_strength", "all_round"] as const;

/** Repères de perf de seed par séance : [élite, débutant] par sexe. time=true → plus bas = meilleur. */
const SEED_PERF: Record<string, { time: boolean; m: [number, number]; f: [number, number] }> = {
  hyrox_sprint: { time: true, m: [660, 1200], f: [720, 1380] },
  fran: { time: true, m: [120, 420], f: [150, 480] },
  grace: { time: true, m: [80, 300], f: [110, 360] },
  jackie: { time: true, m: [360, 720], f: [420, 840] },
  row_2k: { time: true, m: [380, 560], f: [440, 640] },
  helen: { time: true, m: [480, 900], f: [540, 1020] },
  karen: { time: true, m: [360, 900], f: [420, 1020] },
  cindy: { time: false, m: [32, 8], f: [25, 6] },
  benchmark_zero: { time: true, m: [480, 1080], f: [540, 1200] },
  profil_express: { time: true, m: [230, 500], f: [260, 620] },
  run_5k: { time: true, m: [1080, 1800], f: [1200, 2040] },
  run_3k: { time: true, m: [660, 1140], f: [750, 1320] },
  run_1k: { time: true, m: [180, 330], f: [210, 390] },
  max_pushups: { time: false, m: [75, 20], f: [50, 12] },
  max_air_squats_2min: { time: false, m: [110, 50], f: [100, 45] },
  burpees_7min: { time: false, m: [140, 70], f: [120, 60] },
  ergo_skill: { time: true, m: [420, 1020], f: [480, 1140] },
  max_air_squats: { time: false, m: [100, 40], f: [95, 38] },
};

/**
 * Athlètes d'ÉLITE — personas FICTIFS (noms publics inventés). Les performances s'inspirent
 * de repères PUBLICS réels ; le nom réel d'inspiration reste UNIQUEMENT en commentaire interne
 * (jamais affiché). Aucun compte n'usurpe l'identité d'une personne réelle. cf. mémoire projet.
 */
type EliteDiscipline = { goal: (typeof GOALS)[number]; wods: string[]; males: string[]; females: string[]; captions: string[] };
const ELITE_DISCIPLINES: EliteDiscipline[] = [
  {
    // insp. : Hunter McIntyre, Lauren Weeks, Alexander Roncevic, Megan Jacoby… (HYROX)
    goal: "hyrox",
    wods: ["hyrox_sprint", "row_2k", "run_5k", "karen"],
    males: ["Marcus Vance", "Kayden Roth", "Dorian Sael", "Bjorn Halvik", "Tomas Reier"],
    females: ["Lena Brandt", "Sofia Marchetti", "Nora Eklund", "Aisha Vermeer", "Cara Donnelly"],
    captions: ["Sprint HYROX bouclé, jambes en feu 🔥", "Negative split sur le rameur 🚣", "On lâche rien jusqu'au mur 💪", "Semaine d'attaque terminée."],
  },
  {
    // insp. : Mat Fraser, Tia-Clair Toomey, Rich Froning, Laura Horvath… (CrossFit)
    goal: "crossfit_strength",
    wods: ["fran", "grace", "jackie", "helen", "cindy"],
    males: ["Cole Ferran", "Dane Kovac", "Rhys Calder", "Mateo Silva", "Owen Brandt"],
    females: ["Tess Halloran", "Mira Sorstad", "Iris Lambert", "Paige Novak", "Yara Haddad"],
    captions: ["Fran sous la barre des 2:30 💀", "Grace en mode métronome.", "PR sur Jackie aujourd'hui 🙌", "Le pain-cave habituel 😅"],
  },
  {
    // insp. : Jakob Ingebrigtsen, Sifan Hassan, Joshua Cheptegei… (course)
    goal: "all_round",
    wods: ["run_5k", "run_1k", "row_2k"],
    males: ["Elias Karlsen", "Samuel Mwangi", "Samir Oualid", "Finn Carrick", "Noe Dubois"],
    females: ["Hana Bekele", "Lucia Romero", "Mei Tanaka", "Astrid Vik", "Zoe Lefevre"],
    captions: ["Sortie tempo parfaite ce matin 🏃", "Fractionné qui pique 🔥", "Objectif chrono validé.", "Les jambes tournent bien cette semaine."],
  },
];

function rand(min: number, max: number): number {
  return Math.floor(min + Math.random() * (max - min + 1));
}

async function main(): Promise<void> {
  console.log("Seed: version de scoring + WODs…");
  await prisma.scoringVersion.upsert({
    where: { id: SCORING_VERSION_UUID },
    create: {
      id: SCORING_VERSION_UUID,
      semver: "1.0.0",
      status: "active",
      fParams: { curve: "sigmoid-v1" },
      attributeWeights: {},
      activatedAt: new Date(),
    },
    update: { status: "active" },
  });

  for (const w of WODS) {
    const type: WodType = w.scoreType === "time" ? "for_time" : "amrap";
    await prisma.wod.upsert({
      where: { id: w.id },
      create: {
        id: w.id,
        name: w.name,
        isBenchmark: w.isBenchmark ?? true,
        type,
        requiresEquipment: w.requiresEquipment,
        targetAttributes: w.targetAttributes,
        scoreType: w.scoreType,
        movements: {},
      },
      update: {
        name: w.name,
        isBenchmark: w.isBenchmark ?? true,
        scoreType: w.scoreType,
        requiresEquipment: w.requiresEquipment,
        targetAttributes: w.targetAttributes as AttributeKey[],
      },
    });
  }
  // Purge des séances officielles obsolètes (ex. ids renommés) — préserve les séances custom.
  const validWodIds = WODS.map((w) => w.id);
  await prisma.wodResult.deleteMany({ where: { wod: { isCustom: false }, wodId: { notIn: validWodIds } } });
  await prisma.wod.deleteMany({ where: { isCustom: false, id: { notIn: validWodIds } } });

  console.log("Seed: badges…");
  for (const b of BADGES) {
    await prisma.badge.upsert({
      where: { id: b.id },
      create: { id: b.id, category: b.category, condition: b.condition, rarity: b.rarity, cosmeticUnlock: b.cosmeticUnlock },
      update: { category: b.category, condition: b.condition, rarity: b.rarity, cosmeticUnlock: b.cosmeticUnlock },
    });
  }

  const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379", { maxRetriesPerRequest: 1 });
  let redisOk = true;
  redis.on("error", () => {
    redisOk = false;
  });

  console.log("Seed: athlètes fictifs (classement)…");
  // On repart de zéro pour les comptes de seed (idempotent + applique les nouveaux noms/perfs).
  // Cascade : profil, index, attributs, résultats. N'affecte JAMAIS les vrais comptes.
  const oldSeed = await prisma.user.findMany({ where: { email: { startsWith: "seed_" } }, select: { id: true } });
  for (const u of oldSeed) {
    await redis.zrem("leaderboard:male", u.id).catch(() => undefined);
    await redis.zrem("leaderboard:female", u.id).catch(() => undefined);
  }
  await prisma.user.deleteMany({ where: { email: { startsWith: "seed_" } } });
  let created = 0;

  // Faux athlètes « battables » du classement RETIRÉS (app 100% réelle, décision 25/06).
  // Seules les « Références Pro » ci-dessous subsistent, et UNIQUEMENT dans le feed (hors classement).

  // --- Athlètes d'élite (personas fictifs, perfs réalistes, posts publics qui animent le feed) ---
  // App 100 % réelle : AUCUN utilisateur seedé (ni faux comptes « battables » ni « Références Pro »).
  // Décision utilisateur (26/06). Repasser SEED_DEMO_USERS à true pour réactiver des personas de démo.
  const SEED_DEMO_USERS = false;
  console.log(SEED_DEMO_USERS ? "Seed: personas d'élite…" : "Seed: aucun utilisateur seedé (app 100% réelle).");
  let eliteIdx = 0;
  for (const disc of (SEED_DEMO_USERS ? ELITE_DISCIPLINES : [])) {
    const roster: Array<{ name: string; sex: Sex }> = [
      ...disc.males.map((name) => ({ name, sex: "male" as Sex })),
      ...disc.females.map((name) => ({ name, sex: "female" as Sex })),
    ];
    for (const a of roster) {
      const value = Math.max(910, 985 - eliteIdx * 2 - rand(0, 6)); // élite, légère variation
      const rank = rankFromIndex(Math.round(ratingFromInternal(value)));
      const email = `seed_elite_${eliteIdx}@hybrid.local`;
      const user = await prisma.user.upsert({
        where: { email },
        create: {
          email,
          dateOfBirth: new Date(`${rand(1990, 2002)}-0${rand(1, 9)}-1${rand(0, 8)}`),
          ageVerified: true,
          consents: { seed: true },
          profile: { create: { displayName: a.name, sex: a.sex, goal: disc.goal, equipmentPref: "both", rank } },
        },
        update: { profile: { update: { rank } } },
      });
      // Pas de HybridIndex pour les pros : ils animent le feed (posts publics) mais
      // N'APPARAISSENT PAS au classement (décision : pas de pros dans la ligue).
      for (const attribute of ATTRS) {
        const score = Math.min(1000, Math.max(700, value + rand(-40, 25)));
        await prisma.attributeScore.upsert({
          where: { userId_attribute: { userId: user.id, attribute } },
          create: {
            userId: user.id,
            attribute,
            score,
            percentile: Math.min(0.9999, score / 1000),
            unlocked: true,
            isEstimated: false,
            isStale: false,
            scoringVersionId: SCORING_VERSION_UUID,
          },
          update: { score, scoringVersionId: SCORING_VERSION_UUID },
        });
      }
      // Résultats au niveau élite sur les WODs de la discipline ; le 1er daté cette semaine.
      let signatureResultId: string | null = null;
      let di = 0;
      for (const wodId of disc.wods) {
        const perf = SEED_PERF[wodId];
        const meta = WODS.find((w) => w.id === wodId);
        if (!perf || !meta) {
          di++;
          continue;
        }
        const [elite] = a.sex === "male" ? perf.m : perf.f;
        const raw = perf.time ? Math.max(1, elite + rand(-8, 15)) : Math.max(1, elite + rand(-3, 4));
        const sub = Math.min(995, Math.max(900, value + rand(-20, 25)));
        const daysAgo = di === 0 ? rand(0, 5) : rand(7, 120);
        const res = await prisma.wodResult.create({
          data: {
            userId: user.id,
            wodId,
            sex: a.sex,
            rawResult: raw,
            subScore: sub,
            percentile: Math.min(0.9999, sub / 1000),
            attributesAffected: meta.targetAttributes as AttributeKey[],
            rxCompliant: true,
            scoringVersionId: SCORING_VERSION_UUID,
            idempotencyKey: `seed_elite_${wodId}`,
            performedAt: new Date(Date.now() - daysAgo * 86400000),
          },
        });
        if (di === 0) signatureResultId = res.id;
        di++;
      }
      // Posts publics : partage de la perf signature + un message court.
      if (signatureResultId) {
        await prisma.post.create({
          data: { authorId: user.id, kind: "perf_share", wodResultId: signatureResultId, body: disc.captions[eliteIdx % disc.captions.length] },
        });
      }
      await prisma.post.create({
        data: { authorId: user.id, kind: "text", body: disc.captions[(eliteIdx + 1) % disc.captions.length] },
      });
      // (pas de zadd Redis : les pros sont hors classement)
      created++;
      eliteIdx++;
    }
  }

  console.log(`Seed terminé : ${created} athlètes. Redis ${redisOk ? "peuplé" : "indisponible (fallback Postgres)"}.`);
  // Backfill display (v2) : recale le rang stocké de TOUS les profils sur l'OVR /100
  // (corrige les rangs écrits sous l'ancienne échelle /1000, vrais comptes inclus).
  console.log("Seed: backfill des rangs sur l'échelle /100…");
  const allIndexes = await prisma.hybridIndex.findMany({ select: { userId: true, value: true } });
  let fixed = 0;
  for (const hi of allIndexes) {
    const rank = rankFromIndex(Math.round(ratingFromInternal(hi.value)));
    const res = await prisma.profile.updateMany({ where: { userId: hi.userId, rank: { not: rank } }, data: { rank } });
    fixed += res.count;
  }
  console.log(`Backfill rangs : ${fixed} profil(s) recalé(s).`);

  redis.disconnect();
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
