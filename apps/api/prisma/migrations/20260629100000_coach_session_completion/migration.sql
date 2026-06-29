-- CreateTable
CREATE TABLE "app"."coach_session_completion" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "session_id" TEXT NOT NULL,
    "completed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_day" DATE NOT NULL,

    CONSTRAINT "coach_session_completion_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "coach_session_completion_user_id_session_id_completed_day_key" ON "app"."coach_session_completion"("user_id", "session_id", "completed_day");

-- CreateIndex
CREATE INDEX "coach_session_completion_user_id_completed_at_idx" ON "app"."coach_session_completion"("user_id", "completed_at" DESC);

-- AddForeignKey
ALTER TABLE "app"."coach_session_completion" ADD CONSTRAINT "coach_session_completion_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
