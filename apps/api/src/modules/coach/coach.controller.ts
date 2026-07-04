import { BadRequestException, Controller, Get, Param, Post, Query, UseGuards } from "@nestjs/common";
import { AttributeKey } from "@hybrid-index/contracts";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard, type AuthenticatedUser } from "../auth/jwt-auth.guard";
import type { Session } from "./sessions.data";
import { CoachService, type CoachResponse, type CompleteSessionResponse, type LibraryResponse } from "./coach.service";

@Controller("v1/coach")
@UseGuards(JwtAuthGuard)
export class CoachController {
  constructor(private readonly coach: CoachService) {}

  /** Séances ciblées + Index projeté pour un attribut (défaut : ton point faible). */
  @Get()
  recommend(
    @CurrentUser() user: AuthenticatedUser,
    @Query("attribute") attribute?: string,
  ): Promise<CoachResponse> {
    if (attribute !== undefined && !AttributeKey.safeParse(attribute).success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Attribut invalide." });
    }
    return this.coach.coach(user.userId, attribute);
  }

  /**
   * Bibliothèque COMPLÈTE en UNE requête (filtre « Tout » du mobile) : toutes les séances curées,
   * dédupliquées, filtrées selon le matériel du profil, triées stable (durée asc → nom). Évite les
   * 6 appels parallèles `library?attribute=…` (anti N+1). Doit être déclaré AVANT `:` libre /
   * `@Get("library")` n'a pas de conflit ici car la route est plus spécifique.
   */
  @Get("library/all")
  libraryAll(@CurrentUser() user: AuthenticatedUser): Promise<LibraryResponse> {
    return this.coach.libraryAll(user.userId);
  }

  /** Bibliothèque de séances pour un attribut, triée par poids (écran « Séances de [attribut] »). */
  @Get("library")
  library(
    @CurrentUser() user: AuthenticatedUser,
    @Query("attribute") attribute?: string,
  ): Promise<LibraryResponse> {
    const parsed = AttributeKey.safeParse(attribute);
    if (!parsed.success) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Attribut invalide." });
    }
    return this.coach.library(user.userId, parsed.data);
  }

  /** Séance de la semaine (signature « Le Forgeron »). */
  @Get("weekly")
  weekly(): { session: Session } {
    return this.coach.weekly();
  }

  /**
   * Marque une séance guidée comme faite : persiste la complétion ET crédite la SÉRIE (sans créer
   * de wodResult ni toucher l'Athlete Index). Idempotent par jour. 404 si la séance n'existe pas.
   */
  @Post("sessions/:id/complete")
  complete(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
  ): Promise<CompleteSessionResponse> {
    return this.coach.completeSession(user.userId, id);
  }
}
