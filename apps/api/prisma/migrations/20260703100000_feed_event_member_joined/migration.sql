-- `member_joined` avait été ajouté au schéma SANS migration (db push sur la dev) : toute base
-- construite par `migrate deploy` (prod, base de test) rejetait l'événement « nouveau membre »
-- (22P02 invalid enum). Découvert par la base de test isolée du 03/07. IF NOT EXISTS : no-op sur
-- les bases (dev) qui ont déjà la valeur.
ALTER TYPE "app"."FeedEventType" ADD VALUE IF NOT EXISTS 'member_joined';
