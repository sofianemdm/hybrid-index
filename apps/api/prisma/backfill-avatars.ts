/* eslint-disable no-console */
//
// Backfill avatars — donne un avatar DiceBear avataaars (nouveau système, gén. 3) à TOUT compte
// qui n'en a pas : row absente, ou ancien avatar (dessiné/adventurer) sans `diceOptions`.
// Seed = pseudo (stable), options = défauts par sexe (mêmes valeurs que l'éditeur mobile).
// Les comptes avec photo de profil ou avec diceOptions déjà posées ne sont PAS touchés.
// Idempotent : relançable sans effet sur les comptes déjà convertis.
//
// Usage (prod) :
//   DATABASE_URL="<prod>" npx ts-node apps/api/prisma/backfill-avatars.ts
//
import { PrismaClient } from "@prisma/client";
import { avataaarsDefaultsFor } from "./avataaars-defaults";

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const users = await prisma.user.findMany({
    where: { profile: { isNot: null } },
    select: {
      id: true,
      profile: { select: { displayName: true, sex: true } },
      avatar: { select: { diceOptions: true, photoData: true } },
    },
  });

  let converted = 0;
  let untouched = 0;
  for (const u of users) {
    const hasNewAvatar = Boolean(u.avatar?.diceOptions) || Boolean(u.avatar?.photoData);
    if (hasNewAvatar) {
      untouched++;
      continue;
    }
    const sex = u.profile!.sex === "female" ? "female" : "male";
    const data = {
      diceStyle: "avataaars",
      diceSeed: u.profile!.displayName,
      diceOptions: JSON.stringify(avataaarsDefaultsFor(sex)),
    };
    await prisma.avatar.upsert({
      where: { userId: u.id },
      create: { userId: u.id, ...data, equippedCosmetics: {}, unlockedCosmetics: {} },
      update: data,
    });
    console.log(`  ~ ${u.profile!.displayName} → avataaars auto (seed=pseudo)`);
    converted++;
  }

  console.log(`\n✅ Backfill terminé : ${converted} avatar(s) converti(s), ${untouched} déjà à jour.`);
}

main()
  .catch((e) => {
    console.error("Backfill KO:", e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
