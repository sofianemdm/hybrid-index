# 🚀 Guide de démarrage (débutant) — HYBRID INDEX

> Tu n'as jamais fait ça ? Normal. Suis les étapes dans l'ordre, copie-colle les commandes.
> Tout se passe sur **Windows 11** (ton PC), dans **PowerShell**.

Le dossier du projet est : `E:\HYBRID INDEX\hybrid-index-starter\hybrid-index`
Pour **ouvrir un terminal au bon endroit** : ouvre ce dossier dans l'explorateur de fichiers,
clique dans la barre d'adresse, tape `powershell` et appuie sur Entrée.

---

## ✅ Étape 0 — Ce qui est DÉJÀ installé sur ton PC
On les a utilisés pour construire le projet, donc tu n'as **rien à faire** ici :
- **Node.js** (le moteur qui fait tourner le code)
- **pnpm** (le gestionnaire de paquets)
- **Git** (l'historique du code)

Pour vérifier (optionnel) : dans PowerShell, tape `node -v` → ça doit afficher un numéro (ex. `v24...`).

---

## 🧪 Étape 1 — Tester ce qui marche DÉJÀ (sans rien installer)

### a) Lancer tous les tests automatiques (la preuve que tout est correct)
Dans le terminal du projet :
```powershell
pnpm test
```
➡️ Tu dois voir défiler **90 tests verts** ✅. C'est la preuve que le moteur de score est juste.

### b) Voir le serveur de score tourner pour de vrai
```powershell
pnpm --filter @hybrid-index/score-service build
pnpm --filter @hybrid-index/score-service start
```
Laisse cette fenêtre ouverte (le serveur tourne). Ouvre ton **navigateur** à cette adresse :
```
http://localhost:3001/v1/score/health
```
➡️ Tu dois voir : `{"service":"score-service","status":"ok","activeScoringVersion":"scoring-v1"}`

Pour **arrêter** le serveur : reviens dans la fenêtre PowerShell et appuie sur `Ctrl + C`.

### c) Calculer un vrai score (commande à copier)
Ouvre un **2e** PowerShell (laisse le serveur tourner dans le 1er) et colle :
```powershell
Invoke-RestMethod -Method POST http://localhost:3001/v1/score/sub-score -ContentType "application/json" -Body '{"wodId":"run_5k","sex":"male","scoreType":"time","rawResult":1440}'
```
➡️ Réponse : un sous-score de **884** pour un 5 km en 24 min. 🎉
(Change `1440` par ton temps en **secondes** pour voir ton propre score.)

---

## 🐳 Étape 2 — Installer Docker (pour la base de données, étape SUIVANTE)

La **base de données** (qui stockera les comptes, les WODs loggés, les classements) tourne dans
**Docker**. C'est la seule chose à installer pour continuer la construction.

### Installation (10 min)
1. Va sur **https://www.docker.com/products/docker-desktop/**
2. Clique **Download for Windows**.
3. Lance le fichier téléchargé **`Docker Desktop Installer.exe`**.
4. Garde les options **par défaut** (laisse coché « Use WSL 2 »). Clique **OK / Install**.
5. **Redémarre le PC** si on te le demande.
6. Ouvre **Docker Desktop** (menu Démarrer), accepte les conditions, et **attends** que la petite
   **baleine** en bas à droite devienne **verte / stable** (« Engine running »).

### Vérifier que ça marche
Dans PowerShell :
```powershell
docker --version
```
➡️ Doit afficher un numéro de version (ex. `Docker version 27...`).

> 😵 Si erreur « WSL » : ouvre PowerShell **en administrateur** (clic droit → Exécuter en tant
> qu'administrateur), tape `wsl --install`, redémarre, puis relance Docker Desktop.

---

## 🗄️ Étape 3 — Démarrer la base de données

Une fois Docker installé et la baleine verte, dans le terminal du projet :
```powershell
docker compose -f "infra/docker-compose.yml" up -d postgres redis
```
➡️ Ça télécharge et démarre **PostgreSQL** (la base) et **Redis** (les classements).

Vérifier qu'ils tournent :
```powershell
docker ps
```
➡️ Tu dois voir 2 lignes (`postgres` et `redis`).

Pour **tout arrêter** plus tard :
```powershell
docker compose -f "infra/docker-compose.yml" down
```

> ℹ️ Pour l'instant la base sera **vide** : le code qui crée les comptes et enregistre les WODs
> n'est pas encore écrit (c'est la suite de l'incrément 2). Mais une fois Docker prêt, on pourra
> **tout construire ET tester pour de vrai**.

---

## ▶️ Étape 4 — Quand tu reviens vers moi (reprise)

Dis-moi simplement : **« Docker est installé et la baleine est verte »**.
Je reprendrai alors la construction (création de compte → onboarding → reveal sauvegardé →
logging des WODs → classements…), en testant chaque étape sur la vraie base. 💪

---

## 🆘 Si ça coince
- **« pnpm n'est pas reconnu »** → ferme et rouvre PowerShell ; sinon redémarre le PC.
- **Erreur de certificat lors d'un `pnpm install`** → préfixe la commande par les variables système :
  `$env:NODE_OPTIONS="--use-system-ca"` puis relance `pnpm install`.
- **Docker ne démarre pas** → vérifie que la « virtualisation » est activée (souvent par défaut sur
  Windows 11) ; en dernier recours, `wsl --install` en administrateur puis redémarrage.
- **Un port est déjà utilisé** (3000/3001/5432/6379) → ferme les vieux terminaux ou redémarre le PC.

Tu peux aussi me poser n'importe quelle question ici, à n'importe quelle étape. 🙂
