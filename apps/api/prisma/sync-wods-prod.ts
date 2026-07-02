/* eslint-disable no-console */
/**
 * Synchro CIBLÉE et SÛRE des WODs vers une base (prod) : ajoute le WOD « 400 m Course » et
 * renomme les « Max air squats » → « Max squats ». N'AFFECTE NI les utilisateurs NI Redis
 * (contrairement au seed complet). Idempotent (upsert).
 *
 * Lancement : DATABASE_URL="<url>" pnpm --filter @hybrid-index/api exec ts-node prisma/sync-wods-prod.ts
 */
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  // 1) Nouveau WOD de référence 400 m (sans matériel, vitesse + moteur).
  await prisma.wod.upsert({
    where: { id: "run_400" },
    create: {
      id: "run_400",
      name: "400 m Course",
      isBenchmark: true,
      type: "for_time",
      requiresEquipment: false,
      targetAttributes: ["speed", "engine"],
      scoreType: "time",
      movements: {},
    },
    update: {
      name: "400 m Course",
      isBenchmark: true,
      scoreType: "time",
      requiresEquipment: false,
      targetAttributes: ["speed", "engine"],
    },
  });
  console.log("✓ run_400 (400 m Course) upserté");

  // 2) Renommage « air squats » → « squat ».
  const renames: Array<{ id: string; name: string }> = [
    { id: "max_air_squats", name: "Max squats (une série)" },
    { id: "max_air_squats_2min", name: "Max squats en 2 min" },
  ];
  for (const r of renames) {
    const res = await prisma.wod.updateMany({ where: { id: r.id }, data: { name: r.name } });
    console.log(`✓ ${r.id} → « ${r.name} » (${res.count} ligne(s))`);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
