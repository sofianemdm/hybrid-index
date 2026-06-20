-- AlterTable
ALTER TABLE "app"."hybrid_index" ADD COLUMN     "league_position" INTEGER,
ADD COLUMN     "population_band" TEXT,
ADD COLUMN     "population_percentile" DECIMAL(5,4);
