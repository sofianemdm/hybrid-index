import { ProfileScoringService } from "../src/modules/profile/profile-scoring.service";
import type { PrismaService } from "../src/infra/prisma/prisma.service";
import type { ScoreClient } from "../src/infra/score-client/score-client.service";
import type { RedisService } from "../src/infra/redis/redis.service";
import type { FeedEventsService } from "../src/modules/social/feed-events.service";
import type { PushService } from "../src/modules/engagement/push.service";

/**
 * Lever #1 (cahier §4.3) — flag d'AUTO-DÉPASSEMENT renvoyé à l'auteur d'un résultat.
 * `detectOvertake` est la logique qui alimente `PersistedProfile.overtook` (célébration
 * « Tu as doublé X ! » côté UI). On la teste isolément avec un Prisma simulé.
 */
type Detect = (
  userId: string,
  sex: string,
  adjIndex: { value: number },
  previousLeaguePosition: number | null,
  newPosition: number,
) => Promise<{ count: number; topName: string } | null>;

/** Construit le service avec un Prisma simulé (seules hybridIndex.findFirst + profile.findUnique
 *  sont sollicitées par detectOvertake). */
function makeService(opts: {
  justBelow?: { userId: string } | null;
  displayName?: string | null;
}): { detect: Detect } {
  const prisma = {
    hybridIndex: {
      findFirst: async () => opts.justBelow ?? null,
    },
    profile: {
      findUnique: async () => (opts.displayName === undefined ? null : { displayName: opts.displayName }),
    },
  } as unknown as PrismaService;

  const svc = new ProfileScoringService(
    prisma,
    {} as unknown as ScoreClient,
    {} as unknown as RedisService,
    {} as unknown as FeedEventsService,
    {} as unknown as PushService,
  );
  const detect = (svc as unknown as { detectOvertake: Detect }).detectOvertake.bind(svc);
  return { detect };
}

describe("ProfileScoringService.detectOvertake — auto-dépassement (lever #1)", () => {
  it("a grimpé de la 5e à la 3e place ⇒ overtook { count: 2, topName }", async () => {
    const { detect } = makeService({ justBelow: { userId: "below" }, displayName: "Kevin" });
    const res = await detect("me", "male", { value: 700 }, 5, 3);
    expect(res).toEqual({ count: 2, topName: "Kevin" });
  });

  it("position inchangée ⇒ null (rien à célébrer)", async () => {
    const { detect } = makeService({ justBelow: { userId: "below" }, displayName: "Kevin" });
    expect(await detect("me", "male", { value: 700 }, 4, 4)).toBeNull();
  });

  it("a reculé (nouvelle position pire) ⇒ null", async () => {
    const { detect } = makeService({ justBelow: { userId: "below" }, displayName: "Kevin" });
    expect(await detect("me", "male", { value: 700 }, 3, 5)).toBeNull();
  });

  it("tout premier Index (pas d'ancienne position) ⇒ null", async () => {
    const { detect } = makeService({ justBelow: { userId: "below" }, displayName: "Kevin" });
    expect(await detect("me", "male", { value: 700 }, null, 1)).toBeNull();
  });

  it("aucun athlète en dessous (auteur dernier malgré la montée) ⇒ null", async () => {
    const { detect } = makeService({ justBelow: null });
    expect(await detect("me", "male", { value: 700 }, 3, 2)).toBeNull();
  });

  it("le voisin du dessous est l'auteur lui-même (cohérence) ⇒ null", async () => {
    const { detect } = makeService({ justBelow: { userId: "me" }, displayName: "Moi" });
    expect(await detect("me", "male", { value: 700 }, 3, 2)).toBeNull();
  });

  it("athlète doublé sans pseudo ⇒ null (on n'invente pas de nom)", async () => {
    const { detect } = makeService({ justBelow: { userId: "below" }, displayName: "   " });
    expect(await detect("me", "male", { value: 700 }, 5, 3)).toBeNull();
  });
});
