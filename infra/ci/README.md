# infra/ci

Les workflows CI vivent dans `.github/workflows/` (seul emplacement lu par GitHub Actions).

- `ci.yml` — deux jobs : **backend** (TS : lint · typecheck · test · build) et
  **mobile** (Flutter : analyze · test). Le job backend est bloquant sur la logique de score.

Ce dossier est réservé aux scripts/outillage CI complémentaires (déploiement, etc.) à venir.
