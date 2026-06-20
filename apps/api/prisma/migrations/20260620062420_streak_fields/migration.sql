-- AlterTable
ALTER TABLE "app"."streak" ADD COLUMN     "last_outcome" TEXT,
ADD COLUMN     "validated_active_weeks" INTEGER NOT NULL DEFAULT 0;
