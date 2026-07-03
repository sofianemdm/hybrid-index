import { execSync } from "node:child_process";
import { join } from "node:path";

/**
 * jest globalSetup — UNE fois par run de tests, avant toutes les suites :
 * 1. crée la base de test si absente (idempotent : l'erreur « existe déjà » est ignorée),
 * 2. applique les migrations (migrate deploy, no-op si à jour),
 * 3. seed WODs/badges/version de scoring (upserts idempotents, AUCUN utilisateur —
 *    les 5 WODs Ligue sont requis par le garde-fou d'ouverture de saison).
 * Les suites démarrent donc toujours d'un état connu, sur une base ISOLÉE de la dev.
 */
export default async function globalSetup(): Promise<void> {
  const apiDir = join(__dirname, "..");
  const testUrl = process.env.TEST_DATABASE_URL ?? "postgres://hybrid:hybrid@localhost:5432/hybrid_index_test";
  const adminUrl = testUrl.replace(/\/[^/]+$/, "/postgres"); // même serveur, base d'administration
  const dbName = testUrl.split("/").pop()!.split("?")[0];
  const env = {
    ...process.env,
    DATABASE_URL: testUrl,
    REDIS_URL: process.env.TEST_REDIS_URL ?? "redis://localhost:6379/1",
  };

  // 1. CREATE DATABASE si absente (pas de IF NOT EXISTS en SQL Postgres → erreur avalée).
  try {
    execSync(`npx prisma db execute --url "${adminUrl}" --stdin`, {
      cwd: apiDir,
      input: `CREATE DATABASE ${dbName}`,
      stdio: ["pipe", "ignore", "ignore"],
    });
  } catch {
    /* existe déjà — attendu à chaque run sauf le premier */
  }

  // 2. Migrations (idempotent). stdio hérité : un échec DOIT être visible et bloquant.
  execSync("npx prisma migrate deploy", { cwd: apiDir, env, stdio: "inherit" });

  // 3. Seed WODs/badges (idempotent, 0 utilisateur).
  execSync("npx ts-node prisma/seed.ts", { cwd: apiDir, env, stdio: "inherit" });
}
