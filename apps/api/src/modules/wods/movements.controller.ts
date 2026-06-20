import { Controller, Get } from "@nestjs/common";
import type { internalScore } from "@hybrid-index/contracts";
import { WodsService } from "./wods.service";

@Controller("v1/movements")
export class MovementsController {
  constructor(private readonly wods: WodsService) {}

  /** Catalogue public des mouvements (pour le constructeur de WOD). */
  @Get()
  list(): Promise<internalScore.MovementSummary[]> {
    return this.wods.movements();
  }
}
