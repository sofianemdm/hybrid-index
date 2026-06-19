# apps/mobile — HYBRID INDEX (Flutter)

App mobile iOS + Android (base unique). Gérée par `pub` (hors workspace pnpm).

> ⚠️ Nécessite le **SDK Flutter ≥ 3.22** (non installé sur la machine de scaffold ;
> l'app n'a donc pas encore été compilée/lancée ici).

## Démarrage
```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## Qualité
```bash
flutter analyze
flutter test
```

## Structure (cf. docs/architecture.md §1.2)
- `lib/core/` — thème, design tokens, http client, env
- `lib/data/` — client API généré (openapi.json), cache + outbox offline (Drift), repositories
- `lib/domain/` — entités, value objects (miroir des enums de `packages/contracts`)
- `lib/features/` — onboarding, home, wod, radar, league, rival, profile, explorer, share_card, settings, avatar
- `assets/sprites/` — avatars 2D en couches
