import "reflect-metadata";
import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import type { AddressInfo } from "node:net";
import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { AppModule as ScoreAppModule } from "@hybrid-index/score-service/dist/app.module";
import { configureApp as configureScoreApp } from "@hybrid-index/score-service/dist/app.config";
import { isoWeekKey } from "../src/modules/engagement/iso-week";
import { leagueWeekPoints } from "../src/modules/league/league-points.logic";

/**
 * Mode Ligue (e2e réel) — la SYNERGIE « 1 log → 2 usages » et ses garde-fous :
 *  - inscrit + log du WOD imposé de la semaine -> points de Ligue créés, visibles au classement ;
 *  - pas inscrit -> aucun point ; WOD ≠ imposé -> aucun point.
 * Nécessite Postgres + Redis up et la migration league appliquée en local.
 */
describe("api — mode Ligue (e2e réel)", () => {
  let scoreApp: INestApplication;
  let api: INestApplication;
  let prisma: PrismaClient;

  const stamp = Date.now();
  const email = `e2e_league_${stamp}@test.local`;
  let token = "";
  let userId = "";
  let seasonId = "";
  const IMPOSED_WOD = "fran"; // WOD imposé de la semaine de test (WOD valide connu du score-service)

  beforeAll(async () => {
    const scoreRef = await Test.createTestingModule({ imports: [ScoreAppModule] }).compile();
    scoreApp = configureScoreApp(scoreRef.createNestApplication());
    await scoreApp.listen(0);
    const port = (scoreApp.getHttpServer().address() as AddressInfo).port;
    process.env.SCORE_SERVICE_URL = `http://127.0.0.1:${port}`;

    const { AppModule } = await import("../src/app.module");
    const { configureApp } = await import("../src/app.config");
    const apiRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    api = configureApp(apiRef.createNestApplication());
    await api.init();

    prisma = new PrismaClient();

    const reg = await request(api.getHttpServer())
      .post("/v1/auth/register")
      .send({ email, password: "motdepasse123", displayName: `Ligue${stamp}`, dateOfBirth: "1995-05-10", sex: "male", goal: "hyrox" })
      .expect(201);
    token = reg.body.token;
    userId = reg.body.user.id;

    // Saison active contrôlée + 1 semaine imposée = la semaine ISO courante, WOD = fran.
    const now = new Date();
    // Robustesse : retire toute saison résiduelle couvrant « maintenant » (sinon findFirst est
    // ambigu entre elle et la saison de test → flake). N'affecte pas les saisons futures (ex. 2026-09).
    await prisma.leagueSeason.deleteMany({
      where: { status: "active", opensAt: { lte: now }, closesAt: { gt: now } },
    });
    const season = await prisma.leagueSeason.create({
      data: {
        monthKey: `e2e-${stamp}`,
        status: "active",
        divisionTier: 1,
        opensAt: new Date(now.getTime() - 86_400_000),
        closesAt: new Date(now.getTime() + 30 * 86_400_000),
      },
    });
    seasonId = season.id;
    await prisma.leagueWeek.create({
      data: {
        seasonId: season.id,
        weekIndex: 1,
        weekKey: isoWeekKey(now),
        wodId: IMPOSED_WOD,
        filiere: "bodyweight",
        opensAt: new Date(now.getTime() - 86_400_000),
        closesAt: new Date(now.getTime() + 6 * 86_400_000),
      },
    });

    // Avatar de l'athlète de test → la ligne de classement Ligue doit exposer la même vignette.
    await prisma.avatar.create({
      data: {
        userId,
        skinTone: 2,
        hairStyle: 1,
        hairColor: 3,
        beardStyle: null,
        accessory: 0,
        background: 4,
        diceStyle: "bottts",
        diceSeed: "league-seed",
        diceOptions: JSON.stringify({ baseColor: "00897b" }),
        equippedCosmetics: {},
        unlockedCosmetics: {},
      },
    });
  });

  afterAll(async () => {
    if (seasonId) await prisma.leagueSeason.deleteMany({ where: { id: seasonId } }).catch(() => undefined); // cascade league_*
    if (userId) {
      await prisma.hybridIndexHistory.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.progressWeekly.deleteMany({ where: { userId } }).catch(() => undefined);
      await prisma.user.deleteMany({ where: { id: userId } }).catch(() => undefined);
    }
    await prisma.$disconnect().catch(() => undefined);
    await api?.close();
    await scoreApp?.close();
    delete process.env.SCORE_SERVICE_URL;
  });

  it("pas inscrit : loguer le WOD imposé ne donne AUCUN point de Ligue", async () => {
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: IMPOSED_WOD, scoreType: "time", rawResult: 360 })
      .expect(201);
    const count = await prisma.leaguePoints.count({ where: { seasonId, userId } });
    expect(count).toBe(0);
  });

  it("inscription opt-in : 201 + enrolled", async () => {
    const res = await request(api.getHttpServer())
      .post("/v1/league/enroll")
      .set("authorization", `Bearer ${token}`)
      .expect(201);
    expect(res.body.enrolled).toBe(true);
    expect(res.body.sex).toBe("male");
  });

  it("inscrit + log du WOD imposé : points de Ligue créés (= barème) et visibles au classement", async () => {
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: IMPOSED_WOD, scoreType: "time", rawResult: 360 })
      .expect(201);

    const row = await prisma.leaguePoints.findFirst({ where: { seasonId, userId }, orderBy: { createdAt: "desc" } });
    expect(row).toBeTruthy();
    expect(row!.points).toBe(leagueWeekPoints(row!.subScore));
    expect(row!.points).toBeGreaterThanOrEqual(100);

    const standings = await request(api.getHttpServer())
      .get("/v1/league/standings?sex=male")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    const me = (standings.body.entries as Array<{ isMe: boolean; points: number; avatar: unknown }>).find((e) => e.isMe);
    expect(me).toBeTruthy();
    expect(me!.points).toBe(row!.points);
    // La ligne de classement porte l'avatar (même forme JSON que le profil public) → mini-vignette mobile.
    expect(me!.avatar).toEqual({
      skinTone: 2,
      hairStyle: 1,
      hairColor: 3,
      beardStyle: null,
      accessory: 0,
      background: 4,
      photoData: null,
      diceStyle: "bottts",
      diceSeed: "league-seed",
      diceOptions: { baseColor: "00897b" },
    });
    // Chaque entrée expose le champ `avatar` (présent même si null pour les athlètes sans avatar).
    for (const e of standings.body.entries as Array<Record<string, unknown>>) expect(e).toHaveProperty("avatar");

    const meView = await request(api.getHttpServer())
      .get("/v1/league/me")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(meView.body.enrolled).toBe(true);
    expect(meView.body.position).toBe(1);
    expect(meView.body.weeksPlayed).toBe(1);
  });

  it("inscrit mais WOD ≠ imposé : aucun point de Ligue pour ce WOD", async () => {
    const before = await prisma.leaguePoints.count({ where: { seasonId, userId } });
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: "row_2k", scoreType: "time", rawResult: 480 }) // pas le WOD imposé
      .expect(201);
    const after = await prisma.leaguePoints.count({ where: { seasonId, userId } });
    expect(after).toBe(before); // inchangé
  });

  it("saison courante exposée avec le WOD de la semaine", async () => {
    const res = await request(api.getHttpServer())
      .get("/v1/league/season/current")
      .set("authorization", `Bearer ${token}`)
      .expect(200);
    expect(res.body.currentWeek?.wodId).toBe(IMPOSED_WOD);
    expect(res.body.enrolled).toBe(true);
  });

  it("relog d'un même résultat devenu suspect (pending_review) : retiré du classement Ligue (B2)", async () => {
    const key = `e2e_league_relog_${stamp}`;
    // 1) Log honnête du WOD imposé (clé idempotente) → ligne de points créée.
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: IMPOSED_WOD, scoreType: "time", rawResult: 360, idempotencyKey: key })
      .expect(201);
    const wr = await prisma.wodResult.findFirst({ where: { userId, idempotencyKey: key } });
    expect(wr).toBeTruthy();
    expect(await prisma.leaguePoints.count({ where: { wodResultId: wr!.id } })).toBe(1);

    // 2) Relog MÊME clé avec un temps quasi-champion (saut > +30 %) → le résultat passe en
    //    pending_review (anti-triche) ; la ligne de points Ligue doit DISPARAÎTRE.
    await request(api.getHttpServer())
      .post("/v1/results")
      .set("authorization", `Bearer ${token}`)
      .send({ wodId: IMPOSED_WOD, scoreType: "time", rawResult: 120, idempotencyKey: key })
      .expect(201);
    const wr2 = await prisma.wodResult.findFirst({ where: { userId, idempotencyKey: key } });
    expect(wr2!.review).toBe("pending_review");
    expect(await prisma.leaguePoints.count({ where: { wodResultId: wr!.id } })).toBe(0);
  });
});
