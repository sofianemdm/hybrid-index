import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { FeedEventsService } from "../social/feed-events.service";

const WEEK_DAYS = 7;

@Injectable()
export class ChallengesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly feedEvents: FeedEventsService,
  ) {}

  /**
   * Meilleur effort d'un athlète sur un WOD, dans une variante donnée.
   * DW4 : Rx et Scaled ne se comparent jamais entre eux → on filtre sur `rxCompliant`.
   */
  private async myBest(userId: string, wodId: string, rxCompliant: boolean): Promise<number | null> {
    const agg = await this.prisma.wodResult.aggregate({
      where: { userId, wodId, rxCompliant, review: "ok", subScore: { not: null } },
      _max: { subScore: true },
    });
    return agg._max.subScore;
  }

  private isExpired(expiresAt: Date | null): boolean {
    return expiresAt !== null && expiresAt.getTime() < Date.now();
  }

  /** Crée un défi sur un WOD : la référence du créateur (son meilleur effort) est gelée. */
  async create(
    me: string,
    body: { wodId: string; toUserId?: string; expiresInDays?: number; rxCompliant?: boolean },
  ): Promise<unknown> {
    const wod = await this.prisma.wod.findUnique({ where: { id: body.wodId }, select: { id: true, name: true } });
    if (!wod) throw new NotFoundException({ code: "NOT_FOUND", message: "WOD introuvable." });
    if (body.toUserId === me) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "On ne se défie pas soi-même." });
    }
    const rxCompliant = body.rxCompliant ?? true;
    const target = await this.myBest(me, body.wodId, rxCompliant);
    if (target === null) {
      throw new BadRequestException({
        code: "VALIDATION_ERROR",
        message: `Fais d'abord ce WOD en ${rxCompliant ? "Rx" : "Scaled"} pour défier dessus.`,
      });
    }
    const days = body.expiresInDays ?? WEEK_DAYS;
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    const challenge = await this.prisma.challenge.create({
      data: {
        fromUserId: me,
        toUserId: body.toUserId ?? null,
        wodId: body.wodId,
        targetSubScore: target,
        rxCompliant,
        expiresAt,
      },
    });
    await this.feedEvents.emit(me, "challenge_created", { challengeId: challenge.id, wodId: wod.id, wodName: wod.name });
    return this.toView(challenge.id, me);
  }

  async list(me: string): Promise<unknown[]> {
    const rows = await this.prisma.challenge.findMany({
      where: { OR: [{ fromUserId: me }, { toUserId: me }] },
      orderBy: { createdAt: "desc" },
      include: {
        wod: { select: { name: true, scoreType: true } },
        fromUser: { select: { profile: { select: { displayName: true } } } },
        toUser: { select: { profile: { select: { displayName: true } } } },
      },
    });
    return rows.map((c) => ({
      id: c.id,
      wodId: c.wodId,
      wodName: c.wod.name,
      // Un défi périmé non terminé est présenté comme `expired` même si la colonne n'a pas encore basculé.
      status: this.isExpired(c.expiresAt) && (c.status === "pending" || c.status === "accepted") ? "expired" : c.status,
      targetSubScore: c.targetSubScore,
      variant: c.rxCompliant ? "rx" : "scaled",
      fromName: c.fromUser.profile?.displayName ?? "—",
      toName: c.toUser?.profile?.displayName ?? "Ouvert",
      iAmCreator: c.fromUserId === me,
      iAmChallenged: c.toUserId === me,
      expiresAt: c.expiresAt?.toISOString() ?? null,
    }));
  }

  /** Accepter un défi : seul le challengé (ou n'importe qui pour un défi ouvert) peut le faire. */
  async accept(me: string, id: string): Promise<unknown> {
    const c = await this.prisma.challenge.findUnique({ where: { id } });
    if (!c) throw new NotFoundException({ code: "NOT_FOUND", message: "Défi introuvable." });
    if (c.fromUserId === me) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Tu ne peux pas accepter ton propre défi." });
    }
    if (c.toUserId && c.toUserId !== me) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Pas ton défi." });
    }
    if (c.status !== "pending") {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Défi déjà traité." });
    }
    if (this.isExpired(c.expiresAt)) {
      await this.prisma.challenge.update({ where: { id }, data: { status: "expired" } });
      throw new BadRequestException({ code: "CHALLENGE_EXPIRED", message: "Ce défi a expiré." });
    }
    await this.prisma.challenge.update({
      where: { id },
      data: { status: "accepted", toUserId: c.toUserId ?? me },
    });
    return this.toView(id, me);
  }

  async decline(me: string, id: string): Promise<unknown> {
    const c = await this.prisma.challenge.findUnique({ where: { id } });
    if (!c) throw new NotFoundException({ code: "NOT_FOUND", message: "Défi introuvable." });
    if (c.toUserId !== me) throw new ForbiddenException({ code: "FORBIDDEN", message: "Pas ton défi." });
    if (c.status !== "pending" && c.status !== "accepted") {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Défi déjà clôturé." });
    }
    await this.prisma.challenge.update({ where: { id }, data: { status: "declined" } });
    return this.toView(id, me);
  }

  /**
   * Résolution : seul le challengé compare SON meilleur effort au score-cible gelé du créateur.
   * Le créateur ne résout jamais (sinon il « gagnerait » son propre défi).
   */
  async resolve(me: string, id: string): Promise<unknown> {
    const c = await this.prisma.challenge.findUnique({ where: { id }, include: { wod: { select: { name: true } } } });
    if (!c) throw new NotFoundException({ code: "NOT_FOUND", message: "Défi introuvable." });
    if (c.toUserId === null) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Défi pas encore accepté." });
    }
    if (c.toUserId !== me) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Seul le challengé peut vérifier ce défi." });
    }
    if (c.status === "completed" || c.status === "declined" || c.status === "expired") {
      return { id, beaten: c.status === "completed", best: null, target: c.targetSubScore, status: c.status };
    }
    if (this.isExpired(c.expiresAt)) {
      await this.prisma.challenge.update({ where: { id }, data: { status: "expired" } });
      return { id, beaten: false, best: null, target: c.targetSubScore, status: "expired" };
    }
    const best = await this.myBest(me, c.wodId, c.rxCompliant);
    const beaten = best !== null && c.targetSubScore !== null && best > c.targetSubScore;
    if (beaten) {
      await this.prisma.challenge.update({ where: { id }, data: { status: "completed", resolvedAt: new Date() } });
      await this.feedEvents.emit(me, "challenge_resolved", {
        challengeId: id,
        wodName: c.wod.name,
        beaten: true,
      });
    }
    return { id, beaten, best, target: c.targetSubScore, status: beaten ? "completed" : c.status };
  }

  private async toView(id: string, me: string): Promise<unknown> {
    const list = (await this.list(me)) as Array<{ id: string }>;
    return list.find((c) => c.id === id) ?? { id };
  }
}
