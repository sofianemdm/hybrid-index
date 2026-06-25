import "reflect-metadata";
import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { LeagueLifecycleService } from "../src/modules/league/league-lifecycle.service";
import { isoWeeksOfMonth } from "../src/modules/league/league.rotation";

/**
 * Cycle de vie d'une saison de Ligue (DB réelle). Le service ne dépend que de Prisma → on l'instancie
 * directement avec un PrismaClient (pas besoin de booter Nest). Nécessite Postgres + WODs seedés.
 */
describe("LeagueLifecycleService (e2e DB réel)", () => {
  const prisma = new PrismaClient();
  const svc = new LeagueLifecycleService(prisma as never);
  const MONTH = "2026-09";
  let seasonId = "";

  afterAll(async () => {
    if (seasonId) await prisma.leagueSeason.deleteMany({ where: { id: seasonId } }).catch(() => undefined);
    await prisma.$disconnect().catch(() => undefined);
  });

  it("openSeasonForMonth crée la saison + une semaine imposée par semaine ISO du mois", async () => {
    const res = await svc.openSeasonForMonth(MONTH);
    seasonId = res.id;
    const season = await prisma.leagueSeason.findUnique({ where: { id: res.id }, include: { weeks: true } });
    expect(season?.status).toBe("active");
    expect(season?.weeks.length).toBe(isoWeeksOfMonth(MONTH).length);
    expect(season?.weeks.every((w) => w.wodId.length > 0)).toBe(true);
  });

  it("openSeasonForMonth est idempotent (renvoie la même saison)", async () => {
    const again = await svc.openSeasonForMonth(MONTH);
    expect(again.id).toBe(seasonId);
  });

  it("closeSeason archive le classement final (points desc) et passe en closed", async () => {
    const season = await prisma.leagueSeason.findUnique({ where: { id: seasonId }, include: { weeks: true } });
    const weekId = season!.weeks[0].id;
    const uA = randomUUID();
    const uB = randomUUID();
    await prisma.leaguePoints.createMany({
      data: [
        { seasonId, weekId, userId: uA, sex: "male", wodResultId: randomUUID(), points: 800, subScore: 800 },
        { seasonId, weekId, userId: uB, sex: "male", wodResultId: randomUUID(), points: 500, subScore: 500 },
      ],
    });

    await svc.closeSeason(MONTH);

    const closed = await prisma.leagueSeason.findUnique({ where: { id: seasonId } });
    expect(closed?.status).toBe("closed");
    const standings = await prisma.leagueStanding.findMany({
      where: { seasonId, sex: "male" },
      orderBy: { finalRank: "asc" },
    });
    expect(standings[0].userId).toBe(uA); // 800 pts → rang 1
    expect(standings[0].finalRank).toBe(1);
    expect(standings[1].userId).toBe(uB);
  });

  it("closeSeason est idempotent (déjà close → no-op)", async () => {
    await expect(svc.closeSeason(MONTH)).resolves.toBeUndefined();
  });
});
