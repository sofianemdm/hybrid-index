# HYBRID INDEX — Lancer toute l'app en une commande (Windows PowerShell).
# Usage : clic droit > "Exécuter avec PowerShell", ou dans un terminal :  .\demarrer-app.ps1
#
# Démarre : Postgres + Redis (Docker) -> score-service (:3001) -> api (:3000) -> app Flutter (Chrome).
# Pré-requis déjà installés : Docker Desktop (baleine verte), Node, pnpm, Flutter (C:\flutter\bin).

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$flutter = "C:\flutter\bin\flutter.bat"

Write-Host "==> 1/4  Base de données (Docker : Postgres + Redis)..." -ForegroundColor Cyan
docker compose -f "$root\infra\docker-compose.yml" up -d postgres redis | Out-Null

Write-Host "==> 2/4  score-service (port 3001)..." -ForegroundColor Cyan
Start-Process -WindowStyle Minimized powershell -ArgumentList @(
  "-NoExit","-Command","cd '$root\apps\score-service'; node dist/main.js"
)

Write-Host "==> 3/4  api (port 3000)..." -ForegroundColor Cyan
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

Write-Host "==> 4/4  App Flutter dans Chrome (laisse cette fenêtre ouverte)..." -ForegroundColor Cyan
Set-Location "$root\apps\mobile"
& $flutter run -d chrome
