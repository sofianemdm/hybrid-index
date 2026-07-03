/* eslint-disable no-console */
/**
 * RÉPARATION ponctuelle et idempotente : réattribue les points de Ligue MANQUANTS aux résultats
 * déjà enregistrés via la route de l'app (`/v1/wods/:id/results`), qui ne créditait pas la Ligue
 * avant le correctif du 03/07 (bug vécu sur « La Flèche » : séance faite, 0 point au classement).
 *
 * Pour chaque saison ACTIVE : parcourt ses semaines, retrouve les résultats `review=ok` portant
 * sur le WOD imposé de la semaine et effectués dans la fenêtre de la saison, et crée la ligne de
 * points si elle n'existe pas (barème officiel `leagueWeekPoints`). Inscription auto préservée.
 * Anti-double-comptage : `league_points.wodResultId` UNIQUE + skipDuplicates.
 *
 * Lancement : DATABASE_URL="<url>" pnpm --filter @hybrid-index/api exec ts-node prisma/repair-league-points.ts
 */
import { PrismaClient } from "@prisma/client";
import { isoWeekKey } from "../src/modules/engagement/iso-week";
import { leagueWeekPoints } from "../src/modules/league/league-points.logic";

const prisma = new PrismaClient();

async function main() {
  const seasons = await prisma.leagueSeason.findMany({ where: { status: "active" } });
  let repaired = 0;
  for (const season of seasons) {
    const weeks = await prisma.leagueWeek.findMany({ where: { seasonId: season.id } });
    for (const week of weeks) {
      const results = await prisma.wodResult.findMany({
        where: {
          wodId: week.wodId,
          review: "ok",
          subScore: { not: null },
          performedAt: { gte: season.opensAt, lt: season.closesAt },
        },
        select: { id: true, userId: true, sex: true, subScore: true, performedAt: true },
      });
      for (const r of results) {
        // Le résultat doit appartenir à la semaine ISO de CETTE ligne (même règle que le service).
        if (isoWeekKey(r.performedAt) !== week.weekKey) continue;
        const already = await prisma.leaguePoints.findUnique({ where: { wodResultId: r.id } });
        if (already) continue;
        await prisma.leagueEntry.upsert({
          where: { seasonId_userId: { seasonId: season.id, userId: r.userId } },
          create: { seasonId: season.id, userId: r.userId, sex: r.sex, filiere: "bodyweight", level: "rx" },
          update: {},
        });
        await prisma.leaguePoints.create({
          data: {
            seasonId: season.id,
            weekId: week.id,
            userId: r.userId,
            sex: r.sex,
            wodResultId: r.id,
            subScore: r.subScore!,
            points: leagueWeekPoints(r.subScore),
          },
        });
        repaired++;
        console.log(`+ points Ligue : user=${r.userId} wod=${week.wodId} semaine=${week.weekKey}`);
      }
    }
  }
  console.log(`Réparation terminée : ${repaired} ligne(s) de points créée(s).`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
