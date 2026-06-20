-- AlterEnum
BEGIN;
CREATE TYPE "app"."FeedEventType_new" AS ENUM ('pr', 'wod_logged', 'rank_up', 'badge_unlocked');
ALTER TABLE "app"."feed_event" ALTER COLUMN "type" TYPE "app"."FeedEventType_new" USING ("type"::text::"app"."FeedEventType_new");
ALTER TYPE "app"."FeedEventType" RENAME TO "FeedEventType_old";
ALTER TYPE "app"."FeedEventType_new" RENAME TO "FeedEventType";
DROP TYPE "app"."FeedEventType_old";
COMMIT;

-- DropForeignKey
ALTER TABLE "app"."challenge" DROP CONSTRAINT "challenge_from_user_id_fkey";

-- DropForeignKey
ALTER TABLE "app"."challenge" DROP CONSTRAINT "challenge_to_user_id_fkey";

-- DropForeignKey
ALTER TABLE "app"."challenge" DROP CONSTRAINT "challenge_wod_id_fkey";

-- DropForeignKey
ALTER TABLE "app"."rival" DROP CONSTRAINT "rival_rival_user_id_fkey";

-- DropForeignKey
ALTER TABLE "app"."rival" DROP CONSTRAINT "rival_user_id_fkey";

-- DropTable
DROP TABLE "app"."challenge";

-- DropTable
DROP TABLE "app"."rival";

-- DropEnum
DROP TYPE "app"."ChallengeStatus";
