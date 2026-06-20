import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { addWeeks, isoWeekKey, isoWeekKeyToMonday, weekStart } from "./iso-week";

export interface StreakState {
  current: number;
  best: number;
  weeklyGoal: number;
  freezeTokens: number;
  thisWeekCount: number;
  weekValidated: boolean;
}

const MAX_CATCHUP_WEEKS = 12;

/**
 * Streak hebdomadaire (spec gamification 20 juin) : une semaine est validée si ≥ weeklyGoal
 * WODs loggés (ou repos planifié). Jetons de gel : protègent une semaine ratée (pas deux de
 * suite). Régénération +1 token toutes les 4 semaines actives validées. Évaluation paresseuse
 * au log / à la consultation. Tout en UTC (le fuseau par utilisateur viendra plus tard).
 */
@Injectable()
export class StreakService {
  constructor(private readonly prisma: PrismaService) {}

  /** Réglages de la série : objectif hebdo (2–5) et/ou repos planifié de la semaine en cours. */
  async updateSettings(
    userId: string,
    opts: { weeklyGoal?: number; plannedRest?: boolean },
  ): Promise<StreakState> {
    await this.evaluateAndGet(userId); // garantit l'existence de la ligne + évalue le passé
    const data: { weeklyGoal?: number; plannedRest?: boolean } = {};
    if (opts.weeklyGoal !== undefined) data.weeklyGoal = Math.min(5, Math.max(2, opts.weeklyGoal));
    if (opts.plannedRest !== undefined) data.plannedRest = opts.plannedRest;
    await this.prisma.streak.update({ where: { userId }, data });
    return this.evaluateAndGet(userId);
  }

  private async wodCountInWeek(userId: string, monday: Date): Promise<number> {
    return this.prisma.wodResult.count({
      where: { userId, performedAt: { gte: monday, lt: addWeeks(monday, 1) } },
    });
  }

  /** Évalue les semaines écoulées puis renvoie l'état courant. Idempotent. */
  async evaluateAndGet(userId: string, now: Date = new Date()): Promise<StreakState> {
    const currentMonday = weekStart(now);

    let streak = await this.prisma.streak.findUnique({ where: { userId } });
    if (!streak) {
      // Init : on ne pénalise pas les semaines antérieures à l'inscription.
      streak = await this.prisma.streak.create({
        data: { userId, lastWeekEvaluated: isoWeekKey(addWeeks(currentMonday, -1)) },
      });
    }

    let { current, best, freezeTokens, validatedActiveWeeks } = streak;
    let lastOutcome = streak.lastOutcome;
    const weeklyGoal = streak.weeklyGoal;

    // Point de départ : la semaine suivant la dernière évaluée.
    let pointer = streak.lastWeekEvaluated
      ? addWeeks(isoWeekKeyToMonday(streak.lastWeekEvaluated), 1)
      : addWeeks(currentMonday, -1);

    // Trop en retard (longue inactivité) : on remet la série à zéro sans boucler.
    const weeksBehind = Math.round((currentMonday.getTime() - pointer.getTime()) / (7 * 86_400_000));
    if (weeksBehind > MAX_CATCHUP_WEEKS) {
      current = 0;
      validatedActiveWeeks = 0;
      lastOutcome = "broken";
      pointer = addWeeks(currentMonday, -1);
    }

    let plannedRest = streak.plannedRest;
    while (pointer.getTime() < currentMonday.getTime()) {
      const count = await this.wodCountInWeek(userId, pointer);
      let outcome: string;
      if (plannedRest) {
        current += 1;
        outcome = "rest";
      } else if (count >= weeklyGoal) {
        current += 1;
        validatedActiveWeeks += 1;
        outcome = "validated";
      } else if (freezeTokens >= 1 && lastOutcome !== "frozen") {
        freezeTokens -= 1;
        outcome = "frozen";
      } else {
        current = 0;
        validatedActiveWeeks = 0;
        outcome = "broken";
      }
      if (current > best) best = current;
      if (outcome === "validated" && validatedActiveWeeks % 4 === 0 && freezeTokens < 2) {
        freezeTokens += 1;
      }
      lastOutcome = outcome;
      plannedRest = false; // consommé
      pointer = addWeeks(pointer, 1);
    }

    const persisted = await this.prisma.streak.update({
      where: { userId },
      data: {
        current,
        best,
        freezeTokens,
        validatedActiveWeeks,
        lastOutcome,
        plannedRest,
        lastWeekEvaluated: isoWeekKey(addWeeks(currentMonday, -1)),
      },
    });

    const thisWeekCount = await this.wodCountInWeek(userId, currentMonday);
    return {
      current: persisted.current,
      best: persisted.best,
      weeklyGoal: persisted.weeklyGoal,
      freezeTokens: persisted.freezeTokens,
      thisWeekCount,
      weekValidated: thisWeekCount >= persisted.weeklyGoal,
    };
  }
}
