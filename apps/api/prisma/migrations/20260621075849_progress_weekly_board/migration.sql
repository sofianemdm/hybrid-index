-- CreateTable
CREATE TABLE "app"."progress_event" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "week_key" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "ep_awarded" INTEGER NOT NULL,
    "capped_reason" TEXT,
    "ref_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "progress_event_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app"."progress_weekly" (
    "user_id" UUID NOT NULL,
    "week_key" TEXT NOT NULL,
    "sex" "app"."Sex" NOT NULL,
    "ep" INTEGER NOT NULL DEFAULT 0,
    "active_days" INTEGER NOT NULL DEFAULT 0,
    "pr_count" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "progress_weekly_pkey" PRIMARY KEY ("user_id","week_key")
);

-- CreateIndex
CREATE INDEX "progress_event_week_key_user_id_idx" ON "app"."progress_event"("week_key", "user_id");

-- CreateIndex
CREATE INDEX "progress_event_user_id_week_key_idx" ON "app"."progress_event"("user_id", "week_key");

-- CreateIndex
CREATE INDEX "progress_weekly_week_key_sex_ep_idx" ON "app"."progress_weekly"("week_key", "sex", "ep" DESC);

-- AddForeignKey
ALTER TABLE "app"."progress_event" ADD CONSTRAINT "progress_event_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
