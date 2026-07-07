-- Suppression de l'ancien système d'avatar « dessiné » (gén. 1) — décision 07/07.
-- L'app ne rend plus que photo / DiceBear avataaars ; ces colonnes ne sont plus lues nulle part.
ALTER TABLE "app"."avatar" DROP COLUMN "skin_tone";
ALTER TABLE "app"."avatar" DROP COLUMN "hair_style";
ALTER TABLE "app"."avatar" DROP COLUMN "hair_color";
ALTER TABLE "app"."avatar" DROP COLUMN "beard_style";
ALTER TABLE "app"."avatar" DROP COLUMN "accessory";
ALTER TABLE "app"."avatar" DROP COLUMN "background";
