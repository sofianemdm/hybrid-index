/* eslint-disable no-console */
import { PrismaClient, type AttributeKey, type Sex, type ScoreType, type WodType } from "@prisma/client";
import Redis from "ioredis";
import { rankFromIndex } from "@hybrid-index/contracts";
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
  { id: "run_free_distance", name: "Course distance libre", scoreType: "time", requiresEquipment: false, targetAttributes: ["engine", "speed"] },
  { id: "max_air_squats", name: "Max air squats (une série)", scoreType: "reps", requiresEquipment: false, targetAttributes: ["muscular_endurance", "strength"] },
];

const ATTRS: AttributeKey[] = ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"];
const GOALS = ["hyrox", "crossfit_strength", "all_round"] as const;
// Noms RÉALISTES (40 par sexe + 48 noms de famille) → pseudos crédibles, pas générés par template.
const FIRST_M = ["Lucas", "Hugo", "Nathan", "Théo", "Maxime", "Antoine", "Raphaël", "Yanis", "Marco", "Diego", "Adam", "Noah", "Léo", "Tom", "Enzo", "Mehdi", "Sacha", "Ivan", "Karl", "Bruno", "Julien", "Thomas", "Alexandre", "Mathis", "Gabriel", "Romain", "Quentin", "Florian", "Kevin", "Samuel", "Victor", "Paul", "Louis", "Aurélien", "Damien", "Nicolas", "Pierre", "Clément", "Bastien", "Jordan"];
const FIRST_F = ["Léa", "Manon", "Camille", "Sarah", "Chloé", "Inès", "Jade", "Lina", "Maya", "Nora", "Eva", "Zoé", "Anaïs", "Lou", "Romane", "Yasmine", "Alice", "Nina", "Clara", "Iris", "Emma", "Julie", "Marine", "Pauline", "Laura", "Élise", "Margaux", "Justine", "Audrey", "Charlotte", "Mathilde", "Océane", "Lucie", "Amandine", "Sophie", "Mélanie", "Fanny", "Céline", "Morgane", "Aurore"];
const LAST = ["Martin", "Bernard", "Dubois", "Thomas", "Robert", "Petit", "Durand", "Leroy", "Moreau", "Simon", "Laurent", "Lefebvre", "Michel", "Garcia", "David", "Bertrand", "Roux", "Vincent", "Fournier", "Morel", "Girard", "André", "Mercier", "Blanc", "Guérin", "Boyer", "Rousseau", "Henry", "Roussel", "Nicolas", "Perrin", "Morin", "Mathieu", "Gauthier", "Dumont", "Lopez", "Fontaine", "Chevalier", "Robin", "Masson", "Sanchez", "Gérard", "Nguyen", "Faure", "Brun", "Caron", "Lambert", "Renaud"];

function stripAccents(s: string): string {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

/** Nom d'affichage crédible et unique (mix « Prénom Nom », « prenom.nom », « prenomnom »). */
function displayNameFor(i: number, sex: Sex): string {
  const firsts = sex === "male" ? FIRST_M : FIRST_F;
  const first = firsts[i % firsts.length];
  const last = LAST[(i * 13 + (sex === "male" ? 0 : 7)) % LAST.length];
  switch (i % 4) {
    case 1:
      return `${stripAccents(first).toLowerCase()}.${stripAccents(last).toLowerCase()}`;
    case 3:
      return `${stripAccents(first).toLowerCase()}${stripAccents(last).toLowerCase()}`;
    default:
      return `${first} ${last}`;
  }
}

/** Repères de perf de seed par séance : [élite, débutant] par sexe. time=true → plus bas = meilleur. */
const SEED_PERF: Record<string, { time: boolean; m: [number, number]; f: [number, number] }> = {
  pft_hyrox: { time: true, m: [3900, 6000], f: [4500, 6600] },
  fran: { time: true, m: [120, 420], f: [150, 480] },
  grace: { time: true, m: [80, 300], f: [110, 360] },
  jackie: { time: true, m: [360, 720], f: [420, 840] },
  row_2k: { time: true, m: [380, 560], f: [440, 640] },
  helen: { time: true, m: [480, 900], f: [540, 1020] },
  karen: { time: true, m: [360, 900], f: [420, 1020] },
  cindy: { time: false, m: [32, 8], f: [25, 6] },
  benchmark_zero: { time: true, m: [480, 1080], f: [540, 1200] },
  run_5k: { time: true, m: [1080, 1800], f: [1200, 2040] },
  run_1k: { time: true, m: [180, 330], f: [210, 390] },
  max_pushups: { time: false, m: [75, 20], f: [50, 12] },
  max_air_squats_2min: { time: false, m: [110, 50], f: [100, 45] },
  burpees_7min: { time: false, m: [140, 70], f: [120, 60] },
  max_situps_2min: { time: false, m: [90, 40], f: [85, 38] },
  max_air_squats: { time: false, m: [100, 40], f: [95, 38] },
};

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
  const sexes: Sex[] = ["male", "female"];
  let created = 0;
  for (const sex of sexes) {
    for (let i = 0; i < 40; i++) {
      const email = `seed_${sex}_${i}@hybrid.local`;
      const displayName = displayNameFor(i, sex);
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

      // Séances historiques figées : peuplent les classements par séance ; performedAt dans le passé
      // (14-200 j) → exclues du classement de progression hebdo. Sous-ensemble aléatoire, perfs
      // corrélées à l'Index de l'athlète, rendu réaliste pour chaque séance.
      const seedableWodIds = Object.keys(SEED_PERF);
      const picked = new Set<string>();
      const nbSessions = rand(4, 9);
      while (picked.size < nbSessions) {
        picked.add(seedableWodIds[rand(0, seedableWodIds.length - 1)]);
      }
      const wodResults = [...picked].map((wodId) => {
        const perf = SEED_PERF[wodId];
        const meta = WODS.find((w) => w.id === wodId)!;
        const sub = Math.min(999, Math.max(50, value + rand(-110, 110)));
        const frac = sub / 1000;
        const [elite, beg] = sex === "male" ? perf.m : perf.f;
        const raw = Math.max(1, Math.round(beg + (elite - beg) * frac + rand(-3, 3)));
        return {
          userId: user.id,
          wodId,
          sex,
          rawResult: raw,
          subScore: sub,
          percentile: Math.min(0.9999, Math.max(0.0001, frac)),
          attributesAffected: meta.targetAttributes as AttributeKey[],
          rxCompliant: true,
          scoringVersionId: SCORING_VERSION_UUID,
          idempotencyKey: `seed_${wodId}`,
          performedAt: new Date(Date.now() - rand(14, 200) * 86400000),
        };
      });
      await prisma.wodResult.createMany({ data: wodResults, skipDuplicates: true });

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
