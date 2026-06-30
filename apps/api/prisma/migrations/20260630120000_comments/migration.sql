-- Mini réseau social : commentaires sous les posts du feed (+ signalement de commentaire).
-- Migration NON destructive : ajout d'une valeur d'enum et d'une table.

-- AlterEnum : nouveau type de cible de signalement « comment ».
ALTER TYPE "app"."ReportTargetType" ADD VALUE IF NOT EXISTS 'comment';

-- CreateTable
CREATE TABLE IF NOT EXISTS "app"."comment" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "body" VARCHAR(500) NOT NULL,
    "hidden" BOOLEAN NOT NULL DEFAULT false,
    "report_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "comment_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "comment_post_id_created_at_idx" ON "app"."comment"("post_id", "created_at");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "comment_author_id_idx" ON "app"."comment"("author_id");

-- AddForeignKey
ALTER TABLE "app"."comment" ADD CONSTRAINT "comment_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "app"."post"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app"."comment" ADD CONSTRAINT "comment_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
