-- AlterTable
ALTER TABLE "app"."avatar" ADD COLUMN     "accessory" SMALLINT NOT NULL DEFAULT 0,
ADD COLUMN     "background" SMALLINT NOT NULL DEFAULT 0,
ADD COLUMN     "photo_data" TEXT;
