import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import type { ReportReason, ReportTargetType } from "@prisma/client";
import { PrismaService } from "../../infra/prisma/prisma.service";

/** Liste minimale de termes interdits pour la modération de noms (clubs, etc.). À enrichir. */
const BANNED_WORDS = ["fuck", "shit", "salope", "connard", "nigger", "pute", "bitch", "nazi"];

/** Seuil d'auto-masquage : un post signalé par ce nombre de rapporteurs DISTINCTS passe en `hidden`. */
const AUTOHIDE_REPORTS = 3;

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
    // Auto-masquage : compte les rapporteurs DISTINCTS (l'upsert garantit l'unicité par rapporteur
    // via @@unique). Au seuil atteint, l'élément est masqué et quitte tous les feeds.
    if (body.targetType === "post") await this.maybeAutoHidePost(body.targetId);
    if (body.targetType === "comment") await this.maybeAutoHideComment(body.targetId);
    return { reported: true };
  }

  /** Recompte les signalements distincts d'un post et le masque (status=hidden) si le seuil est atteint. */
  private async maybeAutoHidePost(postId: string): Promise<void> {
    const count = await this.prisma.report.count({ where: { targetType: "post", targetId: postId } });
    await this.prisma.post
      .update({ where: { id: postId }, data: { reportCount: count, ...(count >= AUTOHIDE_REPORTS ? { status: "hidden" } : {}) } })
      .catch(() => undefined); // post supprimé entre-temps : best-effort, on ignore.
  }

  /** Recompte les signalements distincts d'un commentaire et le masque (hidden=true) au seuil. */
  private async maybeAutoHideComment(commentId: string): Promise<void> {
    const count = await this.prisma.report.count({ where: { targetType: "comment", targetId: commentId } });
    await this.prisma.comment
      .update({ where: { id: commentId }, data: { reportCount: count, ...(count >= AUTOHIDE_REPORTS ? { hidden: true } : {}) } })
      .catch(() => undefined); // commentaire supprimé entre-temps : best-effort, on ignore.
  }

  /** Ids des posts que `me` a signalés — masqués immédiatement de SON feed dès le signalement. */
  async reportedPostIds(me: string): Promise<string[]> {
    const rows = await this.prisma.report.findMany({
      where: { reporterId: me, targetType: "post" },
      select: { targetId: true },
    });
    return rows.map((r) => r.targetId);
  }

  /** Filtre lexical synchrone des noms (clubs/pseudos). */
  isCleanName(name: string): boolean {
    const lower = name.toLowerCase();
    return !BANNED_WORDS.some((w) => lower.includes(w));
  }
}
