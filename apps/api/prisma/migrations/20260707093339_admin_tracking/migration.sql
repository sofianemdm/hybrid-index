-- AlterTable
ALTER TABLE "app"."user" ADD COLUMN     "last_login_at" TIMESTAMPTZ(6);

-- CreateTable
CREATE TABLE "app"."visit_log" (
    "id" UUID NOT NULL,
    "ip" TEXT NOT NULL,
    "user_id" UUID,
    "path" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "user_agent" TEXT,
    "country" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "visit_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "visit_log_created_at_idx" ON "app"."visit_log"("created_at");

-- CreateIndex
CREATE INDEX "visit_log_ip_created_at_idx" ON "app"."visit_log"("ip", "created_at");

-- CreateIndex
CREATE INDEX "visit_log_user_id_created_at_idx" ON "app"."visit_log"("user_id", "created_at");
