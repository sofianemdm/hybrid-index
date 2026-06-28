import { BadRequestException } from "@nestjs/common";
import { CreateWodRequest } from "../src/modules/wods/create-wod.dto";
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
