-- Réponses / threads (1 SEUL niveau) sous les commentaires (mini réseau social).
-- Migration NON destructive : ajout de 2 colonnes (parent_id nullable + reply_count défaut 0),
-- d'une self-FK (réponse → commentaire racine) et d'un index sur parent_id.

-- AlterTable : parent_id (réponse à un commentaire racine) + compteur dénormalisé de réponses.
ALTER TABLE "app"."comment" ADD COLUMN IF NOT EXISTS "parent_id" UUID;
ALTER TABLE "app"."comment" ADD COLUMN IF NOT EXISTS "reply_count" INTEGER NOT NULL DEFAULT 0;

-- CreateIndex : lecture rapide des réponses d'un commentaire racine (ordre chronologique géré côté requête).
CREATE INDEX IF NOT EXISTS "comment_parent_id_idx" ON "app"."comment"("parent_id");

-- AddForeignKey : self-relation. Cascade à la suppression du commentaire parent (les réponses partent avec).
ALTER TABLE "app"."comment" ADD CONSTRAINT "comment_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "app"."comment"("id") ON DELETE CASCADE ON UPDATE CASCADE;
