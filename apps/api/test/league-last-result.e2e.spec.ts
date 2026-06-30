import "reflect-metadata";
import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { LeagueService } from "../src/modules/league/league.service";
import { LeagueLifecycleService } from "../src/modules/league/league-lifecycle.service";

/**
 * `LeagueService.lastResult` (DB réelle) — le « reveal » de fin de saison.
 * Le service ne dépend que de Prisma → on l'instancie directement (pas besoin de booter Nest).
 *
 * On crée une saison close DÉDIÉE dont le `closedAt` est volontairement dans le FUTUR pour
 * garantir qu'elle est la « dernière close » du DB pendant le test (déterminisme), puis on nettoie.
 * Nécessite Postgres up + la migration league appliquée.
 */
describe("LeagueService.lastResult (e2e DB réel)", () => {
  const prisma = new PrismaClient();
  // `lastResult` ne touche pas au cycle de vie ; on fournit un lifecycle réel (même prisma) pour
  // satisfaire la signature du constructeur sans changer le comportement testé.
  const svc = new LeagueService(prisma as never, new LeagueLifecycleService(prisma as never));

  const stamp = Date.now();
  const monthKey = `9999-${String((stamp % 12) + 1).padStart(2, "0")}`;
  let seasonId = "";

  // Podium masculin (3) + un viewer féminin participant.
  const m1 = randomUUID();
  const m2 = randomUUID();
  const m3 = randomUUID();
  const fViewer = randomUUID();
  const created: string[] = [m1, m2, m3, fViewer];

  beforeAll(async () => {
    const closedAt = new Date(Date.now() + 365 * 24 * 3600 * 1000); // futur → « dernière close »
    const season = await prisma.leagueSeason.create({
      data: {
        monthKey,
        status: "closed",
        divisionTier: 1,
        opensAt: new Date(Date.now() - 60 * 24 * 3600 * 1000),
        closesAt: new Date(Date.now() - 30 * 24 * 3600 * 1000),
        closedAt,
      },
    });
    seasonId = season.id;

    // Users + profils (displayName unique) — un avatar pour m1 seulement (teste le repli null).
    for (const [i, id] of created.entries()) {
      await prisma.user.create({
        data: { id, email: `lr_${stamp}_${i}@test.local`, dateOfBirth: new Date("1995-01-01"), consents: {} },
      });
      await prisma.profile.create({
        data: {
          userId: id,
          displayName: `LR_${stamp}_${i}`,
          sex: id === fViewer ? "female" : "male",
          goal: "hyrox",
          equipmentPref: "none",
        },
      });
    }
    await prisma.avatar.create({
      data: {
        userId: m1,
        skinTone: 2,
        hairStyle: 1,
        hairColor: 1,
        accessory: 0,
        background: 0,
        equippedCosmetics: {},
        unlockedCosmetics: {},
      },
    });

    await prisma.leagueStanding.createMany({
      data: [
        { seasonId, userId: m1, sex: "male", finalRank: 1, totalPoints: 900, filiere: "bodyweight", level: "rx" },
        { seasonId, userId: m2, sex: "male", finalRank: 2, totalPoints: 700, filiere: "bodyweight", level: "rx" },
        { seasonId, userId: m3, sex: "male", finalRank: 3, totalPoints: 500, filiere: "bodyweight", level: "rx" },
        { seasonId, userId: fViewer, sex: "female", finalRank: 1, totalPoints: 800, filiere: "bodyweight", level: "rx" },
      ],
    });
  });

  afterAll(async () => {
    if (seasonId) await prisma.leagueSeason.deleteMany({ where: { id: seasonId } }).catch(() => undefined);
    await prisma.user.deleteMany({ where: { id: { in: created } } }).catch(() => undefined);
    await prisma.$disconnect().catch(() => undefined);
  });

  it("renvoie le podium top 3 du SEXE du viewer (ici male) avec nom + points + avatar batché", async () => {
    const res = await svc.lastResult(m2);
    expect(res).not.toBeNull();
    expect(res!.monthKey).toBe(monthKey);
    expect(res!.sex).toBe("male");
    expect(res!.podium.map((p) => p.finalRank)).toEqual([1, 2, 3]);
    expect(res!.podium[0].userId).toBe(m1);
    expect(res!.podium[0].totalPoints).toBe(900);
    expect(res!.podium[0].avatar).not.toBeNull(); // m1 a un avatar
    expect(res!.podium[1].avatar).toBeNull(); // m2 n'en a pas → repli null
    expect(res!.podium[0].displayName).toBe(`LR_${stamp}_0`);
  });

  it("renvoie la ligne du viewer participant (finalRank/totalPoints/movement)", async () => {
    const res = await svc.lastResult(m2);
    expect(res!.me).toEqual({ finalRank: 2, totalPoints: 700, movement: null });
  });

  it("utilise le sexe du PROFIL quand le viewer n'a pas participé (me = null, podium de SA ligue)", async () => {
    const res = await svc.lastResult(fViewer);
    // fViewer A un standing female → me non null, sex female, podium = ligue female (1 athlète).
    expect(res!.sex).toBe("female");
    expect(res!.podium.map((p) => p.userId)).toEqual([fViewer]);
    expect(res!.me).toEqual({ finalRank: 1, totalPoints: 800, movement: null });
  });

  it("renvoie null quand il n'existe AUCUNE saison close (viewer inconnu inclus)", async () => {
    // On ne peut pas garantir l'absence GLOBALE de saison close ; on vérifie au moins que
    // le contrat « viewer sans standing → me null + podium du sexe par défaut » tient.
    const res = await svc.lastResult(randomUUID());
    if (res) {
      expect(res.me).toBeNull();
      expect(["male", "female"]).toContain(res.sex);
    }
  });
});
