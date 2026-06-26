import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import type { CreateFeedbackRequest } from "./feedback.dto";

@Injectable()
export class FeedbackService {
  constructor(private readonly prisma: PrismaService) {}

  /** Persiste un signalement de bug pour consultation par le dev. */
  async create(userId: string, dto: CreateFeedbackRequest): Promise<{ ok: true; id: string }> {
    const feedback = await this.prisma.feedback.create({
      data: {
        userId,
        message: dto.message,
        context: dto.context ?? null,
      },
      select: { id: true },
    });
    return { ok: true, id: feedback.id };
  }
}
