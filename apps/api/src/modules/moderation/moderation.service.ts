import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import type { ReportReason, ReportTargetType } from "@prisma/client";
import { PrismaService } from "../../infra/prisma/prisma.service";

/** Liste minimale de termes interdits pour la modération de noms (clubs, etc.). À enrichir. */
const BANNED_WORDS = ["fuck", "shit", "salope", "connard", "nigger", "pute", "bitch", "nazi"];

/** Sécurité transverse (Phase C) : blocage entre utilisateurs + signalement générique + filtre de noms. */
@Injectable()
export class ModerationService {
  constructor(private readonly prisma: PrismaService) {}

  async block(me: string, otherId: string): Promise<{ blocked: true }> {
    if (me === otherId) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "On ne se bloque pas soi-même." });
    }
    const exists = await this.prisma.user.findUnique({ where: { id: otherId }, select: { id: true } });
    if (!exists) throw new NotFoundException({ code: "NOT_FOUND", message: "Utilisateur introuvable." });
    await this.prisma.block.upsert({
      where: { blockerId_blockedId: { blockerId: me, blockedId: otherId } },
      create: { blockerId: me, blockedId: otherId },
      update: {},
    });
    return { blocked: true };
  }

  async unblock(me: string, otherId: string): Promise<{ blocked: false }> {
    await this.prisma.block.deleteMany({ where: { blockerId: me, blockedId: otherId } });
    return { blocked: false };
  }

  /** Vrai si l'un bloque l'autre (dans un sens ou l'autre). */
  async isBlockedBetween(a: string, b: string): Promise<boolean> {
    const c = await this.prisma.block.count({
      where: { OR: [{ blockerId: a, blockedId: b }, { blockerId: b, blockedId: a }] },
    });
    return c > 0;
  }

  /** Ids bloqués (dans les deux sens) pour exclure d'un feed/liste. */
  async blockedIds(me: string): Promise<string[]> {
    const rows = await this.prisma.block.findMany({
      where: { OR: [{ blockerId: me }, { blockedId: me }] },
      select: { blockerId: true, blockedId: true },
    });
    const ids = new Set<string>();
    for (const r of rows) ids.add(r.blockerId === me ? r.blockedId : r.blockerId);
    return [...ids];
  }

  async report(
    reporterId: string,
    body: { targetType: ReportTargetType; targetId: string; reason: ReportReason; note?: string },
  ): Promise<{ reported: true }> {
    await this.prisma.report.upsert({
      where: { reporterId_targetType_targetId: { reporterId, targetType: body.targetType, targetId: body.targetId } },
      create: { reporterId, targetType: body.targetType, targetId: body.targetId, reason: body.reason, note: body.note },
      update: { reason: body.reason, note: body.note },
    });
    return { reported: true };
  }

  /** Filtre lexical synchrone des noms (clubs/pseudos). */
  isCleanName(name: string): boolean {
    const lower = name.toLowerCase();
    return !BANNED_WORDS.some((w) => lower.includes(w));
  }
}
