import { Injectable } from "@nestjs/common";
import type { internalScore } from "@hybrid-index/contracts";

/**
 * Registre des versions de scoring (courbe f + poids). Versionnement = décision verrouillée :
 * tout changement de f/poids crée une nouvelle version et déclenche un recalcul historique
 * (cf. architecture.md §5, decisions-log.md). À l'incrément 1, ce registre portera la courbe
 * `sigmoid-v1` et les jeux de poids ; ici on pose la version active.
 */
@Injectable()
export class ScoringVersionService {
  private readonly versions: ReadonlyArray<internalScore.ScoringVersionInfo> = [
    {
      id: "scoring-v1",
      status: "active",
      curve: "sigmoid-v1",
      // Date d'activation (constante au scaffold ; sera gérée en base à l'incrément 1).
      createdAt: "2026-06-19T00:00:00.000Z",
    },
  ];

  getActiveVersion(): internalScore.ScoringVersionInfo {
    const active = this.versions.find((v) => v.status === "active");
    if (!active) {
      throw new Error("Aucune version de scoring active configurée");
    }
    return active;
  }

  getActiveVersionId(): string {
    return this.getActiveVersion().id;
  }
}
