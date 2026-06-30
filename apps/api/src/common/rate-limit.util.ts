import { HttpException, HttpStatus } from "@nestjs/common";
import type { RedisService } from "../infra/redis/redis.service";

/**
 * Garde-fou applicatif anti-spam (par utilisateur, fenêtre glissante via RedisService). Distinct
 * du `RateLimitGuard` HTTP (par IP, désactivé en tests) : celui-ci s'applique DANS le service, est
 * unit-testable et compte par identité métier (userId). Fail-open : si Redis est indisponible
 * (`rateLimit` renvoie null) on N'BLOQUE PAS un utilisateur légitime sur une panne d'infra.
 *
 * @param redis      service Redis (compteur de fenêtre)
 * @param action     préfixe de clé (ex. "post:create") — sépare les quotas par type d'action
 * @param userId     identité métier limitée
 * @param limit      nombre d'actions autorisées dans la fenêtre
 * @param windowSec  durée de la fenêtre, en secondes
 * @throws HttpException 429 (code RATE_LIMITED) si le quota est dépassé
 */
export async function enforceUserRateLimit(
  redis: RedisService,
  action: string,
  userId: string,
  limit: number,
  windowSec: number,
): Promise<void> {
  const count = await redis.rateLimit(`act:${action}:${userId}`, windowSec);
  if (count !== null && count > limit) {
    throw new HttpException(
      { code: "RATE_LIMITED", message: "Tu vas un peu vite. Réessaie dans quelques instants." },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }
}
