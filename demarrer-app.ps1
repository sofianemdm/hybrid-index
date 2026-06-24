# HYBRID INDEX — Lancer toute l'app en une commande (Windows PowerShell).
# Usage : clic droit > "Exécuter avec PowerShell", ou dans un terminal :  .\demarrer-app.ps1
#
# Démarre : Postgres + Redis (Docker) -> score-service (:3001) -> api (:3000) -> app Flutter (Chrome).
# Pré-requis déjà installés : Docker Desktop (baleine verte), Node, pnpm, Flutter (C:\flutter\bin).

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$flutter = "C:\flutter\bin\flutter.bat"

Write-Host "==> 1/5  Base de données (Docker : Postgres + Redis)..." -ForegroundColor Cyan
docker compose -f "$root\infra\docker-compose.yml" up -d postgres redis | Out-Null

Write-Host "==> 2/5  Build du backend (pnpm build)..." -ForegroundColor Cyan
# On reconstruit le backend (api + score-service) AVANT de le lancer, sinon `node dist/main.js`
# tourne sur l'ancien code compile -> les changements (seance masquee, faux users, etc.) ne sont
# pas pris en compte en local. Turbo met en cache : rapide si rien n'a change.
$env:NODE_OPTIONS = "--use-system-ca"
Set-Location $root
pnpm build
if ($LASTEXITCODE -ne 0) {
  Write-Host "Echec du build backend (pnpm build). Corrige l'erreur ci-dessus puis relance." -ForegroundColor Red
  exit 1
}

Write-Host "==> 3/5  score-service (port 3001)..." -ForegroundColor Cyan
Start-Process -WindowStyle Minimized powershell -ArgumentList @(
  "-NoExit","-Command","cd '$root\apps\score-service'; node dist/main.js"
)

Write-Host "==> 4/5  api (port 3000)..." -ForegroundColor Cyan
Start-Process -WindowStyle Minimized powershell -ArgumentList @(
  "-NoExit","-Command","cd '$root\apps\api'; node --env-file-if-exists=.env dist/main.js"
)

Write-Host "    Attente des services (santé)..." -ForegroundColor DarkGray
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 750
  try {
    $a = Invoke-RestMethod "http://localhost:3000/health" -TimeoutSec 2
    $s = Invoke-RestMethod "http://localhost:3001/v1/score/health" -TimeoutSec 2
    if ($a.status -eq "ok" -and $s.status -eq "ok") { $ok = $true; break }
  } catch { }
}
if (-not $ok) {
  Write-Host "Les services ne répondent pas. Vérifie que Docker tourne et que le build est fait (pnpm build)." -ForegroundColor Yellow
  Write-Host "Astuce : depuis $root  ->  pnpm build" -ForegroundColor Yellow
}
else { Write-Host "    Services OK." -ForegroundColor Green }

Write-Host "==> 5/5  App Flutter : build RELEASE + serveur local (port 8080)..." -ForegroundColor Cyan
Set-Location "$root\apps\mobile"
# Build RELEASE (dart2js) plutôt que `flutter run -d chrome` (build DEBUG lié à UNE fenêtre Chrome,
# qui donne un écran blanc dans les autres navigateurs). Le release marche dans TOUS les navigateurs
# du PC. API locale par défaut (http://localhost:3000, cf. Env.apiBaseUrl) → aucun --dart-define.
Write-Host "    Compilation (env. 1 min la 1re fois)..." -ForegroundColor DarkGray
# --pwa-strategy=none : PAS de service worker en local. Sinon le navigateur (surtout Chrome, qui
# avait garde le SW de l'ancien `flutter run` debug) sert un shell perime en cache -> page blanche
# + chargement infini. Inutile en dev ; evite tout cache fantome entre deux builds.
# --dart-define API_BASE_URL : on force l'API LOCALE (localhost:3000). Indispensable car un build
# Netlify (qui pointe vers Railway) a pu ecraser build/web -> sinon "API injoignable" en local
# (Railway refuse l'origine localhost:8080 par CORS).
& $flutter build web --pwa-strategy=none --dart-define=API_BASE_URL=http://localhost:3000
if ($LASTEXITCODE -ne 0) {
  Write-Host "Echec du build Flutter web. Verifie l'installation Flutter (C:\flutter\bin)." -ForegroundColor Red
  exit 1
}
# Port fixe 8080 : requis comme origine JavaScript autorisee pour la connexion Google. Le serveur
# ouvre le navigateur tout seul et reste au premier plan (laisse cette fenetre ouverte).
node "$root\serve-web.mjs"
