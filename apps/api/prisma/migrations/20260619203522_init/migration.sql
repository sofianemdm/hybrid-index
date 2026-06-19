-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "app";

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "scoring";

-- CreateEnum
CREATE TYPE "app"."Sex" AS ENUM ('male', 'female');

-- CreateEnum
CREATE TYPE "app"."EquipmentPref" AS ENUM ('none', 'equipped', 'both');

-- CreateEnum
CREATE TYPE "app"."Goal" AS ENUM ('hyrox', 'crossfit_strength', 'all_round');

-- CreateEnum
CREATE TYPE "app"."AttributeKey" AS ENUM ('engine', 'speed', 'strength', 'power', 'muscular_endurance', 'hybrid');

-- CreateEnum
CREATE TYPE "app"."WodType" AS ENUM ('for_time', 'amrap', 'emom', 'chipper', 'strength', 'interval');

-- CreateEnum
CREATE TYPE "app"."ScoreType" AS ENUM ('time', 'reps', 'load', 'distance');

-- CreateEnum
CREATE TYPE "app"."ResultSource" AS ENUM ('declared', 'verified');

-- CreateEnum
CREATE TYPE "app"."Visibility" AS ENUM ('public', 'private');

-- CreateEnum
CREATE TYPE "app"."Rank" AS ENUM ('rookie', 'bronze', 'silver', 'gold', 'platinum', 'diamond', 'elite');

-- CreateEnum
CREATE TYPE "app"."DistributionSource" AS ENUM ('public', 'community');

-- CreateEnum
CREATE TYPE "app"."ChallengeStatus" AS ENUM ('pending', 'accepted', 'completed', 'expired', 'declined');

-- CreateEnum
CREATE TYPE "app"."ReactionTarget" AS ENUM ('wod_result', 'badge', 'rank_up');

-- CreateEnum
CREATE TYPE "app"."BadgeCategory" AS ENUM ('progression', 'collection', 'performance', 'consistency', 'social');

-- CreateEnum
CREATE TYPE "app"."ResultReview" AS ENUM ('ok', 'pending_review', 'rejected');

-- CreateEnum
CREATE TYPE "scoring"."ScoringStatus" AS ENUM ('draft', 'active', 'superseded');

