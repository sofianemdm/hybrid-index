import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { ratingFromInternal } from "@hybrid-index/scoring-core";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";

/**
 * Clubs (Phase C). Le club n'est PAS une ligue : c'est un groupe (roster) + un point d'entrée
 * pour filtrer les classements (clubId). Création libre, adhésion libre (sans validation admin).
 */
@Injectable()
export class ClubsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly moderation: ModerationService,
  ) {}

  private baseSlug(name: string): string {
    return name
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 32) || "club";
  }

  private async uniqueSlug(name: string): Promise<string> {
    const base = this.baseSlug(name);
    for (let i = 0; i < 50; i++) {
      const slug = i === 0 ? base : `${base}-${i + 1}`;
      const taken = await this.prisma.club.findUnique({ where: { slug }, select: { id: true } });
      if (!taken) return slug;
    }
    return `${base}-${Date.now()}`;
  }

  async create(me: string, body: { name: string; description?: string }): Promise<unknown> {
    const name = body.name.trim();
    if (name.length < 3) throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Nom de club trop court (min 3)." });
    if (!this.moderation.isCleanName(name)) {
      throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Nom de club non autorisé.", details: { field: "name" } });
    }
    const slug = await this.uniqueSlug(name);
    const club = await this.prisma.club.create({
      data: {
        name,
        slug,
        description: body.description?.trim() || null,
        ownerId: me,
        memberCount: 1,
        members: { create: { userId: me, role: "owner" } },
      },
    });
    return this.detail(club.id, me);
  }

  async join(me: string, clubId: string): Promise<unknown> {
    const club = await this.prisma.club.findUnique({ where: { id: clubId } });
    if (!club || club.status !== "visible") throw new NotFoundException({ code: "NOT_FOUND", message: "Club introuvable." });
    const existing = await this.prisma.clubMember.findUnique({ where: { clubId_userId: { clubId, userId: me } } });
    if (!existing) {
      await this.prisma.$transaction([
        this.prisma.clubMember.create({ data: { clubId, userId: me, role: "member" } }),
        this.prisma.club.update({ where: { id: clubId }, data: { memberCount: { increment: 1 } } }),
        this.prisma.clubInvite.updateMany({ where: { clubId, inviteeId: me, status: "pending" }, data: { status: "accepted", respondedAt: new Date() } }),
      ]);
    }
    return this.detail(clubId, me);
  }

  async leave(me: string, clubId: string): Promise<{ left: true }> {
    const m = await this.prisma.clubMember.findUnique({ where: { clubId_userId: { clubId, userId: me } } });
    if (!m) return { left: true };
    const count = await this.prisma.clubMember.count({ where: { clubId } });
    if (m.role === "owner" && count > 1) {
      throw new ForbiddenException({ code: "FORBIDDEN", message: "Transfère ou supprime le club avant de le quitter (tu en es le créateur)." });
    }
    if (count <= 1) {
      await this.prisma.club.delete({ where: { id: clubId } }); // dernier membre → le club disparaît
    } else {
      await this.prisma.$transaction([
        this.prisma.clubMember.delete({ where: { clubId_userId: { clubId, userId: me } } }),
        this.prisma.club.update({ where: { id: clubId }, data: { memberCount: { decrement: 1 } } }),
      ]);
    }
    return { left: true };
  }

  async myClubs(me: string): Promise<unknown[]> {
    const rows = await this.prisma.clubMember.findMany({
      where: { userId: me },
      include: { club: true },
      orderBy: { joinedAt: "desc" },
    });
    return rows
      .filter((r) => r.club.status === "visible")
      .map((r) => ({ id: r.club.id, name: r.club.name, memberCount: r.club.memberCount, role: r.role }));
  }

  async search(q: string | undefined): Promise<unknown[]> {
    const clubs = await this.prisma.club.findMany({
      where: { status: "visible", ...(q ? { name: { contains: q.slice(0, 40), mode: "insensitive" } } : {}) },
      orderBy: { memberCount: "desc" },
      take: 50,
    });
    return clubs.map((c) => ({ id: c.id, name: c.name, description: c.description, memberCount: c.memberCount }));
  }

  /** Détail + roster (membres classés par Index décroissant = classement interne du club). */
  async detail(clubId: string, me?: string): Promise<unknown> {
    const club = await this.prisma.club.findUnique({ where: { id: clubId } });
    if (!club || club.status !== "visible") throw new NotFoundException({ code: "NOT_FOUND", message: "Club introuvable." });
    const members = await this.prisma.clubMember.findMany({
      where: { clubId },
      include: {
        user: { include: { profile: { select: { displayName: true, rank: true } }, hybridIndex: { select: { value: true } } } },
      },
    });
    const roster = members
      .map((m) => ({
        userId: m.userId,
        displayName: m.user.profile?.displayName ?? "—",
        rank: m.user.profile?.rank ?? "rookie",
        index: m.user.hybridIndex ? Math.round(ratingFromInternal(m.user.hybridIndex.value)) : 0, // OVR /100 (valeur déjà ajustée par couverture)
        role: m.role,
        isMe: m.userId === me,
      }))
      .sort((a, b) => b.index - a.index)
      .map((r, i) => ({ ...r, position: i + 1 }));
    const isMember = me ? members.some((m) => m.userId === me) : false;
    // `memberCount` dénormalisé peut DÉRIVER (ex. un membre dont le compte a été supprimé : sa ligne
    // ClubMember part en cascade mais le compteur n'est pas décrémenté). Le roster est la SOURCE DE
    // VÉRITÉ → on renvoie sa taille, et on auto-répare le compteur stocké s'il diverge (fix « 3 vs 2 »).
    const actualCount = members.length;
    if (club.memberCount !== actualCount) {
      await this.prisma.club.update({ where: { id: clubId }, data: { memberCount: actualCount } }).catch(() => undefined);
    }
    return {
      id: club.id,
      name: club.name,
      description: club.description,
      memberCount: actualCount,
      isMember,
      isOwner: me === club.ownerId,
      roster,
    };
  }

  async invite(me: string, clubId: string, inviteeId: string): Promise<{ invited: true }> {
    const member = await this.prisma.clubMember.findUnique({ where: { clubId_userId: { clubId, userId: me } } });
    if (!member) throw new ForbiddenException({ code: "FORBIDDEN", message: "Rejoins le club pour inviter." });
    if (inviteeId === me) throw new BadRequestException({ code: "VALIDATION_ERROR", message: "Tu es déjà membre." });
    // On ne peut pas inviter quelqu'un qui est DÉJÀ membre du club.
    const alreadyMember = await this.prisma.clubMember.findUnique({
      where: { clubId_userId: { clubId, userId: inviteeId } },
      select: { userId: true },
    });
    if (alreadyMember) {
      throw new BadRequestException({ code: "ALREADY_MEMBER", message: "Cette personne est déjà membre du club." });
    }
    await this.prisma.clubInvite.upsert({
      where: { clubId_inviteeId: { clubId, inviteeId } },
      create: { clubId, inviterId: me, inviteeId, status: "pending" },
      update: { inviterId: me, status: "pending", respondedAt: null },
    });
    return { invited: true };
  }

  async myInvites(me: string): Promise<unknown[]> {
    const rows = await this.prisma.clubInvite.findMany({
      where: { inviteeId: me, status: "pending" },
      include: { club: { select: { id: true, name: true, memberCount: true } } },
      orderBy: { createdAt: "desc" },
    });
    return rows.map((r) => ({ inviteId: r.id, clubId: r.club.id, clubName: r.club.name, memberCount: r.club.memberCount }));
  }

  async declineInvite(me: string, inviteId: string): Promise<{ declined: true }> {
    await this.prisma.clubInvite.updateMany({
      where: { id: inviteId, inviteeId: me },
      data: { status: "declined", respondedAt: new Date() },
    });
    return { declined: true };
  }

  /** Ids des membres d'un club (pour filtrer les classements). Vérifie l'appartenance du caller. */
  async memberIds(clubId: string, me: string): Promise<string[]> {
    const meMember = await this.prisma.clubMember.findUnique({ where: { clubId_userId: { clubId, userId: me } } });
    if (!meMember) throw new ForbiddenException({ code: "FORBIDDEN", message: "Tu n'es pas membre de ce club." });
    const members = await this.prisma.clubMember.findMany({ where: { clubId }, select: { userId: true } });
    return members.map((m) => m.userId);
  }
}
