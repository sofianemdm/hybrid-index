-- CreateEnum
CREATE TYPE "app"."FeedEventType" AS ENUM ('pr', 'wod_logged', 'rank_up', 'badge_unlocked', 'challenge_created', 'challenge_resolved');

-- CreateTable
CREATE TABLE "app"."feed_event" (
    "id" UUID NOT NULL,
    "actor_id" UUID NOT NULL,
    "type" "app"."FeedEventType" NOT NULL,
    "payload" JSONB NOT NULL,
    "visibility" "app"."Visibility" NOT NULL DEFAULT 'public',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "feed_event_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."reaction" (
    "id" UUID NOT NULL,
    "from_user_id" UUID NOT NULL,
    "feed_event_id" UUID NOT NULL,
    "emoji" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reaction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "feed_event_actor_id_created_at_idx" ON "app"."feed_event"("actor_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "reaction_feed_event_id_idx" ON "app"."reaction"("feed_event_id");

-- CreateIndex
CREATE UNIQUE INDEX "reaction_from_user_id_feed_event_id_emoji_key" ON "app"."reaction"("from_user_id", "feed_event_id", "emoji");

-- AddForeignKey
ALTER TABLE "app"."feed_event" ADD CONSTRAINT "feed_event_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."reaction" ADD CONSTRAINT "reaction_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."reaction" ADD CONSTRAINT "reaction_feed_event_id_fkey" FOREIGN KEY ("feed_event_id") REFERENCES "app"."feed_event"("id") ON DELETE CASCADE ON UPDATE CASCADE;
