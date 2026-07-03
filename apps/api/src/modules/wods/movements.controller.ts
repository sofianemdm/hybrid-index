import { Controller, Get } from "@nestjs/common";
import type { internalScore } from "@hybrid-index/contracts";
import { WodCatalogService } from "./wod-catalog.service";

@Controller("v1/movements")
export class MovementsController {
  constructor(private readonly catalog: WodCatalogService) {}

  /** Catalogue public des mouvements (pour le constructeur de WOD). */
  @Get()
  list(): Promise<internalScore.MovementSummary[]> {
    return this.catalog.movements();
  }
}
