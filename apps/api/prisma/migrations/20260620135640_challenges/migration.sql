-- CreateTable
CREATE TABLE "app"."challenge" (
    "id" UUID NOT NULL,
    "from_user_id" UUID NOT NULL,
    "to_user_id" UUID,
    "wod_id" TEXT NOT NULL,
    "status" "app"."ChallengeStatus" NOT NULL DEFAULT 'pending',
    "target_sub_score" INTEGER,
    "expires_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(6),

    CONSTRAINT "challenge_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "challenge_to_user_id_status_idx" ON "app"."challenge"("to_user_id", "status");

-- CreateIndex
CREATE INDEX "challenge_from_user_id_status_idx" ON "app"."challenge"("from_user_id", "status");

-- AddForeignKey
ALTER TABLE "app"."challenge" ADD CONSTRAINT "challenge_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."challenge" ADD CONSTRAINT "challenge_to_user_id_fkey" FOREIGN KEY ("to_user_id") REFERENCES "app"."user"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."challenge" ADD CONSTRAINT "challenge_wod_id_fkey" FOREIGN KEY ("wod_id") REFERENCES "app"."wod"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
