import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../infra/prisma/prisma.service";
import { ModerationService } from "../moderation/moderation.service";
import { PushService } from "../engagement/push.service";
import {
  parseMentions,
  buildDisplayNameIndex,
  resolveMentions,
  normalizeMention,
  type ResolvedMention,
} from "../../common/mentions.util";

/**
 * LOT 5 — Mentions @pseudo. Service partagé par PostsService et CommentsService :
 *  - `resolve()` : parse le corps, résout les @pseudo en utilisateurs réels (insensible casse/accents),
 *    EXCLUT l'auto-mention et les utilisateurs bloqués (sens ou l'autre). Renvoie de quoi rendre les
 *    @ cliquables côté client (pseudo canonique, userId, offset/length).
 *  - `notify()` : pousse un push « mention » best-effort à chaque mentionné (dédupliqué en amont).
 */
@Injectable()
export class MentionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly moderation: ModerationService,
    private readonly push: PushService,
  ) {}

  /**
   * Résout les @pseudo d'un corps en mentions exploitables. `me` = auteur (exclu : pas d'auto-mention).
   * Filtre les utilisateurs en blocage bidirectionnel avec `me`. Renvoie [] si aucun @ valide.
   */
  async resolve(me: string, body: string | null | undefined): Promise<ResolvedMention[]> {
    const raw = parseMentions(body);
    if (raw.length === 0) return [];

    // Profils candidats : on requête par displayName insensible casse via `in` sur les variantes
    // brutes (puis on affine par normalisation accents en mémoire). Borne raisonnable de tokens.
    const candidates = raw.slice(0, 20).map((r) => r.raw);
    const profiles = await this.prisma.profile.findMany({
      where: { displayName: { in: candidates, mode: "insensitive" }, user: { is: { status: "active" } } },
      select: { userId: true, displayName: true },
    });
    // Repli : si une casse/accent diffère, on retente une résolution large par normalisation.
    let pool = profiles;
    const index = buildDisplayNameIndex(pool);
    const unresolved = raw.filter((r) => !index.has(normalizeMention(r.raw)));
    if (unresolved.length > 0) {
      // Recherche élargie insensible aux accents : on charge les profils dont le displayName
      // normalisé correspond. Comme Postgres ne normalise pas les accents nativement ici, on borne
      // par un `contains` insensible sur chaque token restant (peu de tokens → coût maîtrisé).
      const extra = await this.prisma.profile.findMany({
        where: {
          OR: unresolved.map((r) => ({ displayName: { contains: r.raw, mode: "insensitive" as const } })),
          user: { is: { status: "active" } },
        },
        select: { userId: true, displayName: true },
        take: 50,
      });
      pool = [...pool, ...extra];
    }

    const fullIndex = buildDisplayNameIndex(pool);
    const resolved = resolveMentions(raw, fullIndex);

    // Exclut l'auto-mention.
    const notMe = resolved.filter((m) => m.userId !== me);
    if (notMe.length === 0) return [];

    // Exclut les utilisateurs en blocage bidirectionnel avec `me`.
    const blocked = new Set(await this.moderation.blockedIds(me));
    return notMe.filter((m) => !blocked.has(m.userId));
  }

  /**
   * Résolution LECTURE (feed / listing) : pour un lot de corps, renvoie une map id→mentions résolues,
   * en UNE seule requête profils (pas de N+1, pas de filtre de blocage — purement cosmétique pour
   * rendre les @ cliquables). Tokens dé-doublonnés et bornés.
   */
  async resolveBatch(items: Array<{ id: string; body: string | null | undefined }>): Promise<Map<string, ResolvedMention[]>> {
    const out = new Map<string, ResolvedMention[]>();
    const perItem = items.map((it) => ({ id: it.id, raw: parseMentions(it.body) }));
    const allRaw = perItem.flatMap((x) => x.raw.map((r) => r.raw));
    if (allRaw.length === 0) {
      for (const it of items) out.set(it.id, []);
      return out;
    }
    const candidates = [...new Set(allRaw)].slice(0, 100);
    const profiles = await this.prisma.profile.findMany({
      where: {
        OR: candidates.map((c) => ({ displayName: { contains: c, mode: "insensitive" as const } })),
        user: { is: { status: "active" } },
      },
      select: { userId: true, displayName: true },
      take: 200,
    });
    const index = buildDisplayNameIndex(profiles);
    for (const x of perItem) out.set(x.id, resolveMentions(x.raw, index));
    return out;
  }

  /** Push « mention » best-effort (jamais bloquant) à chaque utilisateur mentionné. `authorName` = pseudo de l'auteur. */
  async notify(mentions: ResolvedMention[], authorName: string): Promise<void> {
    await Promise.all(
      mentions.map((m) =>
        this.push.notifyMention(m.userId, authorName).catch(() => undefined),
      ),
    );
  }
}
