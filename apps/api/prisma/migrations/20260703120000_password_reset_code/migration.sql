-- Codes de réinitialisation de mot de passe (6 chiffres hachés bcrypt, 15 min, 5 essais max).
CREATE TABLE "app"."password_reset_code" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "code_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_reset_code_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "password_reset_code_user_id_idx" ON "app"."password_reset_code"("user_id");

ALTER TABLE "app"."password_reset_code"
  ADD CONSTRAINT "password_reset_code_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "app"."user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
