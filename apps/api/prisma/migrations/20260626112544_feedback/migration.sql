-- CreateTable
CREATE TABLE "app"."feedback" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "message" VARCHAR(2000) NOT NULL,
    "context" VARCHAR(200),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "feedback_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "feedback_created_at_idx" ON "app"."feedback"("created_at");
