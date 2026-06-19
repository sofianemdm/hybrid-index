/* eslint-disable no-console */
import { PrismaClient, type AttributeKey, type Sex, type ScoreType, type WodType } from "@prisma/client";
import Redis from "ioredis";
import { rankFromIndex } from "@hybrid-index/contracts";

const SCORING_VERSION_UUID = "11111111-1111-1111-1111-111111111111";
const prisma = new PrismaClient();

/** Les 15 WODs de référence (ids alignés sur le score-service) — FK pour wod_result. */
const WODS: Array<{
  id: string;
  name: string;
  scoreType: ScoreType;
  requiresEquipment: boolean;
  targetAttributes: AttributeKey[];
}> = [
  { id: "pft_hyrox", name: "PFT HYROX", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine", "muscular_endurance", "power", "hybrid"] },
  { id: "fran", name: "Fran", scoreType: "time", requiresEquipment: true, targetAttributes: ["muscular_endurance", "power"] },
  { id: "grace", name: "Grace", scoreType: "time", requiresEquipment: true, targetAttributes: ["power", "strength"] },
  { id: "jackie", name: "Jackie", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine", "muscular_endurance", "power", "strength"] },
  { id: "row_2k", name: "2000 m Rameur", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine"] },
  { id: "helen", name: "Helen", scoreType: "time", requiresEquipment: true, targetAttributes: ["engine", "muscular_endurance", "hybrid"] },
  { id: "karen", name: "Karen", scoreType: "time", requiresEquipment: true, targetAttributes: ["power", "muscular_endurance"] },
  { id: "cindy", name: "Cindy", scoreType: "reps", requiresEquipment: true, targetAttributes: ["muscular_endurance", "engine"] },
  { id: "benchmark_zero", name: "Benchmark Zéro", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine", "muscular_endurance", "hybrid"] },
  { id: "run_5k", name: "5 km Course", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine"] },
  { id: "run_1k", name: "1 km Course", scoreType: "time", requiresEquipment: false, targetAttributes: ["speed", "engine"] },
  { id: "max_pushups", name: "Max pompes strictes", scoreType: "reps", requiresEquipment: false, targetAttributes: ["strength", "muscular_endurance"] },
  { id: "max_air_squats_2min", name: "Max air squats en 2 min", scoreType: "reps", requiresEquipment: false, targetAttributes: ["muscular_endurance", "power"] },
  { id: "burpees_7min", name: "Test burpees 7 min", scoreType: "reps", requiresEquipment: false, targetAttributes: ["engine", "muscular_endurance", "power", "hybrid"] },
  { id: "max_situps_2min", name: "Max sit-ups en 2 min", scoreType: "reps", requiresEquipment: false, targetAttributes: ["muscular_endurance"] },
];

const ATTRS: AttributeKey[] = ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"];
const GOALS = ["hyrox", "crossfit_strength", "all_round"] as const;
const FIRST_M = ["Lucas", "Hugo", "Nathan", "Théo", "Maxime", "Antoine", "Raph", "Yanis", "Marco", "Diego", "Adam", "Noah", "Léo", "Tom", "Enzo", "Mehdi", "Sacha", "Ivan", "Karl", "Bruno"];
const FIRST_F = ["Léa", "Manon", "Camille", "Sarah", "Chloé", "Inès", "Jade", "Lina", "Maya", "Nora", "Eva", "Zoé", "Anaïs", "Lou", "Romane", "Yasmine", "Alice", "Nina", "Clara", "Iris"];
const SUFFIX = ["Fit", "WOD", "Hyrox", "Beast", "Iron", "Hybrid", "Athl", "Pro", "X", "Run"];

function rand(min: number, max: number): number {
  return Math.floor(min + Math.random() * (max - min + 1));
}

/** Distribution réaliste d'Index (la plupart 300-650, quelques élites). */
function sampleIndex(): number {
  const r = Math.random();
  if (r < 0.05) return rand(720, 880); // élites
  if (r < 0.25) return rand(560, 720); // forts
  if (r < 0.75) return rand(360, 560); // milieu
  return rand(180, 360); // débutants
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
        isBenchmark: true,
        type,
        requiresEquipment: w.requiresEquipment,
        targetAttributes: w.targetAttributes,
        scoreType: w.scoreType,
        movements: {},
      },
      update: { name: w.name },
    });
  }

  const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379", { maxRetriesPerRequest: 1 });
  let redisOk = true;
  redis.on("error", () => {
    redisOk = false;
  });

  console.log("Seed: athlètes fictifs (classement)…");
  const sexes: Sex[] = ["male", "female"];
  let created = 0;
  for (const sex of sexes) {
    const firsts = sex === "male" ? FIRST_M : FIRST_F;
    for (let i = 0; i < 40; i++) {
      const email = `seed_${sex}_${i}@hybrid.local`;
      const displayName = `${firsts[i % firsts.length]}_${SUFFIX[i % SUFFIX.length]}${i}`;
      const goal = GOALS[i % GOALS.length];
      const value = sampleIndex();
      const percentile = Math.min(0.9999, Math.max(0.0001, value / 1000));
      const rank = rankFromIndex(value);

      const user = await prisma.user.upsert({
        where: { email },
        create: {
          email,
          dateOfBirth: new Date(`${rand(1985, 2007)}-0${rand(1, 9)}-1${rand(0, 8)}`),
          ageVerified: true,
          consents: { seed: true },
          profile: { create: { displayName, sex, goal, equipmentPref: "both", rank } },
        },
        update: { profile: { update: { rank } } },
      });

      await prisma.hybridIndex.upsert({
        where: { userId: user.id },
        create: {
          userId: user.id,
          value,
          percentile,
          isProvisional: false,
          isEstimated: false,
          radarCoverage: rand(3, 6),
          confidenceLevel: "medium",
          scoringVersionId: SCORING_VERSION_UUID,
        },
        update: { value, percentile, scoringVersionId: SCORING_VERSION_UUID },
      });

      for (const attribute of ATTRS) {
        const score = Math.min(1000, Math.max(0, value + rand(-120, 120)));
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

      if (redisOk) {
        await redis.zadd(`leaderboard:${sex}`, value, user.id).catch(() => {
          redisOk = false;
        });
      }
      created++;
    }
  }

  console.log(`Seed terminé : ${created} athlètes. Redis ${redisOk ? "peuplé" : "indisponible (fallback Postgres)"}.`);
  redis.disconnect();
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
