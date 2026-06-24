# 🚀 Mettre HYBRID INDEX en ligne — guide débutant (pas à pas)

Objectif : avoir une **URL publique** (ex. `https://hybrid-index.netlify.app`) que tu ouvres
depuis **n'importe quel téléphone ou PC**, sans laisser ton ordi allumé.

On héberge 4 morceaux :
| Morceau | Où on l'héberge | Coût |
|---|---|---|
| Base **PostgreSQL** + **Redis** | Railway (plugins) | gratuit pour démarrer |
| **API** (apps/api) | Railway (service Docker) | gratuit pour démarrer |
| **score-service** (apps/score-service) | Railway (service Docker) | gratuit pour démarrer |
| **Front** (Flutter Web) | Netlify (glisser-déposer) | gratuit |

> Temps : ~30-45 min la première fois. Tu n'écris quasiment pas de code : surtout des clics + copier-coller.

---

## PHASE 0 — Créer les comptes (5 min)
1. **GitHub** : https://github.com → crée un compte (héberge ton code).
2. **Railway** : https://railway.app → « Login with GitHub ».
3. **Netlify** : https://netlify.com → « Sign up with GitHub ».

---

## PHASE 1 — Mettre ton code sur GitHub (5 min)
Ton code est seulement sur ton PC. On le pousse sur GitHub (Railway en a besoin pour déployer).

1. Sur github.com → bouton **New repository** → nom `hybrid-index` → **Private** → *Create*.
2. GitHub t'affiche une URL type `https://github.com/TON-PSEUDO/hybrid-index.git`.
3. Dans ton terminal, à la racine du projet :
   ```
   git remote add origin https://github.com/TON-PSEUDO/hybrid-index.git
   git branch -M main
   git push -u origin main
   ```
   *(Git te demandera de te connecter à GitHub la première fois.)*

> 💡 Je peux faire ces 3 commandes pour toi — il me suffit que tu me donnes l'URL du repo GitHub.

---

## PHASE 2 — Le backend sur Railway (15 min)

### 2.1 Créer le projet + les bases
1. railway.app → **New Project** → **Deploy from GitHub repo** → choisis `hybrid-index`.
2. Une fois le projet ouvert : bouton **+ New** → **Database** → **Add PostgreSQL**.
3. Encore **+ New** → **Database** → **Add Redis**.

### 2.2 Le service score-service
1. **+ New** → **GitHub Repo** → `hybrid-index` (ça crée un 2e service).
2. Ouvre ce service → onglet **Settings** :
   - **Service name** : `score-service`.
   - Section **Build** → **Dockerfile Path** : `infra/docker/Dockerfile.score-service`.
3. Onglet **Settings** → **Networking** → **Generate Domain** (note l'URL, ex. `https://score-service-prod.up.railway.app`).

### 2.3 Le service api
1. Ouvre le **premier service** créé (celui de la phase 2.1) → **Settings** :
   - **Service name** : `api`.
   - **Build** → **Dockerfile Path** : `infra/docker/Dockerfile.api`.
2. Onglet **Variables** → ajoute (bouton *New Variable*) :
   | Variable | Valeur |
   |---|---|
   | `DATABASE_URL` | clique « Add Reference » → `Postgres` → `DATABASE_URL` |
   | `REDIS_URL` | « Add Reference » → `Redis` → `REDIS_URL` |
   | `JWT_SECRET` | une longue chaîne aléatoire (voir astuce ci-dessous) |
   | `SCORE_SERVICE_URL` | l'URL du score-service de l'étape 2.2 |
   | `CORS_ORIGINS` | (on la mettra en Phase 4 — laisse `https://exemple.netlify.app` pour l'instant) |
   | `NODE_ENV` | `production` |
3. **Generate Domain** (onglet Networking) pour l'`api` → note l'URL, ex. `https://api-prod.up.railway.app`. **C'est l'URL que le front utilisera.**

> 🔑 **Astuce JWT_SECRET** : dans un terminal, tape `openssl rand -base64 48` et copie le résultat. (Sous Windows sans openssl : prends une longue suite aléatoire de 50+ caractères.)

### 2.4 Lancer les migrations de base (1 fois)
La base est vide : il faut créer les tables. Le plus simple depuis ton PC, en visant la base Railway :
1. Sur Railway → service **Postgres** → onglet **Variables** → copie la valeur **`DATABASE_URL`** publique.
2. Dans ton terminal, à la racine du projet :
   ```
   DATABASE_URL="<colle-la-ici>" pnpm --filter @hybrid-index/api prisma:deploy
   ```
3. (Optionnel) des utilisateurs de démo + références pro :
   ```
   DATABASE_URL="<la-même>" pnpm --filter @hybrid-index/api prisma:seed
   ```

---

## PHASE 3 — Le front sur Netlify (5 min)
1. Sur ton PC, construis le front en le pointant vers TON api Railway :
   ```
   cd apps/mobile
   C:/flutter/bin/flutter.bat build web --dart-define=API_BASE_URL=https://api-prod.up.railway.app
   ```
   *(remplace par ton URL api réelle.)*
2. Va sur **https://app.netlify.com/drop** et **glisse-dépose le dossier** `apps/mobile/build/web`.
3. Netlify te donne une URL, ex. `https://joyful-cat-123.netlify.app`. **C'est l'adresse de ton app !**

---

## PHASE 4 — Relier front ↔ api (CORS) + tester (3 min)
1. Retourne sur Railway → service **api** → **Variables** → modifie **`CORS_ORIGINS`** = ton URL Netlify exacte (ex. `https://joyful-cat-123.netlify.app`). Sauvegarde → l'api redéploie automatiquement.
2. Ouvre ton URL Netlify **depuis ton téléphone (en 4G)** → inscris-toi → 🎉 ça marche de partout.

---

## 🆘 Si ça ne marche pas
| Symptôme | Cause probable | Solution |
|---|---|---|
| L'app charge mais l'inscription échoue | mauvaise `API_BASE_URL` au build | rebuild le front avec la bonne URL api, re-déploie sur Netlify |
| Erreur CORS dans la console du navigateur | `CORS_ORIGINS` ≠ URL Netlify | mets l'URL Netlify EXACTE (https, sans `/` final) |
| L'api ne démarre pas (logs Railway) | `CORS_ORIGINS` ou `JWT_SECRET` manquant | l'api exige ces 2 variables en prod |
| « relation does not exist » | migrations non jouées | refais la Phase 2.4 |
| score-service injoignable | mauvais `SCORE_SERVICE_URL` | colle l'URL exacte du service score-service |

---

## 🔁 Mettre à jour l'app plus tard
- **Backend** : `git push` → Railway redéploie tout seul.
- **Front** : rebuild (`flutter build web …`) → reglisse `build/web` sur Netlify (ou connecte le repo).

---

## Variables récapitulées
Voir `.env.production.example` à la racine.
