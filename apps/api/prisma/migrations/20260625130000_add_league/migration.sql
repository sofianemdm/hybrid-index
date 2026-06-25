-- CreateEnum
CREATE TYPE "app"."LeagueSeasonStatus" AS ENUM ('upcoming', 'active', 'closed');

-- CreateEnum
CREATE TYPE "app"."LeagueFiliere" AS ENUM ('bodyweight', 'equipped');

-- CreateEnum
CREATE TYPE "app"."LeagueLevel" AS ENUM ('rx', 'scaled');

-- CreateTable
CREATE TABLE "app"."league_season" (
    "id" UUID NOT NULL,
    "month_key" TEXT NOT NULL,
    "status" "app"."LeagueSeasonStatus" NOT NULL DEFAULT 'upcoming',
    "division_tier" INTEGER NOT NULL DEFAULT 1,
    "opens_at" TIMESTAMPTZ(6) NOT NULL,
    "closes_at" TIMESTAMPTZ(6) NOT NULL,
    "closed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "league_season_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."league_week" (
    "id" UUID NOT NULL,
    "season_id" UUID NOT NULL,
    "week_index" INTEGER NOT NULL,
    "week_key" TEXT NOT NULL,
    "wod_id" TEXT NOT NULL,
    "filiere" "app"."LeagueFiliere" NOT NULL DEFAULT 'bodyweight',
    "opens_at" TIMESTAMPTZ(6) NOT NULL,
    "closes_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "league_week_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."league_entry" (
    "season_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "filiere" "app"."LeagueFiliere" NOT NULL DEFAULT 'bodyweight',
    "level" "app"."LeagueLevel" NOT NULL DEFAULT 'rx',
    "division_id" UUID,
    "joined_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "league_entry_pkey" PRIMARY KEY ("season_id","user_id")
);

-- CreateTable
CREATE TABLE "app"."league_points" (
    "id" UUID NOT NULL,
    "season_id" UUID NOT NULL,
    "week_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "filiere" "app"."LeagueFiliere" NOT NULL DEFAULT 'bodyweight',
    "level" "app"."LeagueLevel" NOT NULL DEFAULT 'rx',
    "wod_result_id" UUID NOT NULL,
    "points" INTEGER NOT NULL,
    "sub_score" INTEGER NOT NULL,
    "review" "app"."ResultReview" NOT NULL DEFAULT 'ok',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "league_points_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."league_division" (
    "id" UUID NOT NULL,
    "season_id" UUID NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "filiere" "app"."LeagueFiliere" NOT NULL DEFAULT 'bodyweight',
    "level" "app"."LeagueLevel" NOT NULL DEFAULT 'rx',
    "tier" INTEGER NOT NULL,
    "label" TEXT NOT NULL,

    CONSTRAINT "league_division_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."league_standing" (
    "id" UUID NOT NULL,
    "season_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "filiere" "app"."LeagueFiliere" NOT NULL DEFAULT 'bodyweight',
    "level" "app"."LeagueLevel" NOT NULL DEFAULT 'rx',
    "division_id" UUID,
    "final_rank" INTEGER NOT NULL,
    "total_points" INTEGER NOT NULL,
    "movement" TEXT,

    CONSTRAINT "league_standing_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "league_season_month_key_key" ON "app"."league_season"("month_key");

-- CreateIndex
CREATE INDEX "league_season_status_idx" ON "app"."league_season"("status");

-- CreateIndex
CREATE INDEX "league_week_week_key_idx" ON "app"."league_week"("week_key");

-- CreateIndex
CREATE UNIQUE INDEX "league_week_season_id_week_index_filiere_key" ON "app"."league_week"("season_id", "week_index", "filiere");

-- CreateIndex
CREATE UNIQUE INDEX "league_week_season_id_week_key_filiere_key" ON "app"."league_week"("season_id", "week_key", "filiere");

-- CreateIndex
CREATE INDEX "league_entry_season_id_sex_idx" ON "app"."league_entry"("season_id", "sex");

-- CreateIndex
CREATE INDEX "league_entry_season_id_division_id_idx" ON "app"."league_entry"("season_id", "division_id");

-- CreateIndex
CREATE UNIQUE INDEX "league_points_wod_result_id_key" ON "app"."league_points"("wod_result_id");

-- CreateIndex
CREATE INDEX "league_points_season_id_user_id_idx" ON "app"."league_points"("season_id", "user_id");

-- CreateIndex
CREATE INDEX "league_points_season_id_sex_points_idx" ON "app"."league_points"("season_id", "sex", "points" DESC);

-- CreateIndex
CREATE INDEX "league_division_season_id_sex_idx" ON "app"."league_division"("season_id", "sex");

-- CreateIndex
CREATE UNIQUE INDEX "league_division_season_id_sex_filiere_level_tier_key" ON "app"."league_division"("season_id", "sex", "filiere", "level", "tier");

-- CreateIndex
CREATE INDEX "league_standing_season_id_sex_final_rank_idx" ON "app"."league_standing"("season_id", "sex", "final_rank");

-- CreateIndex
CREATE INDEX "league_standing_user_id_season_id_idx" ON "app"."league_standing"("user_id", "season_id");

-- CreateIndex
CREATE UNIQUE INDEX "league_standing_season_id_user_id_key" ON "app"."league_standing"("season_id", "user_id");

-- AddForeignKey
ALTER TABLE "app"."league_week" ADD CONSTRAINT "league_week_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "app"."league_season"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."league_entry" ADD CONSTRAINT "league_entry_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "app"."league_season"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."league_entry" ADD CONSTRAINT "league_entry_division_id_fkey" FOREIGN KEY ("division_id") REFERENCES "app"."league_division"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."league_points" ADD CONSTRAINT "league_points_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "app"."league_season"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."league_division" ADD CONSTRAINT "league_division_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "app"."league_season"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."league_standing" ADD CONSTRAINT "league_standing_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "app"."league_season"("id") ON DELETE CASCADE ON UPDATE CASCADE;

