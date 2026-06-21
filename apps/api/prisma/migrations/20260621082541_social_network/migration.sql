-- CreateEnum
CREATE TYPE "app"."PostKind" AS ENUM ('text', 'perf_share', 'photo');

-- CreateEnum
CREATE TYPE "app"."ModerationStatus" AS ENUM ('visible', 'hidden', 'removed');

-- CreateEnum
CREATE TYPE "app"."ClubRole" AS ENUM ('owner', 'member');

-- CreateEnum
CREATE TYPE "app"."ClubInviteStatus" AS ENUM ('pending', 'accepted', 'declined', 'revoked');

-- CreateEnum
CREATE TYPE "app"."ReportTargetType" AS ENUM ('post', 'message', 'club', 'user');

-- CreateEnum
CREATE TYPE "app"."ReportReason" AS ENUM ('spam', 'harassment', 'inappropriate', 'cheating', 'other');

-- CreateEnum
CREATE TYPE "app"."ReportStatus" AS ENUM ('open', 'reviewed', 'actioned', 'dismissed');

-- CreateTable
CREATE TABLE "app"."post" (
    "id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "kind" "app"."PostKind" NOT NULL,
    "body" VARCHAR(500),
    "wod_result_id" UUID,
    "photo_url" TEXT,
    "club_id" UUID,
    "status" "app"."ModerationStatus" NOT NULL DEFAULT 'visible',
    "visibility" "app"."Visibility" NOT NULL DEFAULT 'public',
    "reaction_count" INTEGER NOT NULL DEFAULT 0,
    "report_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "post_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."post_reaction" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "from_user_id" UUID NOT NULL,
    "emoji" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_reaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."club" (
    "id" UUID NOT NULL,
    "name" VARCHAR(40) NOT NULL,
    "slug" TEXT NOT NULL,
    "description" VARCHAR(280),
    "owner_id" UUID NOT NULL,
    "visibility" "app"."Visibility" NOT NULL DEFAULT 'public',
    "status" "app"."ModerationStatus" NOT NULL DEFAULT 'visible',
    "member_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "club_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."club_member" (
    "club_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "app"."ClubRole" NOT NULL DEFAULT 'member',
    "joined_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "club_member_pkey" PRIMARY KEY ("club_id","user_id")
);

-- CreateTable
CREATE TABLE "app"."club_invite" (
    "id" UUID NOT NULL,
    "club_id" UUID NOT NULL,
    "inviter_id" UUID NOT NULL,
    "invitee_id" UUID NOT NULL,
    "status" "app"."ClubInviteStatus" NOT NULL DEFAULT 'pending',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "responded_at" TIMESTAMPTZ(6),

    CONSTRAINT "club_invite_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."block" (
    "blocker_id" UUID NOT NULL,
    "blocked_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "block_pkey" PRIMARY KEY ("blocker_id","blocked_id")
);

-- CreateTable
CREATE TABLE "app"."conversation" (
    "id" UUID NOT NULL,
    "user_a_id" UUID NOT NULL,
    "user_b_id" UUID NOT NULL,
    "last_message_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "conversation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."message" (
    "id" UUID NOT NULL,
    "conversation_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "body" VARCHAR(2000) NOT NULL,
    "status" "app"."ModerationStatus" NOT NULL DEFAULT 'visible',
    "read_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "message_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."report" (
    "id" UUID NOT NULL,
    "reporter_id" UUID NOT NULL,
    "target_type" "app"."ReportTargetType" NOT NULL,
    "target_id" UUID NOT NULL,
    "reason" "app"."ReportReason" NOT NULL,
    "note" VARCHAR(500),
    "status" "app"."ReportStatus" NOT NULL DEFAULT 'open',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(6),

    CONSTRAINT "report_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "post_author_id_created_at_idx" ON "app"."post"("author_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "post_status_created_at_idx" ON "app"."post"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "post_club_id_created_at_idx" ON "app"."post"("club_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "post_reaction_post_id_idx" ON "app"."post_reaction"("post_id");

-- CreateIndex
CREATE UNIQUE INDEX "post_reaction_post_id_from_user_id_key" ON "app"."post_reaction"("post_id", "from_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "club_slug_key" ON "app"."club"("slug");

-- CreateIndex
CREATE INDEX "club_status_member_count_idx" ON "app"."club"("status", "member_count" DESC);

-- CreateIndex
CREATE INDEX "club_member_user_id_idx" ON "app"."club_member"("user_id");

-- CreateIndex
CREATE INDEX "club_member_club_id_joined_at_idx" ON "app"."club_member"("club_id", "joined_at");

-- CreateIndex
CREATE INDEX "club_invite_invitee_id_status_idx" ON "app"."club_invite"("invitee_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "club_invite_club_id_invitee_id_key" ON "app"."club_invite"("club_id", "invitee_id");

-- CreateIndex
CREATE INDEX "block_blocked_id_idx" ON "app"."block"("blocked_id");

-- CreateIndex
CREATE INDEX "conversation_user_a_id_last_message_at_idx" ON "app"."conversation"("user_a_id", "last_message_at" DESC);

-- CreateIndex
CREATE INDEX "conversation_user_b_id_last_message_at_idx" ON "app"."conversation"("user_b_id", "last_message_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "conversation_user_a_id_user_b_id_key" ON "app"."conversation"("user_a_id", "user_b_id");

-- CreateIndex
CREATE INDEX "message_conversation_id_created_at_idx" ON "app"."message"("conversation_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "report_target_type_target_id_idx" ON "app"."report"("target_type", "target_id");

-- CreateIndex
CREATE INDEX "report_status_created_at_idx" ON "app"."report"("status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "report_reporter_id_target_type_target_id_key" ON "app"."report"("reporter_id", "target_type", "target_id");

-- AddForeignKey
ALTER TABLE "app"."post" ADD CONSTRAINT "post_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."post_reaction" ADD CONSTRAINT "post_reaction_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "app"."post"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."post_reaction" ADD CONSTRAINT "post_reaction_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."club" ADD CONSTRAINT "club_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."club_member" ADD CONSTRAINT "club_member_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "app"."club"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."club_member" ADD CONSTRAINT "club_member_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."club_invite" ADD CONSTRAINT "club_invite_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "app"."club"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."block" ADD CONSTRAINT "block_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."block" ADD CONSTRAINT "block_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."conversation" ADD CONSTRAINT "conversation_user_a_id_fkey" FOREIGN KEY ("user_a_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."conversation" ADD CONSTRAINT "conversation_user_b_id_fkey" FOREIGN KEY ("user_b_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."message" ADD CONSTRAINT "message_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "app"."conversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."message" ADD CONSTRAINT "message_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."report" ADD CONSTRAINT "report_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
