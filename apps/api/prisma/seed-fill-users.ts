/* eslint-disable no-console */
//
// Seed « fill users » — 6 profils crédibles et BATTABLES DANS LE CLASSEMENT (3 H / 3 F),
// Index affiché entre 55 et 72 /100, chacun avec 3 à 12 séances.
//
// Différence avec les « Références Pro » du seed principal : ceux-là sont HORS classement (pas
// de HybridIndex, feed only). Ici on veut l'inverse → on crée un HybridIndex + une entrée Redis,
// donc ces profils APPARAISSENT au classement (leur raison d'être).
//
// Conformité :
//   - Noms génériques INVENTÉS (aucune usurpation d'athlète réel) — cf. `no-fake-athlete-accounts`.
//   - Emails `seed_fill_N@hybrid.local` → captés par `purge-fake-users.ts` (endsWith @hybrid.local)
//     et par l'idempotence ci-dessous (startsWith seed_fill_). 100 % réversible.
//   - Réintroduit volontairement des comptes de remplissage (inverse la décision « app 100% réelle »
//     du 26/06) — demande EXPLICITE de l'humain.
//
// Usage (prod) :
//   DATABASE_URL="<prod>" REDIS_URL="<prod>" NODE_OPTIONS=--use-system-ca \
//     npx ts-node apps/api/prisma/seed-fill-users.ts
//   (local : sans DATABASE_URL/REDIS_URL, prend le .env du package).
//
import { PrismaClient, type AttributeKey, type Goal, type Sex } from "@prisma/client";
import Redis from "ioredis";
import { rankFromIndex } from "@hybrid-index/contracts";
import { ratingFromInternal, percentileFromInternal } from "@hybrid-index/scoring-core";

const SCORING_VERSION_UUID = "11111111-1111-1111-1111-111111111111";
const prisma = new PrismaClient();

const ATTRS: AttributeKey[] = ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"];

/** Repères de perf [élite, débutant] par sexe (copiés de seed.ts). time=true → plus bas = meilleur. */
const SEED_PERF: Record<
  string,
  { time: boolean; attrs: AttributeKey[]; m: [number, number]; f: [number, number] }
> = {
  hyrox_sprint: { time: true, attrs: ["engine", "power", "hybrid", "muscular_endurance"], m: [660, 1200], f: [720, 1380] },
  fran: { time: true, attrs: ["muscular_endurance", "power"], m: [120, 420], f: [150, 480] },
  grace: { time: true, attrs: ["power", "strength"], m: [80, 300], f: [110, 360] },
  jackie: { time: true, attrs: ["engine", "muscular_endurance", "power", "strength"], m: [360, 720], f: [420, 840] },
  row_2k: { time: true, attrs: ["engine"], m: [380, 560], f: [440, 640] },
  helen: { time: true, attrs: ["engine", "muscular_endurance", "hybrid"], m: [480, 900], f: [540, 1020] },
  karen: { time: true, attrs: ["power", "muscular_endurance"], m: [360, 900], f: [420, 1020] },
  cindy: { time: false, attrs: ["muscular_endurance", "engine"], m: [32, 8], f: [25, 6] },
  benchmark_zero: { time: true, attrs: ["engine", "muscular_endurance", "hybrid"], m: [480, 1080], f: [540, 1200] },
  profil_express: { time: true, attrs: ["engine", "speed", "strength", "power", "muscular_endurance", "hybrid"], m: [230, 500], f: [260, 620] },
  run_5k: { time: true, attrs: ["engine"], m: [1080, 1800], f: [1200, 2040] },
  run_3k: { time: true, attrs: ["engine"], m: [660, 1140], f: [750, 1320] },
  run_1k: { time: true, attrs: ["speed", "engine"], m: [180, 330], f: [210, 390] },
  run_400: { time: true, attrs: ["speed", "engine"], m: [68, 130], f: [76, 154] },
  max_pushups: { time: false, attrs: ["strength", "muscular_endurance"], m: [75, 20], f: [50, 12] },
  max_air_squats_2min: { time: false, attrs: ["muscular_endurance", "power"], m: [110, 50], f: [100, 45] },
  burpees_7min: { time: false, attrs: ["engine", "muscular_endurance", "power", "hybrid"], m: [140, 70], f: [120, 60] },
  ergo_skill: { time: true, attrs: ["strength", "muscular_endurance", "engine", "power"], m: [420, 1020], f: [480, 1140] },
  max_air_squats: { time: false, attrs: ["muscular_endurance", "strength"], m: [100, 40], f: [95, 38] },
};
const WOD_KEYS = Object.keys(SEED_PERF);

/** Les 6 personas (pseudos crédibles validés par l'humain le 07/07). target = Index /100 visé. */
const FILL_USERS: Array<{ name: string; sex: Sex; goal: Goal; target: number }> = [
  { name: "maxlift92", sex: "male", goal: "crossfit_strength", target: 56 },
  { name: "lea_move", sex: "female", goal: "all_round", target: 60 },
  { name: "Tom_frx", sex: "male", goal: "hyrox", target: 63 },
  { name: "camille.wod", sex: "female", goal: "crossfit_strength", target: 66 },
  { name: "kevin.hyrox", sex: "male", goal: "hyrox", target: 69 },
  { name: "manon_fit31", sex: "female", goal: "all_round", target: 71 },
];

function rand(min: number, max: number): number {
  return Math.floor(min + Math.random() * (max - min + 1));
}
function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}

