# Déploiement en production — HYBRID INDEX

Backend conteneurisé (api + score-service + Postgres + Redis). L'app Flutter se déploie à part
(Web statique, ou stores via le build natif — cf. docs/build-android.md).

> ⚠️ L'`api` **refuse de démarrer** sans `JWT_SECRET` et `CORS_ORIGINS` en production (garde-fous
> sécurité voulus). C'est normal : il faut fournir ces secrets.

## 1. Pré-requis serveur
- Un serveur Linux avec **Docker** + **Docker Compose v2**.
- Un nom de domaine + un **reverse-proxy TLS** devant l'api (Caddy, Traefik ou nginx) pour le HTTPS.

## 2. Secrets (jamais committés)
Crée un fichier `.env.prod` à la racine (ignoré par git via `.env.*`) :
```env
POSTGRES_PASSWORD=<mot de passe fort généré>
JWT_SECRET=<chaîne aléatoire 32+ caractères, ex: openssl rand -base64 48>
CORS_ORIGINS=https://app.tondomaine.com
GOOGLE_CLIENT_ID=<optionnel : ID client Google OAuth>
```

## 3. Build + démarrage
```bash
docker compose -f infra/docker-compose.prod.yml --env-file .env.prod up -d --build
```
Cela démarre Postgres, Redis, le score-service (interne) et l'api (port 3000, à placer derrière le
reverse-proxy).

## 4. Migrations de base de données
À jouer à chaque déploiement qui modifie le schéma (depuis une machine avec le code + Node) :
```bash
DATABASE_URL="postgres://hybrid:<POSTGRES_PASSWORD>@<host>:5432/hybrid_index" \
  pnpm --filter @hybrid-index/api prisma:deploy
```
`prisma migrate deploy` applique les migrations existantes (apps/api/prisma/migrations) sans en
créer de nouvelles — sûr en production.

## 5. Seed (optionnel)
Le seed insère des athlètes de démonstration + les WODs + badges + la version de scoring. En prod
réel, ne seede **que** les données de référence (WODs, badges, version), pas les faux athlètes :
adapte `apps/api/prisma/seed.ts` ou n'exécute le seed que sur un environnement de démo.

## 6. Reverse-proxy TLS (exemple Caddy)
```caddyfile
api.tondomaine.com {
    reverse_proxy localhost:3000
}
```
Caddy gère automatiquement les certificats Let's Encrypt. Mets ensuite `CORS_ORIGINS` à l'origine de
ton front (ex. `https://app.tondomaine.com`).

## 7. App Flutter (front)
- **Web** : `flutter build web --dart-define=API_BASE_URL=https://api.tondomaine.com` puis sers le
  dossier `build/web` (Netlify, Vercel, S3+CloudFront, ou le reverse-proxy).
- **Android/iOS** : cf. docs/build-android.md (passer `API_BASE_URL` via `--dart-define`).

## 8. Checklist sécurité avant ouverture publique
- [ ] `JWT_SECRET` fort et secret ; `CORS_ORIGINS` restreint au(x) domaine(s) du front.
- [ ] Postgres non exposé publiquement (pas de port hôte en prod — déjà le cas ici).
- [ ] HTTPS partout (reverse-proxy TLS).
- [ ] Sauvegardes Postgres (volume `pgdata`) planifiées.
- [ ] Rotation/limitation : ajouter un rate-limiter (à venir) ; surveiller les logs (Sentry/PostHog
      prévus dans la stack).
- [ ] OAuth Apple/Google : domaines de redirection autorisés configurés côté provider.

## Limites connues (cf. docs/decisions-log.md)
- Push FCM non branché (flux in-app `/v1/me/notifications/feed` fonctionne sans Firebase).
- Distributions de score = estimations sport-science, à recalibrer sur les vraies données (≥200/sexe).
