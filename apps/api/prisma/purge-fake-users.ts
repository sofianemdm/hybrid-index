// Purge des faux comptes / comptes de test en base.
//
// SÉCURITÉ : mode DRY-RUN par défaut (liste seulement, ne supprime RIEN). Ajouter `--apply` pour
// exécuter réellement. Ne supprime QUE les emails de test évidents (jamais un vrai email) :
//   *@example.com · *@test.local · *@hybrid.local · seed_*
// Il LISTE aussi tous les AUTRES comptes (vrais emails) pour que l'humain décide s'il faut en
// retirer d'autres (à faire nommément, jamais automatiquement).
//
// Usage :
//   DATABASE_URL="<prod>" REDIS_URL="<prod>" node --env-file-if-exists=.env dist-scripts/purge-fake-users.js
//   (ou via ts-node / tsx). Sans --apply = dry-run.
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

// Patterns 100 % « non réels » (comptes de test/seed) — sûrs à supprimer automatiquement.
const FAKE_EMAIL_CONDITIONS = [
  { endsWith: "@example.com" },
  { endsWith: "@test.local" },
  { endsWith: "@hybrid.local" },
  { startsWith: "seed_" },
];

async function main(): Promise<void> {
  const apply = process.argv.includes("--apply");

  const all = await prisma.user.findMany({
    select: { id: true, email: true, displayName: true, createdAt: true },
    orderBy: { createdAt: "asc" },
  });

  const isFake = (email: string): boolean =>
    FAKE_EMAIL_CONDITIONS.some((c) =>
      ("endsWith" in c && email.toLowerCase().endsWith(c.endsWith)) ||
      ("startsWith" in c && email.toLowerCase().startsWith(c.startsWith)),
    );

  const fake = all.filter((u) => isFake(u.email));
  const real = all.filter((u) => !isFake(u.email));

  console.log(`\n=== ${all.length} comptes au total ===`);
  console.log(`\n--- ${fake.length} FAUX comptes (patterns de test) → SERONT SUPPRIMÉS ---`);
  for (const u of fake) console.log(`  [suppr] ${u.email}  (${u.displayName ?? "—"})`);
  console.log(`\n--- ${real.length} AUTRES comptes (vrais emails) → CONSERVÉS ---`);
  for (const u of real) console.log(`  [garde] ${u.email}  (${u.displayName ?? "—"})`);

  if (!apply) {
    console.log(`\nDRY-RUN : rien supprimé. Relance avec --apply pour supprimer les ${fake.length} faux comptes.`);
    return;
  }

  if (fake.length === 0) {
    console.log("\nAucun faux compte à supprimer.");
    return;
  }

  const ids = fake.map((u) => u.id);
  const res = await prisma.user.deleteMany({ where: { id: { in: ids } } });
  // Les feedback ont une FK LOGIQUE (pas de relation Prisma) → nettoyage explicite.
  await prisma.$executeRawUnsafe(
    `DELETE FROM app.feedback WHERE user_id = ANY($1::text[])`,
    ids,
  ).catch(() => {/* table/colonne absente selon schéma : sans effet */});

  console.log(`\n✅ ${res.count} faux comptes supprimés (cascade : profils, avatars, Index, résultats…).`);
  console.log("⚠️  Redis (classements) : lancer le nettoyage des sorted sets leaderboard:* séparément.");
}

main()
  .catch((e) => {
    console.error("Purge KO:", e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