/** Valeur interne /1000 telle que round(ratingFromInternal(value)) == target (dichotomie). */
function internalForDisplay(target: number): number {
  let lo = 200;
  let hi = 900;
  for (let i = 0; i < 40; i++) {
    const mid = (lo + hi) / 2;
    if (ratingFromInternal(mid) < target) lo = mid;
    else hi = mid;
  }
  return Math.round((lo + hi) / 2);
}

/** Mélange (Fisher-Yates) une copie du tableau. */
function shuffled<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = rand(0, i);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

async function main(): Promise<void> {
  const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379", { maxRetriesPerRequest: 1 });
  let redisOk = true;
  redis.on("error", () => {
    redisOk = false;
  });

  // --- Idempotence : on repart de zéro pour les fill users (cascade profil/index/attributs/résultats). ---
  const old = await prisma.user.findMany({
    where: { email: { startsWith: "seed_fill_" } },
    select: { id: true, profile: { select: { sex: true } } },
  });
  for (const u of old) {
    if (u.profile) await redis.zrem(`leaderboard:${u.profile.sex}`, u.id).catch(() => undefined);
  }
  await prisma.user.deleteMany({ where: { email: { startsWith: "seed_fill_" } } });
  console.log(`Nettoyage : ${old.length} ancien(s) fill user(s) supprimé(s).`);

  let created = 0;
  for (let i = 0; i < FILL_USERS.length; i++) {
    const p = FILL_USERS[i];
    const value = internalForDisplay(p.target);
    const display = ratingFromInternal(value);
    const rank = rankFromIndex(Math.round(display));
    const t = clamp((p.target - 55) / (72 - 55), 0, 1); // 0 = plancher, 1 = haut de la plage

    // Radar : 6 attributs autour de l'Index, avec un peu de relief.
    const attributeScores = ATTRS.map((attribute) => {
      const score = clamp(value + rand(-45, 30), 250, 900);
      return {
        attribute,
        score,
        percentile: clamp(score / 1000, 0.0001, 0.9999),
        unlocked: true,
        isEstimated: false,
        isStale: false,
        scoringVersionId: SCORING_VERSION_UUID,
      };
    });

    // Séances : 3 à 12 WODs distincts, perf interpolée au niveau du profil.
    const nSessions = rand(3, 12);
    const picks = shuffled(WOD_KEYS).slice(0, nSessions);
    const wodResults = picks.map((wodId, di) => {
      const perf = SEED_PERF[wodId];
      const [elite, beginner] = p.sex === "male" ? perf.m : perf.f;
      // t haut = meilleur → se rapproche du repère élite (temps plus bas / reps plus hautes).
      const base = perf.time ? beginner - t * (beginner - elite) : beginner + t * (elite - beginner);
      const jitter = perf.time ? base * (rand(-4, 6) / 100) : base * (rand(-8, 8) / 100);
      const raw = Math.max(1, Math.round(base + jitter));
      const subScore = clamp(value + rand(-30, 25), 200, 950);
      const daysAgo = di === 0 ? rand(0, 6) : rand(7, 90); // 1re séance cette semaine (activité récente)
      return {
        wodId,
        sex: p.sex,
        rawResult: raw,
        subScore,
        percentile: clamp(subScore / 1000, 0.0001, 0.9999),
        attributesAffected: perf.attrs,
        rxCompliant: true,
        scoringVersionId: SCORING_VERSION_UUID,
        idempotencyKey: `seed_fill_${wodId}`,
        performedAt: new Date(Date.now() - daysAgo * 86400000),
      };
    });

    const user = await prisma.user.create({
      data: {
        email: `seed_fill_${i}@hybrid.local`,
        dateOfBirth: new Date(`${rand(1988, 2003)}-0${rand(1, 9)}-1${rand(0, 8)}`),
        ageVerified: true,
        consents: { seed: true },
        profile: { create: { displayName: p.name, sex: p.sex, goal: p.goal, equipmentPref: "both", rank } },
        // Avatar DiceBear (rendu par HiAvatar dès que diceSeed est présent) — seed = pseudo, stable.
        avatar: {
          create: {
            skinTone: 0,
            hairStyle: 0,
            hairColor: 0,
            diceStyle: "adventurer",
            diceSeed: p.name,
            equippedCosmetics: {},
            unlockedCosmetics: {},
          },
        },
        hybridIndex: {
          create: {
            value,
            percentile: clamp(percentileFromInternal(value), 0.0001, 0.9999),
            isProvisional: false,
            isEstimated: false,
            radarCoverage: ATTRS.length,
            confidenceLevel: "high",
            scoringVersionId: SCORING_VERSION_UUID,
          },
        },
        attributeScores: { create: attributeScores },
        wodResults: { create: wodResults },
      },
      select: { id: true },
    });

    // Classement (Redis) : score = valeur interne (même clé de tri que Postgres).
    await redis.zadd(`leaderboard:${p.sex}`, value, user.id).catch(() => {
      redisOk = false;
    });

    console.log(`  + ${p.name} (${p.sex}) · Index ${display} /100 · interne ${value} · ${nSessions} séances`);
    created++;
  }

  console.log(`\n✅ ${created} fill users créés. Redis ${redisOk ? "peuplé" : "indisponible (le classement se répare depuis Postgres à la lecture)"}.`);
  redis.disconnect();
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error("Seed fill users KO:", e);
  await prisma.$disconnect();
  process.exit(1);
});
