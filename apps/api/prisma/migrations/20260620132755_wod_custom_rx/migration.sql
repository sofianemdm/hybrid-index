-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "app"."WodType" ADD VALUE 'tabata';
ALTER TYPE "app"."WodType" ADD VALUE 'distance';

-- AlterTable
ALTER TABLE "app"."wod" ADD COLUMN     "calibration" TEXT NOT NULL DEFAULT 'estimated',
ADD COLUMN     "created_by_id" UUID,
ADD COLUMN     "result_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "rounds" INTEGER,
ADD COLUMN     "time_cap_sec" INTEGER,
ADD COLUMN     "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "visibility" "app"."Visibility" NOT NULL DEFAULT 'public';

-- AlterTable
ALTER TABLE "app"."wod_result" ADD COLUMN     "rx_compliant" BOOLEAN NOT NULL DEFAULT true;

-- CreateIndex
CREATE INDEX "wod_is_custom_visibility_created_at_idx" ON "app"."wod"("is_custom", "visibility", "created_at" DESC);

-- CreateIndex
CREATE INDEX "wod_created_by_id_idx" ON "app"."wod"("created_by_id");

-- AddForeignKey
ALTER TABLE "app"."wod" ADD CONSTRAINT "wod_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "app"."user"("id") ON DELETE SET NULL ON UPDATE CASCADE;