-- CreateTable
CREATE TABLE "app"."user" (
    "id" UUID NOT NULL,
    "email" TEXT,
    "password_hash" TEXT,
    "date_of_birth" DATE NOT NULL,
    "age_verified" BOOLEAN NOT NULL DEFAULT false,
    "consents" JSONB NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "deletion_requested_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "user_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."auth_identity" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "provider" TEXT NOT NULL,
    "provider_subject" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_identity_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."avatar" (
    "user_id" UUID NOT NULL,
    "skin_tone" SMALLINT NOT NULL,
    "hair_style" SMALLINT NOT NULL,
    "hair_color" SMALLINT NOT NULL,
    "beard_style" SMALLINT,
    "equipped_cosmetics" JSONB NOT NULL,
    "unlocked_cosmetics" JSONB NOT NULL,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "avatar_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "app"."profile" (
    "user_id" UUID NOT NULL,
    "display_name" TEXT NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "goal" "app"."Goal" NOT NULL,
    "equipment_pref" "app"."EquipmentPref" NOT NULL,
    "rank" "app"."Rank" NOT NULL DEFAULT 'rookie',
    "visibility" "app"."Visibility" NOT NULL DEFAULT 'public',
    "city" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "profile_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "app"."hybrid_index" (
    "user_id" UUID NOT NULL,
    "value" INTEGER NOT NULL,
    "percentile" DECIMAL(5,4) NOT NULL,
    "is_provisional" BOOLEAN NOT NULL,
    "is_estimated" BOOLEAN NOT NULL,
    "radar_coverage" SMALLINT NOT NULL,
    "projected_value" INTEGER,
    "confidence_level" TEXT NOT NULL,
    "scoring_version_id" UUID NOT NULL,
    "computed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "hybrid_index_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "app"."attribute_score" (
    "user_id" UUID NOT NULL,
    "attribute" "app"."AttributeKey" NOT NULL,
    "score" INTEGER NOT NULL,
    "percentile" DECIMAL(5,4) NOT NULL,
    "unlocked" BOOLEAN NOT NULL,
    "is_estimated" BOOLEAN NOT NULL,
    "is_stale" BOOLEAN NOT NULL,
    "best_result_id" UUID,
    "scoring_version_id" UUID NOT NULL,
    "last_updated" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "attribute_score_pkey" PRIMARY KEY ("user_id","attribute")
);

-- CreateTable
CREATE TABLE "app"."wod" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "is_benchmark" BOOLEAN NOT NULL,
    "is_custom" BOOLEAN NOT NULL DEFAULT false,
    "type" "app"."WodType" NOT NULL,
    "requires_equipment" BOOLEAN NOT NULL,
    "target_attributes" "app"."AttributeKey"[],
    "score_type" "app"."ScoreType" NOT NULL,
    "movements" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wod_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."wod_result" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "wod_id" TEXT NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "raw_result" DECIMAL(65,30) NOT NULL,
    "sub_score" INTEGER,
    "percentile" DECIMAL(5,4),
    "attributes_affected" "app"."AttributeKey"[],
    "source" "app"."ResultSource" NOT NULL DEFAULT 'declared',
    "review" "app"."ResultReview" NOT NULL DEFAULT 'ok',
    "scoring_version_id" UUID,
    "idempotency_key" TEXT,
    "visibility" "app"."Visibility" NOT NULL DEFAULT 'public',
    "performed_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wod_result_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."league" (
    "id" TEXT NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "label" TEXT NOT NULL,

    CONSTRAINT "league_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."rival" (
    "user_id" UUID NOT NULL,
    "rival_user_id" UUID,
    "rival_index_value" INTEGER,
    "state" TEXT NOT NULL,
    "recomputed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "rival_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "app"."streak" (
    "user_id" UUID NOT NULL,
    "current" INTEGER NOT NULL DEFAULT 0,
    "best" INTEGER NOT NULL DEFAULT 0,
    "weekly_goal" INTEGER NOT NULL DEFAULT 3,
    "freeze_tokens" INTEGER NOT NULL DEFAULT 1,
    "freeze_tokens_refreshed_at" TIMESTAMPTZ(6),
    "planned_rest" BOOLEAN NOT NULL DEFAULT false,
    "last_week_evaluated" TEXT,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "streak_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "app"."notification_prefs" (
    "user_id" UUID NOT NULL,
    "prefs" JSONB NOT NULL,
    "quiet_hours" JSONB NOT NULL,
    "daily_cap" INTEGER NOT NULL DEFAULT 2,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "notification_prefs_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "app"."follow" (
    "follower_id" UUID NOT NULL,
    "followee_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "follow_pkey" PRIMARY KEY ("follower_id","followee_id")
);

-- CreateTable
CREATE TABLE "app"."badge" (
    "id" TEXT NOT NULL,
    "category" "app"."BadgeCategory" NOT NULL,
    "condition" TEXT NOT NULL,
    "rarity" TEXT NOT NULL,
    "cosmetic_unlock" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "badge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."user_badge" (
    "user_id" UUID NOT NULL,
    "badge_id" TEXT NOT NULL,
    "unlocked_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_badge_pkey" PRIMARY KEY ("user_id","badge_id")
);

-- CreateTable
CREATE TABLE "scoring"."scoring_version" (
    "id" UUID NOT NULL,
    "semver" TEXT NOT NULL,
    "status" "scoring"."ScoringStatus" NOT NULL,
    "f_params" JSONB NOT NULL,
    "attribute_weights" JSONB NOT NULL,
    "freshness_weeks" SMALLINT NOT NULL DEFAULT 26,
    "notes" TEXT,
    "activated_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "scoring_version_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "scoring"."reference_distribution" (
    "id" UUID NOT NULL,
    "wod_id" TEXT NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "source" "app"."DistributionSource" NOT NULL,
    "n" INTEGER NOT NULL,
    "percentile_curve" JSONB NOT NULL,
    "pro_reference" DECIMAL(65,30) NOT NULL,
    "scoring_version_id" UUID NOT NULL,
    "computed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reference_distribution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "scoring"."hybrid_index_history" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "value" INTEGER NOT NULL,
    "percentile" DECIMAL(5,4) NOT NULL,
    "scoring_version_id" UUID NOT NULL,
    "reason" TEXT NOT NULL,
    "computed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "hybrid_index_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "scoring"."recompute_job" (
    "id" UUID NOT NULL,
    "from_version" UUID NOT NULL,
    "to_version" UUID NOT NULL,
    "status" TEXT NOT NULL,
    "total_users" INTEGER NOT NULL,
    "processed" INTEGER NOT NULL DEFAULT 0,
    "started_at" TIMESTAMPTZ(6),
    "finished_at" TIMESTAMPTZ(6),

    CONSTRAINT "recompute_job_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_email_key" ON "app"."user"("email");

-- CreateIndex
CREATE INDEX "auth_identity_user_id_idx" ON "app"."auth_identity"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "auth_identity_provider_provider_subject_key" ON "app"."auth_identity"("provider", "provider_subject");

-- CreateIndex
CREATE UNIQUE INDEX "profile_display_name_key" ON "app"."profile"("display_name");

-- CreateIndex
CREATE INDEX "profile_sex_idx" ON "app"."profile"("sex");

-- CreateIndex
CREATE INDEX "profile_rank_idx" ON "app"."profile"("rank");

-- CreateIndex
CREATE INDEX "hybrid_index_value_idx" ON "app"."hybrid_index"("value" DESC);

-- CreateIndex
CREATE INDEX "attribute_score_attribute_score_idx" ON "app"."attribute_score"("attribute", "score" DESC);

-- CreateIndex
CREATE INDEX "wod_requires_equipment_idx" ON "app"."wod"("requires_equipment");

-- CreateIndex
CREATE INDEX "wod_result_wod_id_sex_sub_score_idx" ON "app"."wod_result"("wod_id", "sex", "sub_score" DESC);

-- CreateIndex
CREATE INDEX "wod_result_user_id_wod_id_performed_at_idx" ON "app"."wod_result"("user_id", "wod_id", "performed_at" DESC);

-- CreateIndex
CREATE INDEX "wod_result_user_id_performed_at_idx" ON "app"."wod_result"("user_id", "performed_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "wod_result_user_id_idempotency_key_key" ON "app"."wod_result"("user_id", "idempotency_key");

-- CreateIndex
CREATE INDEX "follow_followee_id_idx" ON "app"."follow"("followee_id");

-- CreateIndex
CREATE INDEX "follow_follower_id_created_at_idx" ON "app"."follow"("follower_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "reference_distribution_wod_id_sex_scoring_version_id_key" ON "scoring"."reference_distribution"("wod_id", "sex", "scoring_version_id");

-- CreateIndex
CREATE INDEX "hybrid_index_history_user_id_computed_at_idx" ON "scoring"."hybrid_index_history"("user_id", "computed_at");

-- AddForeignKey
ALTER TABLE "app"."auth_identity" ADD CONSTRAINT "auth_identity_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."avatar" ADD CONSTRAINT "avatar_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."profile" ADD CONSTRAINT "profile_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."hybrid_index" ADD CONSTRAINT "hybrid_index_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."attribute_score" ADD CONSTRAINT "attribute_score_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."wod_result" ADD CONSTRAINT "wod_result_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."wod_result" ADD CONSTRAINT "wod_result_wod_id_fkey" FOREIGN KEY ("wod_id") REFERENCES "app"."wod"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."rival" ADD CONSTRAINT "rival_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."rival" ADD CONSTRAINT "rival_rival_user_id_fkey" FOREIGN KEY ("rival_user_id") REFERENCES "app"."user"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."streak" ADD CONSTRAINT "streak_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."notification_prefs" ADD CONSTRAINT "notification_prefs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."follow" ADD CONSTRAINT "follow_follower_id_fkey" FOREIGN KEY ("follower_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."follow" ADD CONSTRAINT "follow_followee_id_fkey" FOREIGN KEY ("followee_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."user_badge" ADD CONSTRAINT "user_badge_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."user_badge" ADD CONSTRAINT "user_badge_badge_id_fkey" FOREIGN KEY ("badge_id") REFERENCES "app"."badge"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
