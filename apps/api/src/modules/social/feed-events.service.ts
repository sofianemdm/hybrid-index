import { Injectable, Logger } from "@nestjs/common";
import { Prisma, type FeedEventType } from "@prisma/client";
import { PrismaService } from "../../infra/prisma/prisma.service";

/** Émission d'événements de feed (best-effort : un échec ne casse jamais l'action source). */
@Injectable()
export class FeedEventsService {
  private readonly logger = new Logger(FeedEventsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async emit(actorId: string, type: FeedEventType, payload: Record<string, unknown>): Promise<void> {
    try {
      await this.prisma.feedEvent.create({ data: { actorId, type, payload: payload as Prisma.InputJsonValue } });
    } catch (e) {
      this.logger.warn(`FeedEvent ${type} non émis (${actorId}) : ${e}`);
    }
  }
}
