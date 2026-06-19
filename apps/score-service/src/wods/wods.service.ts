import { Injectable, NotFoundException } from "@nestjs/common";
import { WODS, WODS_BY_ID } from "./wods.data";
import type { WodDefinition } from "./wod.types";

@Injectable()
export class WodsService {
  all(): ReadonlyArray<WodDefinition> {
    return WODS;
  }

  find(wodId: string): WodDefinition | undefined {
    return WODS_BY_ID.get(wodId);
  }

  getOrThrow(wodId: string): WodDefinition {
    const wod = this.find(wodId);
    if (!wod) {
      throw new NotFoundException({ code: "NOT_FOUND", message: `WOD inconnu : ${wodId}` });
    }
    return wod;
  }
}
