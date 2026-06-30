import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from "@nestjs/common";
import { CreateWodRequest } from "../src/modules/wods/create-wod.dto";
import { EstimateWodRequest } from "../src/modules/wods/wod-estimate.dto";
import { WodsService } from "../src/modules/wods/wods.service";
import { WOD_PRESCRIPTIONS } from "../src/modules/wods/wod-prescriptions.data";

/** Un payload de base valide ; chaque test n'écrase que le champ qu'il vérifie. */
const baseBody = (): unknown => ({
  name: "Mon WOD",
  type: "for_time",
  scoreType: "time",
  requiresEquipment: false,
  blocks: [{ movementId: "burpee", reps: 50 }],
});

describe("CreateWodRequest — bornes anti-abus", () => {
  it("accepte un payload raisonnable", () => {
    expect(CreateWodRequest.safeParse(baseBody()).success).toBe(true);
  });

  it("rejette des reps absurdes (> 100000)", () => {
    const body = { ...(baseBody() as Record<string, unknown>), blocks: [{ movementId: "burpee", reps: 1_000_000 }] };
    expect(CreateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette une charge absurde (> 1000 kg)", () => {
    const body = { ...(baseBody() as Record<string, unknown>), blocks: [{ movementId: "deadlift", loadKg: 5_000 }] };
    expect(CreateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette un nombre de tours absurde (> 100)", () => {
    const body = { ...(baseBody() as Record<string, unknown>), rounds: 9_999 };
    expect(CreateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette un timeCap absurde (> 24 h)", () => {
    const body = { ...(baseBody() as Record<string, unknown>), timeCapSec: 200_000 };
    expect(CreateWodRequest.safeParse(body).success).toBe(false);
  });

  it("accepte les valeurs limites exactes", () => {
    const body = {
      ...(baseBody() as Record<string, unknown>),
      rounds: 100,
      timeCapSec: 86_400,
      blocks: [{ movementId: "deadlift", reps: 100_000, loadKg: 1_000 }],
    };
    expect(CreateWodRequest.safeParse(body).success).toBe(true);
  });
});

describe("EstimateWodRequest — bornes anti-abus/DoS (endpoint PUBLIC /estimate)", () => {
  /** Payload d'estimation valide ; chaque test n'écrase que le champ vérifié. */
  const baseEstimate = (): unknown => ({
    sex: "male",
    scoreType: "time",
    wodType: "for_time",
    blocks: [{ movementId: "burpee", reps: 50 }],
  });

  it("accepte un payload raisonnable", () => {
    expect(EstimateWodRequest.safeParse(baseEstimate()).success).toBe(true);
  });

  it("rejette des reps absurdes (> 100000)", () => {
    const body = { ...(baseEstimate() as Record<string, unknown>), blocks: [{ movementId: "burpee", reps: 1_000_000 }] };
    expect(EstimateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette une charge absurde (> 1000 kg)", () => {
    const body = { ...(baseEstimate() as Record<string, unknown>), blocks: [{ movementId: "deadlift", loadKg: 5_000 }] };
    expect(EstimateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette une distance absurde (> 1 000 000 m)", () => {
    const body = { ...(baseEstimate() as Record<string, unknown>), blocks: [{ movementId: "run", distanceMeters: 5_000_000 }] };
    expect(EstimateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette des calories absurdes (> 100000)", () => {
    const body = { ...(baseEstimate() as Record<string, unknown>), blocks: [{ movementId: "row", calories: 1_000_000 }] };
    expect(EstimateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette une durée de bloc absurde (> 24 h)", () => {
    const body = { ...(baseEstimate() as Record<string, unknown>), blocks: [{ movementId: "plank", durationSec: 200_000 }] };
    expect(EstimateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette un nombre de tours absurde (> 100)", () => {
    const body = { ...(baseEstimate() as Record<string, unknown>), rounds: 9_999 };
    expect(EstimateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette un timeCap absurde (> 24 h)", () => {
    const body = { ...(baseEstimate() as Record<string, unknown>), timeCapSec: 200_000 };
    expect(EstimateWodRequest.safeParse(body).success).toBe(false);
  });

  it("rejette un tableau de blocs géant (> 20)", () => {
    const blocks = Array.from({ length: 21 }, () => ({ movementId: "burpee", reps: 10 }));
    const body = { ...(baseEstimate() as Record<string, unknown>), blocks };
    expect(EstimateWodRequest.safeParse(body).success).toBe(false);
  });

  it("accepte les valeurs limites exactes", () => {
    const body = {
      ...(baseEstimate() as Record<string, unknown>),
      rounds: 100,
      timeCapSec: 86_400,
      blocks: [
        {
          movementId: "deadlift",
          reps: 100_000,
          loadKg: 1_000,
          distanceMeters: 1_000_000,
          calories: 100_000,
          durationSec: 86_400,
        },
      ],
    };
    expect(EstimateWodRequest.safeParse(body).success).toBe(true);
  });
});

describe("WodsService.create — garde-fou anti-spam (rate limit applicatif)", () => {
  const buildService = (recentCount: number): { service: WodsService; createMock: jest.Mock } => {
    const createMock = jest.fn();
    const prisma = {
      wod: {
        count: jest.fn().mockResolvedValue(recentCount),
        create: createMock,
      },
      profile: { findUnique: jest.fn().mockResolvedValue({ sex: "male" }) },
    };
    const scoreClient = { computeEstimate: jest.fn().mockResolvedValue({ attributesAffected: ["hybrid"] }) };
    const service = new WodsService(
      prisma as never,
      scoreClient as never,
      {} as never,
      {} as never,
      {} as never,
    );
    return { service, createMock };
  };

  const body = baseBody() as never;

  it("refuse (RATE_LIMIT) au-delà du seuil horaire", async () => {
    const { service, createMock } = buildService(WodsService.MAX_CUSTOM_WODS_PER_HOUR);
    await expect(service.create("user-1", body)).rejects.toBeInstanceOf(BadRequestException);
    expect(createMock).not.toHaveBeenCalled();
    await service.create("user-1", body).catch((e: BadRequestException) => {
      expect((e.getResponse() as { code: string }).code).toBe("RATE_LIMIT");
    });
  });

  it("laisse passer sous le seuil (n'atteint pas l'erreur de rate limit)", async () => {
    const { service } = buildService(WodsService.MAX_CUSTOM_WODS_PER_HOUR - 1);
    // create() poursuit au-delà du garde-fou : il échouera plus loin (mocks partiels), mais JAMAIS
    // sur un RATE_LIMIT. On vérifie donc seulement que ce n'est pas une BadRequestException RATE_LIMIT.
    await service.create("user-1", body).catch((e: unknown) => {
      if (e instanceof BadRequestException) {
        expect((e.getResponse() as { code?: string }).code).not.toBe("RATE_LIMIT");
      }
    });
  });
});

describe("WodsService.update / remove — garde-fous propriété & custom", () => {
  type WodRow = { id: string; isCustom: boolean; createdById: string | null };

  const buildService = (
    wod: WodRow | null,
    opts: { resultCount?: number } = {},
  ): {
    service: WodsService;
    updateMock: jest.Mock;
    deleteMock: jest.Mock;
    detailMock: jest.SpyInstance;
  } => {
    const updateMock = jest.fn().mockResolvedValue({ id: wod?.id });
    const deleteMock = jest.fn().mockResolvedValue({ id: wod?.id });
    const prisma = {
      wod: {
        findUnique: jest.fn().mockResolvedValue(wod),
        update: updateMock,
        delete: deleteMock,
      },
      wodResult: { count: jest.fn().mockResolvedValue(opts.resultCount ?? 0) },
      profile: { findUnique: jest.fn().mockResolvedValue({ sex: "male" }) },
    };
    const scoreClient = { computeEstimate: jest.fn().mockResolvedValue({ attributesAffected: ["hybrid"] }) };
    const service = new WodsService(prisma as never, scoreClient as never, {} as never, {} as never, {} as never);
    // detail() rejoue tout un pipeline d'estimation → on le neutralise (testé ailleurs).
    const detailMock = jest.spyOn(service, "detail").mockResolvedValue({ id: wod?.id } as never);
    return { service, updateMock, deleteMock, detailMock };
  };

  const body = (): never =>
    ({
      name: "WOD édité",
      type: "for_time",
      scoreType: "time",
      requiresEquipment: false,
      blocks: [{ movementId: "burpee", reps: 30 }],
    }) as never;

  it("update : le créateur d'un WOD custom peut éditer", async () => {
    const { service, updateMock } = buildService({ id: "w1", isCustom: true, createdById: "owner" });
    await service.update("owner", "w1", body());
    expect(updateMock).toHaveBeenCalledTimes(1);
  });

  it("update : un non-créateur reçoit 403", async () => {
    const { service, updateMock } = buildService({ id: "w1", isCustom: true, createdById: "owner" });
    await expect(service.update("intrus", "w1", body())).rejects.toBeInstanceOf(ForbiddenException);
    expect(updateMock).not.toHaveBeenCalled();
  });

  it("update : un WOD officiel/benchmark (non custom) est interdit (403) même au créateur", async () => {
    const { service, updateMock } = buildService({ id: "grace", isCustom: false, createdById: "owner" });
    await expect(service.update("owner", "grace", body())).rejects.toBeInstanceOf(ForbiddenException);
    expect(updateMock).not.toHaveBeenCalled();
  });

  it("update : WOD introuvable → 404", async () => {
    const { service } = buildService(null);
    await expect(service.update("owner", "ghost", body())).rejects.toBeInstanceOf(NotFoundException);
  });

  it("remove : le créateur supprime un WOD custom sans résultat", async () => {
    const { service, deleteMock } = buildService({ id: "w1", isCustom: true, createdById: "owner" }, { resultCount: 0 });
    await expect(service.remove("owner", "w1")).resolves.toEqual({ deleted: true });
    expect(deleteMock).toHaveBeenCalledTimes(1);
  });

  it("remove : un non-créateur reçoit 403", async () => {
    const { service, deleteMock } = buildService({ id: "w1", isCustom: true, createdById: "owner" });
    await expect(service.remove("intrus", "w1")).rejects.toBeInstanceOf(ForbiddenException);
    expect(deleteMock).not.toHaveBeenCalled();
  });

  it("remove : refuse (409) si des résultats existent déjà", async () => {
    const { service, deleteMock } = buildService({ id: "w1", isCustom: true, createdById: "owner" }, { resultCount: 3 });
    await expect(service.remove("owner", "w1")).rejects.toBeInstanceOf(ConflictException);
    expect(deleteMock).not.toHaveBeenCalled();
  });
});

describe("WodsService.detail — bloc `guided` (Mode guidé)", () => {
  type WodRow = {
    id: string;
    name: string;
    type: string;
    scoreType: string;
    rounds: number | null;
    timeCapSec: number | null;
    requiresEquipment: boolean;
    targetAttributes: string[];
    isBenchmark: boolean;
    isCustom: boolean;
    createdById: string | null;
  };

  const buildService = (wod: WodRow): WodsService => {
    const prisma = {
      wod: { findUnique: jest.fn().mockResolvedValue(wod) },
      // detail() sans userId → pas de requête wodResult, mais on mock par sécurité.
      wodResult: { findFirst: jest.fn(), findMany: jest.fn() },
    };
    // getWodLevels jette → levels = null (le bloc guided n'en dépend pas, c'est ce qu'on isole).
    const scoreClient = { getWodLevels: jest.fn().mockRejectedValue(new Error("score down")) };
    return new WodsService(prisma as never, scoreClient as never, {} as never, {} as never, {} as never);
  };

  const officialRow = (over: Partial<WodRow> = {}): WodRow => ({
    id: "grace",
    name: "Grace",
    type: "for_time",
    scoreType: "time",
    rounds: null,
    timeCapSec: null,
    requiresEquipment: true,
    targetAttributes: ["strength"],
    isBenchmark: true,
    isCustom: false,
    createdById: null,
    ...over,
  });

  it("expose format = type + capSec depuis la prescription + cues dérivés des blocks", async () => {
    const service = buildService(officialRow({ id: "grace", type: "for_time" }));
    const res = (await service.detail("grace")) as { guided: { format: string; capSec: number | null; cues: string[]; work: unknown[]; rounds: number | null } };
    expect(res.guided.format).toBe("for_time");
    // Grace a une prescription officielle avec timeCapSec → capSec hérité.
    expect(res.guided.capSec).toBe(WOD_PRESCRIPTIONS["grace"]?.timeCapSec ?? null);
    // cues = une ligne par block de la prescription.
    expect(res.guided.cues.length).toBe(WOD_PRESCRIPTIONS["grace"]?.blocks.length ?? 0);
    // for_time → pas de fenêtres canoniques.
    expect(res.guided.work).toEqual([]);
  });

  it("tabata → fenêtres canoniques 20/10 dans work[]", async () => {
    // Pas de prescription tabata officielle → on force un wod custom tabata pour isoler buildGuided.
    const service = buildService(officialRow({ id: "tab", type: "tabata", isCustom: false, timeCapSec: 240, rounds: 8 }));
    const res = (await service.detail("tab")) as { guided: { format: string; work: Array<{ kind: string; durationSec: number }> } };
    expect(res.guided.format).toBe("tabata");
    expect(res.guided.work).toEqual([
      { kind: "work", durationSec: 20 },
      { kind: "rest", durationSec: 10 },
    ]);
  });

  it("rounds & capSec viennent du WOD quand la prescription n'en porte pas", async () => {
    const service = buildService(officialRow({ id: "emomx", type: "emom", rounds: 12, timeCapSec: 720 }));
    const res = (await service.detail("emomx")) as { guided: { rounds: number | null; capSec: number | null } };
    // Pas de prescription pour "emomx" → capSec retombe sur wod.timeCapSec, rounds sur wod.rounds.
    expect(res.guided.rounds).toBe(12);
    expect(res.guided.capSec).toBe(720);
  });

  it("WOD introuvable → 404 (inchangé)", async () => {
    const prisma = { wod: { findUnique: jest.fn().mockResolvedValue(null) } };
    const service = new WodsService(prisma as never, {} as never, {} as never, {} as never, {} as never);
    await expect(service.detail("ghost")).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe("WodsService.detail — movementIds canoniques (guide des mouvements)", () => {
  type Row = {
    id: string;
    name: string;
    type: string;
    scoreType: string;
    rounds: number | null;
    timeCapSec: number | null;
    requiresEquipment: boolean;
    targetAttributes: string[];
    isBenchmark: boolean;
    isCustom: boolean;
    createdById: string | null;
    movements?: unknown;
  };

  const row = (over: Partial<Row>): Row => ({
    id: "fran",
    name: "Fran",
    type: "for_time",
    scoreType: "time",
    rounds: null,
    timeCapSec: null,
    requiresEquipment: true,
    targetAttributes: ["strength"],
    isBenchmark: true,
    isCustom: false,
    createdById: null,
    ...over,
  });

  /**
   * Benchmark : detail() reçoit les movementIds du blueprint via la réponse `getWodLevels` du
   * score-service. On mock cette réponse avec les IDs canoniques attendus (mêmes que ceux produits
   * par `blueprintMovementIds`, testés côté score-service) et on vérifie qu'ils ressortent tels quels.
   */
  const benchmarkService = (id: string, movementIds: string[]): WodsService => {
    const prisma = {
      wod: { findUnique: jest.fn().mockResolvedValue(row({ id, name: id })) },
      wodResult: { findFirst: jest.fn(), findMany: jest.fn() },
    };
    const scoreClient = {
      getWodLevels: jest.fn().mockResolvedValue({
        wodId: id,
        scoreType: "time",
        male: { champion: 120, intermediate: 240, occasional: 480 },
        female: { champion: 150, intermediate: 300, occasional: 600 },
        movementIds,
      }),
    };
    return new WodsService(prisma as never, scoreClient as never, {} as never, {} as never, {} as never);
  };

  it("fran → [thruster, pull_up]", async () => {
    const service = benchmarkService("fran", ["thruster", "pull_up"]);
    const res = (await service.detail("fran")) as { movementIds: string[] };
    expect(res.movementIds).toEqual(["thruster", "pull_up"]);
  });

  it("benchmark_zero → [burpee, push_up, air_squat]", async () => {
    const service = benchmarkService("benchmark_zero", ["burpee", "push_up", "air_squat"]);
    const res = (await service.detail("benchmark_zero")) as { movementIds: string[] };
    expect(res.movementIds).toEqual(["burpee", "push_up", "air_squat"]);
  });

  // ergo_skill : rameur en CALORIES → `row_cal` (id canonique réel du blueprint), pas `row`.
  it("ergo_skill → [row_cal, wall_walk, toes_to_bar]", async () => {
    const service = benchmarkService("ergo_skill", ["row_cal", "wall_walk", "toes_to_bar"]);
    const res = (await service.detail("ergo_skill")) as { movementIds: string[] };
    expect(res.movementIds).toEqual(["row_cal", "wall_walk", "toes_to_bar"]);
  });

  it("score-service indisponible (getWodLevels rejette) → movementIds = [] (état dégradé)", async () => {
    const prisma = {
      wod: { findUnique: jest.fn().mockResolvedValue(row({ id: "fran" })) },
      wodResult: { findFirst: jest.fn(), findMany: jest.fn() },
    };
    const scoreClient = { getWodLevels: jest.fn().mockRejectedValue(new Error("down")) };
    const service = new WodsService(prisma as never, scoreClient as never, {} as never, {} as never, {} as never);
    const res = (await service.detail("fran")) as { movementIds: string[] };
    expect(res.movementIds).toEqual([]);
  });

  it("WOD custom → movementIds dérivés des blocs (wod.movements), ordonnés & dédupliqués", async () => {
    const prisma = {
      wod: {
        findUnique: jest.fn().mockResolvedValue(
          row({
            id: "w-custom",
            isCustom: true,
            isBenchmark: false,
            createdById: "owner",
            movements: [
              { movementId: "burpee", reps: 20 },
              { movementId: "push_up", reps: 30 },
              { movementId: "burpee", reps: 10 }, // doublon → ignoré
            ],
          }),
        ),
      },
      wodResult: { findFirst: jest.fn(), findMany: jest.fn() },
    };
    // computeEstimate (paliers custom) peut échouer : detail() retombe sur levels=null, sans incidence.
    const scoreClient = { computeEstimate: jest.fn().mockRejectedValue(new Error("n/a")) };
    const service = new WodsService(prisma as never, scoreClient as never, {} as never, {} as never, {} as never);
    const res = (await service.detail("w-custom")) as { movementIds: string[] };
    expect(res.movementIds).toEqual(["burpee", "push_up"]);
  });
});
