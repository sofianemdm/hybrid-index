import { Controller, Get, Param, ParseIntPipe, Query, UseGuards } from "@nestjs/common";
import { AdminGuard } from "./admin.guard";
import { AdminService } from "./admin.service";

/** Panneau d'administration (page web /admin) — lecture seule, réservé aux emails ADMIN_EMAILS. */
@Controller("v1/admin")
@UseGuards(AdminGuard)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  /** KPIs globaux : users, visites, séances, posts, clubs, push, feedbacks. */
  @Get("overview")
  overview(): Promise<Record<string, unknown>> {
    return this.admin.overview();
  }

  /** Séries par jour (défaut 30, max 90) : inscriptions, visiteurs, hits, séances, posts. */
  @Get("timeseries")
  timeseries(@Query("days", new ParseIntPipe({ optional: true })) days?: number): Promise<Record<string, unknown>> {
    return this.admin.timeseries(days ?? 30);
  }

  /** Visiteurs uniques par IP (nb visites, 1re/dernière visite, dernier user) sur N jours (défaut : aujourd'hui). */
  @Get("visitors")
  visitors(
    @Query("days", new ParseIntPipe({ optional: true })) days?: number,
    @Query("limit", new ParseIntPipe({ optional: true })) limit?: number,
  ): Promise<Record<string, unknown>> {
    return this.admin.visitors(days ?? 1, limit ?? 100);
  }

  /** Journal des visites (IP, page, user), paginé, filtrable par ip/userId. */
  @Get("visits")
  visits(
    @Query("limit", new ParseIntPipe({ optional: true })) limit?: number,
    @Query("cursor") cursor?: string,
    @Query("ip") ip?: string,
    @Query("userId") userId?: string,
  ): Promise<Record<string, unknown>> {
    return this.admin.visits({ limit: limit ?? 50, cursor, ip, userId });
  }

  /** Liste des comptes (récents d'abord), recherche par email/pseudo. */
  @Get("users")
  users(
    @Query("limit", new ParseIntPipe({ optional: true })) limit?: number,
    @Query("cursor") cursor?: string,
    @Query("q") q?: string,
  ): Promise<Record<string, unknown>> {
    return this.admin.users({ limit: limit ?? 50, cursor, q });
  }

  /** Fiche détaillée d'un compte. */
  @Get("users/:id")
  userDetail(@Param("id") id: string): Promise<Record<string, unknown>> {
    return this.admin.userDetail(id);
  }

  /** Feedbacks / bugs signalés. */
  @Get("feedbacks")
  feedbacks(@Query("limit", new ParseIntPipe({ optional: true })) limit?: number): Promise<Record<string, unknown>> {
    return this.admin.feedbacks(limit ?? 100);
  }
}
