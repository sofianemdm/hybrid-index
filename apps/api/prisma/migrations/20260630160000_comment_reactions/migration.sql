-- Likes (kudos 👏) sous les commentaires (mini réseau social).
-- Migration NON destructive : ajout d'une colonne (défaut 0) + d'une table + index + FK.

-- AlterTable : compteur dénormalisé de kudos par commentaire (pattern report_count / reaction_count post).
ALTER TABLE "app"."comment" ADD COLUMN IF NOT EXISTS "reaction_count" INTEGER NOT NULL DEFAULT 0;

-- CreateTable : un kudos par (commentaire, utilisateur), unicité garantie en base.
CREATE TABLE IF NOT EXISTS "app"."comment_reaction" (
    "id" UUID NOT NULL,
    "comment_id" UUID NOT NULL,
    "from_user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "comment_reaction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex : unicité (un seul applaudissement par utilisateur et commentaire).
CREATE UNIQUE INDEX IF NOT EXISTS "comment_reaction_comment_id_from_user_id_key" ON "app"."comment_reaction"("comment_id", "from_user_id");

-- CreateIndex : lecture rapide des kudos d'un commentaire.
CREATE INDEX IF NOT EXISTS "comment_reaction_comment_id_idx" ON "app"."comment_reaction"("comment_id");

-- AddForeignKey : cascade à la suppression du commentaire.
ALTER TABLE "app"."comment_reaction" ADD CONSTRAINT "comment_reaction_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "app"."comment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey : cascade à la suppression de l'auteur du kudos.
ALTER TABLE "app"."comment_reaction" ADD CONSTRAINT "comment_reaction_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
