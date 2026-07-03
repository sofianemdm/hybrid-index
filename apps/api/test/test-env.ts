/**
 * ISOLATION des tests (jest setupFiles — s'exécute AVANT tout import de chaque fichier de test) :
 * les tests pointent sur une base DÉDIÉE (hybrid_index_test) et un index Redis dédié (db 1).
 * La base de DEV n'est plus JAMAIS touchée par un run de tests (fini : saison Ligue supprimée,
 * comptes e2e fantômes, nettoyage manuel après chaque run, assertions flakys inter-suites).
 *
 * Précédence : une variable posée ici GAGNE sur le .env (le dotenv intégré de Prisma n'écrase
 * jamais une variable déjà présente dans process.env).
 */
process.env.DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? "postgres://hybrid:hybrid@localhost:5432/hybrid_index_test";
process.env.REDIS_URL = process.env.TEST_REDIS_URL ?? "redis://localhost:6379/1";
