# Prisma — schéma de données HYBRID INDEX

Schéma : `schema.prisma` — deux schémas Postgres `app.*` (api) et `scoring.*` (score-service),
cf. `docs/architecture.md §3`. Multi-schema activé (`previewFeatures = ["multiSchema"]`).

## Commandes
```bash
# nécessite DATABASE_URL (cf. .env.example) ; validate/generate ne se connectent pas à la BD
pnpm --filter @hybrid-index/api prisma:validate
pnpm --filter @hybrid-index/api prisma:generate
# migrations (nécessitent un Postgres en marche — docker compose) :
# npx prisma migrate dev --name init
```

## À faire en migration SQL (non exprimable dans le schéma Prisma)
- **Age-gating (décision D4)** : `ALTER TABLE app."user" ADD CONSTRAINT chk_min_age
  CHECK (date_of_birth <= (now() - interval '13 years'));`
- **Index partiel classement** : `CREATE INDEX ... ON app.wod_result (wod_id, sex, sub_score DESC)
  WHERE review = 'ok';` (l'index Prisma `@@index` ne porte pas le `WHERE` partiel).
- `citext` pour `email` / `display_name` (extension `citext` + type) si l'insensibilité à la casse
  est requise — sinon contrainte d'unicité sur `lower(...)`.

> `email` et `display_name` sont typés `String` (Prisma ne gère pas `citext` nativement) ; à
> finaliser lors de la 1re migration (incrément 2).
