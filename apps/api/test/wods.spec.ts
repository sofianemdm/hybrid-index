import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from "@nestjs/common";
import { CreateWodRequest } from "../src/modules/wods/create-wod.dto";
import { EstimateWodRequest } from "../src/modules/wods/wod-estimate.dto";
import { WodsService } from "../src/modules/wods/wods.service";

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
