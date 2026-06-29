-- AddColumn (DEFAULT 'fr' pour ne rien casser : tous les profils existants restent en FR).
ALTER TABLE "app"."profile" ADD COLUMN "locale" TEXT NOT NULL DEFAULT 'fr';
