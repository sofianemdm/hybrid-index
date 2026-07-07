import { Injectable, type NestMiddleware } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { PrismaService } from "../infra/prisma/prisma.service";
import { clientIp } from "./client-ip";

/** Sous-ensemble de la requête HTTP (évite la dépendance aux types express). */
interface HttpReq {
  headers: Record<string, string | string[] | undefined>;
  ip?: string;
  method?: string;
  originalUrl?: string;
  url?: string;
}

/** Chemins ignorés : bruit sans valeur d'analyse (santé, préflights gérés à part). */
const IGNORED_PREFIXES = ["/health", "/favicon"];

/**
 * Journalise chaque requête API dans `visit_log` (panneau admin) : IP, chemin, user si Bearer.
 * STRICTEMENT best-effort et non bloquant : l'écriture part en fire-and-forget, toute erreur est
 * avalée — le tracking ne doit JAMAIS ajouter de latence ni faire échouer une requête.
 * Rétention bornée (90 j) par le cron de purge du module admin (RGPD).
 */
@Injectable()
export class VisitLogMiddleware implements NestMiddleware {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  use(req: HttpReq, _res: unknown, next: () => void): void {
    try {
      const method = (req.method ?? "GET").toUpperCase();
      const rawPath = (req.originalUrl ?? req.url ?? "").split("?")[0];
      if (method !== "OPTIONS" && rawPath && !IGNORED_PREFIXES.some((p) => rawPath.startsWith(p))) {
        const ua = req.headers["user-agent"];
        const userAgent = (Array.isArray(ua) ? ua[0] : ua)?.slice(0, 255) ?? null;
        void this.prisma.visitLog
          .create({
            data: {
              ip: clientIp(req),
              userId: this.userIdFromBearer(req),
              path: rawPath.slice(0, 300),
              method,
              userAgent,
            },
          })
          .catch(() => undefined); // best-effort : ne casse jamais la requête
      }
    } catch {
      // ignore — le tracking est cosmétique, la requête prime
    }
    next();
  }

  /** sub du Bearer si valide, sinon null (même approche que le rate-limit par user). */
  private userIdFromBearer(req: HttpReq): string | null {
    const h = req.headers.authorization;
    const header = Array.isArray(h) ? h[0] : h;
    if (!header?.startsWith("Bearer ")) return null;
    try {
      const payload = this.jwt.verify<{ sub?: string }>(header.slice(7));
      return payload.sub ?? null;
    } catch {
      return null;
    }
  }
}
