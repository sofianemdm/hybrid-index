# Rapport de nuit — 20 juin 2026 (au réveil ☀️)

Salut ! Pendant la nuit j'ai construit une **vraie app HYBRID INDEX que tu peux ouvrir dans ton
navigateur** ce matin, branchée sur un backend persistant (vraie base de données). Voici tout.

---

## 🚀 Comment lancer l'app (le plus simple)

1. **Vérifie que Docker tourne** (la baleine est verte).
2. Ouvre PowerShell dans le dossier du projet et lance :
   ```powershell
   .\demarrer-app.ps1
   ```
   Ce script démarre **tout** : la base (Postgres + Redis), le `score-service`, l'`api`, puis ouvre
   l'**app dans Chrome**. Laisse la fenêtre ouverte. Le premier lancement Flutter prend ~30 s.

> Si le script dit que les services ne répondent pas : lance d'abord un build, puis relance le script.
> ```powershell
> $env:NODE_OPTIONS="--use-system-ca"; pnpm build
> ```

### Lancement manuel (si tu préfères, 3 terminaux)
```powershell
# Terminal 1 — base de données (si pas déjà up)
docker compose -f infra/docker-compose.yml up -d postgres redis

# Terminal 2 — score-service
cd apps/score-service ; node dist/main.js

# Terminal 3 — api
cd apps/api ; node --env-file-if-exists=.env dist/main.js

# Terminal 4 — l'app (ouvre Chrome)
cd apps/mobile ; flutter run -d chrome
```

---

## 🎮 Quoi essayer (le parcours complet)

1. **Crée un compte** : pseudo, email, mot de passe, **date de naissance** (essaie une date < 13 ans →
   l'app refuse, c'est l'age-gating légal), sexe, objectif.
2. **Onboarding** : mets un temps de course (ex. 5 km en 24:00) et/ou ton max de pompes → l'**Index
   estimé s'affiche en direct**.
3. **Révélation** : clique « Révéler mon HYBRID INDEX » → animation de l'anneau + ton **radar 6 attributs** + ton **rang**.
4. **Accueil** : ton Index, ton rang, ta **carte rival** (l'athlète juste au-dessus de toi), ton radar.
5. **Logge un WOD** (bouton central) : choisis un WOD parmi les 15, entre ton résultat → ton **Index se recalcule** et bouge.
6. **Classement** : onglet Hommes / Femmes, ta ligne est **surlignée**. ~40 athlètes fictifs par sexe peuplent déjà le classement.

> Astuce : essaie un résultat aberrant (ex. Fran en 5 s) → l'app refuse (bornes anti-triche du score-service).

---

## ✅ Ce qui marche (vérifié cette nuit)

**Backend (NestJS + PostgreSQL + Redis, persistant)**
- Inscription / connexion **email + mot de passe (bcrypt) + JWT**, session persistée.
- **Age-gating 13+** (décision D4) → refus `403` propre.
- **Onboarding persisté** : POST `/v1/onboarding/complete` enregistre les efforts + l'Index révélé.
- **Log d'un WOD** : POST `/v1/results` → note l'effort (bornes physio), persiste, **recalcule l'Index/radar** (logique no-drop, autorité = score-service).
- **Classement par ligue** (Hommes/Femmes) via **Redis sorted sets** (repli Postgres), + **rival** (athlète juste au-dessus).
- Seed de **80 athlètes fictifs** + les **15 WODs** + la version de scoring.
- CORS activé pour le navigateur. Smoke test e2e complet : **tout vert**.

**App mobile (Flutter, lancée en Web pour la démo navigateur)**
- Thème sombre « feel jeu » du design system (cyan signature, radar coloré, badges de rang).
- Écrans : **auth, onboarding (aperçu live), révélation animée, accueil, classement, log WOD**.
- États vide / chargement / erreur / succès gérés.
- `flutter analyze` propre + `flutter build web` **OK** + `flutter run` (debug) **OK**.

**Tests** : suite backend **toujours verte** (10/10 sur l'api, 90+ sur le monorepo). Rien de cassé.

---

## ⚠️ Limites connues (à faire ensuite, en toute transparence)

1. **OAuth Apple/Google différé** : impossible à configurer en autonomie (il faut des identifiants
   externes Apple/Google). J'ai mis en place l'**email + mot de passe**, qui est dans la stack
   verrouillée. À brancher avec toi plus tard.
2. **Web = démo navigateur**, pas encore iOS/Android natif. Le code Flutter est **le vrai code du
   produit** (même base) — on l'enverra sur téléphone quand tu voudras (build Android/iOS).
3. **Pas encore de tests automatisés** sur les nouveaux endpoints (auth/results/leaderboard) : ils
   sont validés par un **smoke test e2e réel** cette nuit, mais des tests Jest dédiés restent à écrire (DoD).
4. **Percentile par attribut** non encore stocké (placeholder 0) — l'affichage radar utilise le score, pas ce champ.
5. **Réseau/SSL** : ton réseau intercepte le SSL ; pour `pnpm install` il faut
   `NODE_OPTIONS=--use-system-ca` (déjà documenté). Flutter, lui, n'est pas impacté.

---

## 🔧 État de l'installation

- **Flutter SDK** : installé dans `C:\flutter` (stable 3.44.2) et **ajouté à ton PATH**
  (un terminal **fraîchement ouvert** connaît la commande `flutter`).
- **Docker** : Postgres + Redis tournent. La base a été **migrée** (schémas `app` + `scoring`) et **seedée**.
- **`.env`** : créé localement (non committé) — contient `DATABASE_URL`, `REDIS_URL`, `JWT_SECRET`.

Bonne découverte 💪 — dis-moi ce que tu veux peaufiner en premier (design, plus d'écrans, ou passage sur téléphone).
