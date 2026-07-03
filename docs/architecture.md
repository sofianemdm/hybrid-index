# HYBRID INDEX — Architecture (v1)

> **Statut :** livrable de conception (pas de code d'implémentation).
> **Source de vérité :** `docs/cahier-des-charges.md` + `CLAUDE.md`. En cas de conflit, le cahier prime.
> **Portée :** MVP « thin slice » (Phase 1), avec préparation explicite des phases ultérieures.
> **Décisions imposées par l'humain appliquées telles quelles :** monorepo unique ; Service Score microservice **physiquement séparé** et **versionné** dès le MVP ; stack Flutter / NestJS / PostgreSQL / Redis ; auth email + Apple + Google ; FCM ; PostHog ; Sentry ; logging hors-ligne ; âge minimum 15 ans ; champ `visibility` prévu ; RGPD export + suppression.

---

## 0. Principes directeurs (rappel doctrine)

1. **Simplicité d'abord.** Deux services seulement au MVP : `api` (BFF/monolithe modulaire NestJS) + `score-service` (microservice). Pas de découpage prématuré en N microservices.
2. **Le score est sacré.** Toute la logique de notation (courbe `f`, poids, percentiles, bornes physiologiques) vit **uniquement** dans `score-service`, versionnée, testée à couverture élevée. L'`api` ne recopie jamais ces formules.
3. **Le score ne baisse jamais.** Garanti par le schéma (meilleur effort retenu, fenêtre de fraîcheur) + le versioning du scoring (recalcul = jamais de chute brutale affichée).
4. **Offline-first côté mobile.** Les salles ont un mauvais réseau : toute soumission de WOD passe par une file locale idempotente.
5. **Tout public au MVP, mais réversible.** Champ `visibility` présent partout dès le départ ; aucune logique ne suppose « public » en dur.

---

## 1. Structure du monorepo

### 1.1 Outillage retenu

| Besoin | Choix | Justification |
|---|---|---|
| Orchestration monorepo (JS/TS) | **pnpm workspaces** + **Turborepo** | pnpm = installs rapides + node_modules strict (évite les imports fantômes entre packages) ; Turborepo = cache de build/test/lint, tâches incrémentales. Pas de Nx (plus lourd, sur-ingénierie ici). |
| Langage backend | **TypeScript** (NestJS) partout | Une seule stack backend, contrats typés partagés. |
| Mobile | **Flutter** (Dart), géré hors workspace pnpm mais dans le même repo | Flutter a son propre gestionnaire (`pub`). Le dossier `apps/mobile` est ignoré par pnpm. |
| Contrats d'API partagés | Package `packages/contracts` (TS) = **source de vérité** des DTO/enums via **Zod** + types dérivés | Zod = validation runtime (entrées API + bornes physio) ET inférence de type statique. Un seul endroit pour décrire un DTO. |
| Génération de types Dart | **OpenAPI** émis par NestJS (`@nestjs/swagger`) → `openapi.json` → génération du client Dart | On ne partage pas le code TS avec Dart directement. On partage un **contrat OpenAPI** versionné, à partir duquel on génère un client Dart typé. Frontière de langage propre. |
| Lint/format | ESLint + Prettier (TS) ; `flutter analyze` + `dart format` (Dart) | Standard. |
| CI minimale | GitHub Actions : `lint → typecheck → test → build` (jobs séparés TS et Flutter), bloquants sur la logique de score | Conforme à la Definition of Done. |
| Conteneurs | Docker + docker-compose (Postgres, Redis, api, score-service) pour le dev local | Reproductibilité ; mêmes images en déploiement. |

> **Note types partagés Dart↔TS :** on évite toute « génération de types Dart depuis TS » directe (fragile). La frontière est l'**OpenAPI** produit par l'`api`. Les enums métier (attributs, types de WOD, rangs) sont définis **une fois** dans `packages/contracts`, exposés dans l'OpenAPI, puis régénérés côté Dart. Une seule source.

### 1.2 Arborescence

```
hybrid-index/
├─ apps/
│  ├─ mobile/                      # App Flutter (iOS + Android, base unique)
│  │  ├─ lib/
│  │  │  ├─ core/                  # thème, design tokens, http client, env
│  │  │  ├─ data/
│  │  │  │  ├─ api/                # client généré depuis openapi.json
│  │  │  │  ├─ local/              # SQLite/Drift : cache + outbox offline
│  │  │  │  └─ repositories/
│  │  │  ├─ domain/                # entités, value objects (mirroir des enums contrats)
│  │  │  ├─ features/              # onboarding, home, wod, radar, league, rival,
│  │  │  │                         # profile, explorer, share_card, settings, avatar
│  │  │  └─ main.dart
│  │  ├─ assets/sprites/           # avatars 2D en couches (corps/cheveux/barbe/cosmetics)
│  │  └─ pubspec.yaml
│  │
│  ├─ api/                         # NestJS — BFF / API publique mobile
│  │  ├─ src/
│  │  │  ├─ modules/               # voir §7 (auth, users, onboarding, wods, results,
│  │  │  │                         # index, attributes, leagues, rivals, social, ...)
│  │  │  ├─ infra/                 # prisma, redis, fcm, posthog, sentry, score-client
│  │  │  ├─ common/                # filtres d'erreur, guards, pipes (validation Zod)
│  │  │  └─ main.ts
│  │  ├─ prisma/                   # schema.prisma + migrations  (DB applicative)
│  │  └─ test/
│  │
│  └─ score-service/              # NestJS — MICROSERVICE Score (séparé, versionné)
│     ├─ src/
│     │  ├─ scoring/              # courbe f, poids, calcul sous-score / index / percentile
│     │  ├─ versions/            # registre des ScoringVersion (f, poids, statut)
│     │  ├─ recompute/           # jobs de recalcul historique versionné
│     │  ├─ distributions/       # accès ReferenceDistribution + percentiles communautaires
│     │  └─ main.ts
│     ├─ prisma/                  # accès lecture/écriture aux tables de scoring (cf. §3)
│     └─ test/                    # COUVERTURE ÉLEVÉE (logique de score)
│
├─ packages/
│  ├─ contracts/                  # DTO (Zod) + enums métier + codes d'erreur + schémas OpenAPI
│  │  └─ src/
│  │     ├─ enums/                # AttributeKey, WodType, ScoreType, Rank, EquipmentPref...
│  │     ├─ dto/                  # tous les payloads/réponses API publique
│  │     ├─ internal/             # contrats internes api <-> score-service (/v1/score/*)
│  │     └─ errors/               # ErrorCode + ApiError standard
│  ├─ scoring-core/               # (optionnel) logique pure de f/poids réutilisable + testable,
│  │                              # importée par score-service uniquement
│  └─ config/                     # eslint, tsconfig base, prettier partagés
│
├─ infra/
│  ├─ docker/                     # Dockerfiles api, score-service
│  ├─ docker-compose.yml          # postgres + redis + api + score-service (dev)
│  └─ ci/                         # workflows GitHub Actions
│
└─ docs/
   ├─ cahier-des-charges.md       # SOURCE DE VÉRITÉ
   ├─ architecture.md             # CE FICHIER
   └─ architecture/               # ADRs courts à venir (contexte/décision/conséquences)
```

**Frontières (qui peut importer quoi) :**
- `apps/mobile` ne connaît que l'OpenAPI de `api`. Jamais `score-service` directement.
- `apps/api` importe `packages/contracts`. Il appelle `score-service` via HTTP (contrat `internal`).
- `apps/score-service` importe `packages/contracts/internal` + `packages/scoring-core`. Il ne dépend **jamais** de l'`api`.
- `packages/scoring-core` est pur (aucune dépendance infra) → testable en isolation = exigence DoD sur le score.

---

## 2. Vue des composants & flux

```
                         ┌─────────────────────────────────────────────┐
                         │              APP MOBILE (Flutter)            │
                         │  features + repos + Outbox locale (SQLite)   │
                         └───────────────┬─────────────────────────────┘
                                         │ HTTPS REST (OpenAPI v1)
                                         │ + JWT  + Idempotency-Key
                                         ▼
        PostHog ◄────────────┐   ┌───────────────────────────────────┐   ┌────────► Sentry
        (analytics)          │   │        API / BFF  (NestJS)         │   │          (erreurs)
                             └───┤  auth · onboarding · wods · results│───┘
                                 │  index · leagues · rivals · social │
                                 │  share · settings/RGPD · notifs    │
                                 └───┬───────────┬───────────┬────────┘
                  internal REST      │           │           │
                  /v1/score/*  ──────┘           │           │ pub
        ┌────────────────────────────┐          │           ▼
        │   SCORE-SERVICE (NestJS)    │          │      ┌─────────┐
        │   microservice VERSIONNÉ    │          │      │   FCM   │ push notifs
        │   - sous-score d'un effort  │          │      └─────────┘
        │   - Hybrid Index + radar    │          │
        │   - percentile / projection │          ▼
        │   - recalcul historique     │     ┌─────────┐    ┌──────────────────────┐
        └──────────┬─────────────────┘     │  REDIS  │    │  Card Render Service  │
                   │                        │ sorted  │    │  (templates → image)  │
                   │ lecture/écriture        │  sets   │    │  Phase 1: lib in-api  │
                   ▼  scoring tables         │ + cache │    │  Phase 2: worker sép. │
            ┌──────────────┐                 └────┬────┘    └──────────────────────┘
            │  PostgreSQL  │◄────────────────────┘
            │ (DB unique,  │   classements (Index H/F + 15 WOD), cache, sessions, idempotence
            │  schémas     │
            │  séparés)    │
            └──────────────┘
```

### 2.1 Rôle de chaque composant

| Composant | Rôle | MVP ? |
|---|---|---|
| **Mobile Flutter** | UI, onboarding, saisie WOD, reveal, radar, ligues, rival, partage. Contient l'**Outbox** offline. | Oui |
| **API / BFF (NestJS)** | Seul point d'entrée du mobile. Auth, CRUD métier, orchestration, écriture des classements Redis, déclenchement notifs, RGPD. Appelle le score-service pour tout calcul. | Oui |
| **Score-service (NestJS)** | **Toute** la notation : sous-score d'un effort, agrégation radar, Hybrid Index, percentile, Index projeté, recalcul historique. Versionné. Aucune logique métier social. | Oui |
| **PostgreSQL** | Persistance durable. **Schémas logiques séparés** : `app` (entités produit, propriété de l'`api`) et `scoring` (distributions, sous-scores, versions, propriété du score-service). Une seule instance, deux frontières de propriété. | Oui |
| **Redis** | (a) classements via **sorted sets** (2 ligues + 15 WOD) ; (b) cache de lecture (radar, percentiles) ; (c) sessions/refresh ; (d) clés d'idempotence. | Oui |
| **FCM** | Push (rival, séance, récap). Plafonné, configurable. | Oui (notifs basiques) |
| **PostHog** | Funnels, rétention, cohortes. Événements clés (reveal, log WOD, rival battu). | Oui |
| **Sentry** | Erreurs + traces api & score-service & mobile. | Oui |
| **Card Render Service** | Génère les cartes partageables (reveal/PR/rang/percentile). **MVP : bibliothèque de rendu in-process dans l'api** (templates → PNG). Extrait en worker séparé en Phase 2 si charge. | MVP minimal |

### 2.2 Frontière interne API ↔ score-service

- Communication **REST interne synchrone**, réseau privé, **versionnée** sous `/v1/score/...`.
- Le contrat est défini dans `packages/contracts/internal` (Zod + OpenAPI interne).
- Le score-service est **stateless pour le calcul d'un effort** mais **stateful pour les versions** (il possède le registre `scoring_version` et les tables `scoring`).
- L'`api` ne stocke jamais de formule. Elle envoie un effort brut + contexte (sexe, wodId, objectif) et reçoit un résultat noté + la `scoringVersionId` utilisée.
- Pour les recalculs historiques, l'`api` **n'orchestre pas** : elle déclenche (`POST /v1/score/recompute`) et le score-service mène le job en tâche de fond, puis publie les nouveaux scores que l'`api` lit.

---

## 3. Modèle de données (PostgreSQL)

Conventions : `snake_case`, PK `uuid` (v7 si dispo, sinon v4) sauf tables de référence à id court ; `created_at`/`updated_at` (timestamptz) partout ; soft-delete via `deleted_at` uniquement là où le RGPD l'exige. **Deux schémas :** `app.*` (propriété api) et `scoring.*` (propriété score-service).

### 3.1 Enums (Postgres `ENUM` ou tables de référence)

```
sex                : 'male' | 'female'
equipment_pref     : 'none' | 'equipped' | 'both'
goal               : 'hyrox' | 'crossfit_strength' | 'all_round'
attribute_key      : 'engine' | 'speed' | 'strength' | 'power' | 'muscular_endurance' | 'hybrid'
wod_type           : 'for_time' | 'amrap' | 'emom' | 'chipper' | 'strength' | 'interval'
score_type         : 'time' | 'reps' | 'load' | 'distance'
result_source      : 'declared' | 'verified'          -- 'verified' = Phase 3, champ prêt
visibility         : 'public' | 'private'              -- 'public' partout au MVP
rank               : 'rookie'|'bronze'|'silver'|'gold'|'platinum'|'diamond'|'elite'
distribution_source: 'public' | 'community'
challenge_status   : 'pending' | 'accepted' | 'completed' | 'expired' | 'declined'
reaction_target    : 'wod_result' | 'badge' | 'rank_up'
badge_category     : 'progression' | 'collection' | 'performance' | 'consistency' | 'social'
result_review      : 'ok' | 'pending_review' | 'rejected'   -- anti-triche §5.5
scoring_status     : 'draft' | 'active' | 'superseded'
```

### 3.2 Schéma `app.*` (propriété de l'API)

#### `app.user`
| Colonne | Type | Notes |
|---|---|---|
| id | uuid PK | |
| email | citext UNIQUE NULL | null si compte uniquement Apple/Google sans email partagé |
| password_hash | text NULL | argon2id ; null si OAuth pur |
| date_of_birth | date NOT NULL | **age-gating ≥ 15 ans** (contrainte applicative + check sur âge) |
| age_verified | boolean NOT NULL default false | confirmé à l'inscription |
| consents | jsonb NOT NULL | RGPD : `{publicProfile, analytics, marketing, acceptedAt, version}` |
| status | text default 'active' | 'active' \| 'deactivated' \| 'deletion_requested' |
| deletion_requested_at | timestamptz NULL | RGPD suppression (purge différée) |
| created_at / updated_at | timestamptz | |

Index : `unique(email)`. Contrainte : `CHECK (date_of_birth <= now() - interval '13 years')`.

#### `app.auth_identity` (multi-provider)
| Colonne | Type | Notes |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK → user | |
| provider | text | 'email' \| 'apple' \| 'google' |
| provider_subject | text | sub OAuth / email |
| created_at | timestamptz | |

Index : `unique(provider, provider_subject)`.

#### `app.avatar`
| Colonne | Type | Notes |
|---|---|---|
| user_id | uuid PK FK → user | 1–1 |
| skin_tone | smallint | index de palette |
| hair_style / hair_color | smallint | |
| beard_style | smallint NULL | masquable |
| equipped_cosmetics | jsonb | `{frame, aura, outfit, accessory}` (slots) |
| unlocked_cosmetics | jsonb | tableau d'ids débloqués (paliers/badges) |
| updated_at | timestamptz | |

> `sex` n'est **pas** sur l'avatar : il est sur le profile (normalisation du score = §3.2 `profile.sex`). On évite la duplication.

#### `app.profile` (public)
| Colonne | Type | Notes |
|---|---|---|
| user_id | uuid PK FK → user | 1–1 |
| display_name | citext UNIQUE | |
| sex | sex NOT NULL | **normalisation du score** (verrouillé après choix : impacte tous les percentiles) |
| goal | goal NOT NULL | pondération de l'Index |
| equipment_pref | equipment_pref NOT NULL | préremplit la saisie WOD |
| rank | rank NOT NULL default 'rookie' | dénormalisé depuis l'Index (lecture rapide hub) |
| visibility | visibility NOT NULL default 'public' | **prêt pour plus tard**, public au MVP |
| city | text NULL | pas de localisation précise (§18) |
| created_at / updated_at | timestamptz | |

Index : `unique(display_name)`, `index(sex)` (filtres Explorer), `index(rank)`.

#### `scoring`-adjacent côté lecture : `app.hybrid_index` (état courant, dénormalisé pour le hub)
| Colonne | Type | Notes |
|---|---|---|
| user_id | uuid PK FK → user | état **courant** uniquement |
| value | integer | 0–1000, source de classement |
| percentile | numeric(5,4) | par sexe |
| is_provisional | boolean | couverture < seuil |
| is_estimated | boolean | au moins un effort estimé (ex. Force proxy) |
| radar_coverage | smallint | nb attributs débloqués (0–6) |
| projected_value | integer NULL | Index projeté (ciblage d'axe) |
| confidence_level | text | 'public_data' \| 'community' |
| scoring_version_id | uuid FK → scoring.scoring_version | version ayant produit cet état |
| computed_at | timestamptz | |

Index : `index(value DESC)` (fallback SQL des classements si Redis indispo).

> L'historique de l'Index est en `scoring.hybrid_index_history` (cf. §3.3) car il est produit et versionné par le score-service.

#### `app.attribute_score` (état courant par attribut)
| Colonne | Type | Notes |
|---|---|---|
| user_id | uuid FK → user | |
| attribute | attribute_key | |
| score | integer | 0–1000, **meilleur effort dans la fenêtre de fraîcheur** |
| percentile | numeric(5,4) | par sexe |
| unlocked | boolean | ≥1 effort qualifiant |
| is_estimated | boolean | true pour Force sans matériel (proxy) |
| is_stale | boolean | meilleur effort > seuil de fraîcheur (8–12 sem.) |
| best_result_id | uuid FK → app.wod_result NULL | l'effort qui DÉTIENT le score courant |
| scoring_version_id | uuid FK → scoring.scoring_version | |
| last_updated | timestamptz | |

PK composite `(user_id, attribute)`. Index `(attribute, score DESC)`.

#### `app.wod` (référentiel des 15 + custom plus tard)
| Colonne | Type | Notes |
|---|---|---|
| id | text PK | slug stable, ex. `benchmark_zero`, `fran` |
| name | text | |
| is_benchmark | boolean | true pour les 15 |
| is_custom | boolean default false | **custom = Phase 2** |
| type | wod_type | |
| requires_equipment | boolean | filtre matériel |
| target_attributes | attribute_key[] | tags |
| score_type | score_type | time/reps/load/distance |
| movements | jsonb | `[{movement, reps, loadMale?, loadFemale?, isBodyweight}]` |
| created_at | timestamptz | |

Index `index(requires_equipment)`, `index using gin(target_attributes)`.

#### `app.wod_result` (efforts logués)
| Colonne | Type | Notes |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK → user | |
| wod_id | text FK → wod | |
| sex | sex | figé au moment de l'effort (sécurise le percentile historique) |
| raw_result | numeric | valeur selon score_type (secondes / reps / kg / mètres) |
| sub_score | integer NULL | 0–1000, **calculé par score-service** (null tant que non noté) |
| percentile | numeric(5,4) NULL | par sexe |
| attributes_affected | attribute_key[] | tags effectivement impactés |
| source | result_source default 'declared' | 'verified' = Phase 3 |
| review | result_review default 'ok' | anti-triche : 'pending_review'/'rejected' → exclu classements |
| scoring_version_id | uuid FK → scoring.scoring_version NULL | version ayant noté |
| idempotency_key | text NULL | dédoublonnage offline (cf. §6) |
| visibility | visibility default 'public' | |
| performed_at | timestamptz NOT NULL | date réelle de l'effort (≠ création) |
| created_at | timestamptz | |

Index clés :
- `unique(user_id, idempotency_key)` (idempotence des soumissions offline).
- `index(wod_id, sex, sub_score DESC) WHERE review = 'ok'` → classement par WOD + exclusion triche.
- `index(user_id, wod_id, performed_at DESC)` → historique, détection d'anomalie (saut de perf).
- `index(user_id, performed_at DESC)` → fraîcheur, garde-fou surentraînement.

**« Meilleur effort dans la fenêtre de fraîcheur (26 sem.) » + « le score ne baisse jamais » :**
- `attribute_score.score` n'est jamais recalculé « vers le bas » à partir d'un mauvais effort. À chaque nouvel effort noté pour l'attribut `A`, le score-service calcule :
  ```sql
  -- candidat = meilleur sub_score parmi efforts taguant A, performed_at > now() - 26 semaines, review='ok'
  SELECT MAX(sub_score) FROM app.wod_result
   WHERE user_id = :u AND :A = ANY(attributes_affected)
     AND performed_at > now() - interval '26 weeks'
     AND review = 'ok';
  ```
- On **met à jour `attribute_score` uniquement si** `candidat > score_courant` **OU** si l'effort qui détenait le score (`best_result_id`) est sorti de la fenêtre. Si l'ancien meilleur sort de la fenêtre et qu'aucun effort récent ne l'égale, le score peut redescendre **mais jamais sous un mauvais jour ponctuel** : on retient toujours le meilleur effort encore frais. C'est une décroissance par **péremption**, pas par **punition** — conforme §5.4 (et `is_stale` invite à re-tester avant péremption).
- Garder `best_result_id` permet de détecter immédiatement la sortie de fenêtre sans rescanner tout l'historique.

#### `app.league` (référence : 2 lignes)
| id | sex | label |
|---|---|---|
| `men` | male | Ligue Hommes |
| `women` | female | Ligue Femmes |

Le classement vit dans Redis (cf. §3.5) ; cette table sert de référentiel stable. Pas de table d'appartenance : la ligue se déduit de `profile.sex`.

#### `app.rival`
| Colonne | Type | Notes |
|---|---|---|
| user_id | uuid PK FK → user | |
| rival_user_id | uuid FK → user NULL | null si n°1 ou < 2 actifs |
| rival_index_value | integer NULL | snapshot pour l'affichage « +7 pts » |
| state | text | 'active' \| 'leader' \| 'insufficient_pool' |
| recomputed_at | timestamptz | |

Calcul du rival (§11.4) sans table coûteuse : requête sur Redis sorted set par ligue (zrangebyscore juste au-dessus du score user) **filtrée par activité**. L'« actif » (≥1 effort dans 30 j) est maintenu via :
- index `index(user_id, performed_at DESC)` sur `wod_result`, **ou**
- un set Redis `active:{sex}` (TTL glissant 30 j) alimenté à chaque log → permet `ZINTERSTORE` activité × classement. Retenu pour la perf.

#### `app.challenge` (Phase 2, schéma prêt)
| id | from_user | to_user | wod_id | status (challenge_status) | invite_token | created_at | expires_at |

`results` n'est pas une colonne jsonb : table fille `app.challenge_result(challenge_id, user_id, wod_result_id)`. Index `unique(invite_token)`.

#### `app.reaction` (Phase 2)
| id | from_user | target_type (reaction_target) | target_id | emoji | created_at |
Index `unique(from_user, target_type, target_id, emoji)`.

#### `app.badge` (référentiel)
| id | category (badge_category) | condition | rarity | cosmetic_unlock | created_at |

#### `app.user_badge`
| user_id | badge_id | unlocked_at | PK(user_id, badge_id) |

#### `app.follow`
| follower_id | followee_id | created_at | PK(follower_id, followee_id) |
Index `index(followee_id)` (qui me suit), `index(follower_id, created_at)` (feed).

#### `app.notification_prefs`
| user_id PK | prefs jsonb (`{ rivalPassed:bool, ... }`) | quiet_hours jsonb (`{start,end,tz}`) | updated_at |

### 3.3 Schéma `scoring.*` (propriété du score-service — VERSIONNÉ)

#### `scoring.scoring_version` ⭐
| Colonne | Type | Notes |
|---|---|---|
| id | uuid PK | |
| semver | text | ex. `1.0.0` |
| status | scoring_status | 'draft' \| 'active' \| 'superseded' |
| f_params | jsonb | paramètres de la courbe `f` (forme sigmoïde, médiane cible 450, etc.) |
| attribute_weights | jsonb | poids `w_A` par objectif (hyrox/crossfit/all_round) |
| freshness_weeks | smallint default 26 | fenêtre de fraîcheur |
| notes | text | |
| activated_at | timestamptz NULL | |
| created_at | timestamptz | |

**Une seule version `active` à la fois.** C'est la version « courante » pour tout nouveau calcul.

#### `scoring.reference_distribution`
| Colonne | Type | Notes |
|---|---|---|
| id | uuid PK | |
| wod_id | text | (réf logique vers app.wod ; pas de FK cross-schema stricte) |
| sex | sex | |
| source | distribution_source | 'public' \| 'community' |
| n | integer | taille échantillon (cold-start) |
| percentile_curve | jsonb | mapping résultat→percentile (points/spline) |
| pro_reference | numeric | niveau élite (cible « bats le pro ») |
| scoring_version_id | uuid FK | distribution rattachée à une version |
| computed_at | timestamptz | |

Index `unique(wod_id, sex, scoring_version_id)`.

#### `scoring.hybrid_index_history` ⭐ (versionné)
| Colonne | Type | Notes |
|---|---|---|
| id | uuid PK | |
| user_id | uuid | |
| value | integer | |
| percentile | numeric(5,4) | |
| scoring_version_id | uuid FK | **version ayant produit ce point** |
| reason | text | 'wod_logged' \| 'recompute' \| 'projection' |
| computed_at | timestamptz | |

Index `index(user_id, computed_at)`. C'est la courbe affichée (écran Détail de l'Index, §17 #7).

#### `scoring.recompute_job` (audit des recalculs)
| id | from_version | to_version | status | total_users | processed | started_at | finished_at |

> **Ce qui est versionné côté score :** `scoring_version` (f + poids + fenêtre), `reference_distribution`, et toute valeur dérivée porte une `scoring_version_id` : `app.wod_result.sub_score`, `app.attribute_score.score`, `app.hybrid_index`, `scoring.hybrid_index_history`. On peut donc savoir **avec quelle version** chaque score affiché a été calculé, et recalculer proprement.

### 3.4 MVP vs préparé pour plus tard

| Élément | MVP | Plus tard |
|---|---|---|
| `wod.is_custom`, WOD custom | colonne présente, valeur false | Phase 2 (estimation de difficulté) |
| `result_source = 'verified'` | colonne présente, toujours 'declared' | Phase 3 (montres/officiel) |
| `visibility` | présent, toujours 'public' | passage privé réversible |
| `challenge`, `reaction`, `badge`/`user_badge` (complet) | tables créées (migrations prêtes) mais endpoints partiels | Phase 2 |
| box/amis | aucune table (déduit de follow + ligue) | après 200 users |
| `community` distributions | colonne `source` + `n` prêts | recalcul dès n ≥ seuil |

---

## 4. Contrats d'API

### 4.1 Conventions transverses
- Base : `https://api.hybridindex.app/v1` (versionnée dans l'URL).
- Auth : `Authorization: Bearer <jwt access>` (15 min) + refresh token (rotation, stocké côté Redis).
- Idempotence : header `Idempotency-Key: <uuid>` **obligatoire** sur `POST /results` (et défis).
- Pagination : `?cursor=&limit=` (curseur opaque) ; jamais d'offset sur les classements.
- **Format d'erreur standard** (défini dans `packages/contracts/errors`) :
  ```json
  {
    "error": {
      "code": "WOD_RESULT_OUT_OF_BOUNDS",
      "message": "Résultat hors plage plausible.",
      "details": { "field": "rawResult", "min": 90, "max": 1800 },
      "traceId": "..."
    }
  }
  ```
- **Codes d'erreur** (extrait) : `VALIDATION_ERROR` (400), `UNAUTHENTICATED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404), `IDEMPOTENT_REPLAY` (200, renvoie la 1re réponse), `CONFLICT` (409), `WOD_RESULT_OUT_OF_BOUNDS` (422), `WOD_RESULT_ANOMALY` (422, accepté mais flaggé), `SCORE_SERVICE_UNAVAILABLE` (503, résultat stocké, score en attente), `AGE_RESTRICTED` (403), `RATE_LIMITED` (429).

### 4.2 Validation des entrées + bornes physiologiques (anti-triche §5.5)
- **Toute** entrée validée par schéma Zod (`packages/contracts/dto`) dans un `ZodValidationPipe` NestJS.
- Sur soumission d'un résultat, l'`api` applique d'abord les **bornes physiologiques** (par `wod_id` + `sex`, ex. 2000 m row ∈ [5:30, 12:00] H) :
  - hors bornes → `WOD_RESULT_OUT_OF_BOUNDS` (422), résultat **non enregistré**.
  - dans bornes mais **saut anormal** (ex. +30 % en 7 j vs historique) → enregistré avec `review='pending_review'` → noté pour l'utilisateur **mais exclu des classements** (filtre `WHERE review='ok'`).
- Les bornes vivent dans `score-service` (proches des distributions) et sont exposées à l'`api` via `/v1/score/validate` (ou embarquées en config lue au boot). Une seule source de vérité physiologique.

### 4.3 API publique (mobile) — endpoints MVP

#### Auth
| Méthode | Chemin | Entrée | Réponse | Erreurs |
|---|---|---|---|---|
| POST | `/auth/register` | `{email, password, dateOfBirth, consents}` | `{tokens, user}` | `AGE_RESTRICTED`, `CONFLICT`(email), `VALIDATION_ERROR` |
| POST | `/auth/login` | `{email, password}` | `{tokens}` | `UNAUTHENTICATED` |
| POST | `/auth/oauth/:provider` | `{idToken}` (apple/google) | `{tokens, isNew}` | `UNAUTHENTICATED`, `AGE_RESTRICTED` |
| POST | `/auth/refresh` | `{refreshToken}` | `{tokens}` | `UNAUTHENTICATED` |
| POST | `/auth/logout` | — | 204 | |

> Age-gating : si OAuth et `dateOfBirth` inconnue, écran complémentaire qui appelle `PATCH /me/birthdate` ; refus si < 15 ans.

#### Onboarding & avatar
| Méthode | Chemin | Entrée | Réponse |
|---|---|---|---|
| POST | `/onboarding/avatar` | `{skinTone, hairStyle, hairColor, beardStyle?}` | `{avatar}` |
| POST | `/onboarding/profile` | `{displayName, sex, goal, equipmentPref}` | `{profile}` |
| POST | `/onboarding/estimate` | `{runs?:[{distanceKm,seconds}], selfAssessment?:{runLevel,maxPushups,experience}}` | `{hybridIndex (provisional, estimated)}` |
| GET | `/onboarding/reveal` | — | `{hybridIndex, radar, rankInfo}` |
| GET | `/avatar` / PATCH `/avatar` | apparence + cosmétiques équipés | `{avatar}` |

#### Résultats de WOD (cœur)
| Méthode | Chemin | Entrée (DTO) | Réponse | Erreurs |
|---|---|---|---|---|
| GET | `/wods` | `?equipment=&attribute=` | `[WodSummary]` | |
| GET | `/wods/:id` | — | `WodDetail` | `NOT_FOUND` |
| POST | `/wods/:id/results` | header `Idempotency-Key` ; `{rawResult, movements?, performedAt, visibility?}` | `WodResultScored {subScore, percentile, proReference, attributesAffected, indexDelta, rivalDelta, badges[]}` | `OUT_OF_BOUNDS`, `ANOMALY`, `SCORE_SERVICE_UNAVAILABLE`(503 → `{resultId, status:'pending'}`), `IDEMPOTENT_REPLAY` |
| GET | `/me/results` | `?wodId=&cursor=` | `[WodResult]` | |

#### Index & radar
| GET | `/me/index` | `{value, percentile, isProvisional, isEstimated, rank, projectedValue?}` |
| GET | `/me/index/history` | `?from=&to=` → `[{value, computedAt}]` |
| GET | `/me/radar` | `[{attribute, score, percentile, unlocked, isEstimated, isStale}]` |
| POST | `/me/index/projection` | `{attribute, targetScore}` → `{projectedIndex, projectedRank}` (ciblage d'axe) |

#### Ligues & classements
| GET | `/leagues/:sex` | `?cursor=` → `{entries:[{rank, user, indexValue}], me:{rank,...}}` |
| GET | `/wods/:id/leaderboard` | `?sex=&cursor=` → classement par WOD (review='ok' uniquement) |

#### Rival
| GET | `/me/rival` | `{state, rival?:{user, indexValue, gap}}` |
| POST | `/me/rival/recompute` | — → recalcul forcé (sinon auto à chaque variation + 1×/j) |

#### Profils publics, Explorer, comparaison
| GET | `/profiles/:userId` | profil public (Index, radar, historique, badges) ; respecte `visibility` |
| GET | `/explore` | `?sex=&rank=&equipment=&cursor=` → liste d'athlètes |
| GET | `/feed` | activité des suivis (`?cursor=`) |
| POST | `/follow/:userId` / DELETE | 204 |
| GET | `/compare?a=&b=` | radars + index superposés |

#### Cartes de partage
| POST | `/share-cards` | `{type:'reveal'|'pr'|'rank_up'|'percentile'|'beat_pro', refId}` → `{imageUrl, deeplink}` |

#### Réglages & RGPD
| PATCH | `/settings/equipment` `/settings/visibility` | préférences |
| GET | `/me/notification-prefs` / PATCH | prefs + quiet hours |
| POST | `/me/data-export` | déclenche export → `{jobId}` puis `GET /me/data-export/:jobId` → fichier |
| DELETE | `/me` | suppression compte (RGPD) → `deletion_requested_at`, purge différée |
| POST | `/devices` | enregistrement token FCM |

### 4.4 API INTERNE `api ↔ score-service` (`/v1/score/...`, réseau privé)

| Méthode | Chemin | Entrée | Réponse |
|---|---|---|---|
| POST | `/v1/score/effort` | `{userId, wodId, sex, scoreType, rawResult, attributes[], goal}` | `{subScore, percentile, proReference, scoringVersionId}` |
| POST | `/v1/score/validate` | `{wodId, sex, rawResult, recentResults[]}` | `{withinBounds, anomaly, bounds:{min,max}}` |
| POST | `/v1/score/index` | `{userId, sex, goal, attributeScores[]}` | `{value, percentile, isProvisional, radarCoverage, scoringVersionId}` |
| POST | `/v1/score/projection` | `{userId, sex, goal, attributeScores[], targetAttribute, targetScore}` | `{projectedIndex}` |
| GET | `/v1/score/version/active` | — | `{scoringVersion}` |
| POST | `/v1/score/recompute` | `{toVersionId, scope?}` | `{jobId}` (async) |
| GET | `/v1/score/recompute/:jobId` | — | `{status, processed, total}` |

> Toutes les réponses internes renvoient la `scoringVersionId` ; l'`api` la persiste sur la ligne concernée.

---

## 5. Stratégie de versioning du Service Score

### 5.1 Cycle de vie d'une version
1. Une nouvelle `scoring_version` (nouvelle courbe `f` ou nouveaux poids ou recalibration communautaire des distributions) est créée en `status='draft'`.
2. Les `reference_distribution` sont attachées à cette version.
3. Validation hors-ligne sur un échantillon (tests + comparaison de distribution des deltas).
4. Lancement d'un **recompute job** (`POST /v1/score/recompute {toVersionId}`).

### 5.2 Recalcul historique sans chute brutale (« le score ne baisse jamais »)
- Le recompute recalcule, pour chaque utilisateur : tous les `sub_score` des `wod_result` encore dans la fenêtre, puis `attribute_score`, puis `hybrid_index`, en marquant tout avec la nouvelle `scoring_version_id`.
- **Garde-fou anti-chute affichée :** le score-service applique une règle de transition. La valeur affichée après migration est :
  ```
  displayed_new = max(value_new_version, value_old_version)        // option "no-drop dur"
        ou       lissage(value_old, value_new) sur K jours          // option "ramp"
  ```
  Décision MVP retenue : **no-drop dur sur l'Index global** (on ne fait jamais baisser l'Index affiché d'un utilisateur du fait d'un changement de formule). Les attributs individuels peuvent bouger ; l'Index reste le `max`. Le `hybrid_index_history` enregistre la vraie valeur `value_new_version` **plus** un champ implicite via `reason='recompute'`, et l'état courant `app.hybrid_index.value` applique le `max`. Ceci respecte §3.6 du cahier (« le score ne baisse jamais brutalement ») tout en gardant la traçabilité réelle.
- Le recompute est **idempotent** et **repris** par lots (`recompute_job.processed`) : tolérant aux pannes, exécuté en tâche de fond, sans interrompre le service.

### 5.3 Où vit la version
- Registre unique : `scoring.scoring_version`, propriété du score-service.
- L'`api` ne connaît qu'un id opaque (`scoringVersionId`) qu'elle stocke et n'interprète pas.
- Chaque valeur dérivée référence sa version (cf. §3.3). On peut donc auditer « ce sub_score a été calculé avec 1.2.0 » et recalculer sélectivement.

---

## 6. Synchronisation hors-ligne (mobile)

### 6.1 File locale (Outbox)
- Stockage local **SQLite (Drift)** dans `apps/mobile/lib/data/local`.
- Table `outbox`:
  ```
  outbox(
    local_id        TEXT PK,            -- uuid généré sur l'appareil
    idempotency_key TEXT NOT NULL,      -- = local_id (stable, réutilisé aux retries)
    endpoint        TEXT NOT NULL,      -- ex. POST /wods/fran/results
    payload         TEXT NOT NULL,      -- JSON
    status          TEXT NOT NULL,      -- 'pending'|'sent'|'acked'|'failed'
    attempts        INTEGER DEFAULT 0,
    created_at      INTEGER,            -- epoch
    last_error      TEXT
  )
  ```
- L'utilisateur log un WOD hors-ligne → écriture immédiate dans `outbox` + mise à jour optimiste de l'UI (score « en attente de calcul »).

### 6.2 Idempotence
- `idempotency_key` (= `local_id`) envoyé en header sur **chaque** tentative.
- Côté serveur : `unique(user_id, idempotency_key)` sur `wod_result`. Si rejouée → réponse `IDEMPOTENT_REPLAY` renvoyant le résultat déjà noté (clé+réponse mises en cache Redis 24 h). Aucune double-écriture, aucun double-score.

### 6.3 Synchro & résolution de conflits
- Un worker Flutter (connectivité retrouvée) draine l'outbox FIFO par `created_at`, avec backoff exponentiel.
- `performed_at` est l'horodatage **réel de l'effort** (pas l'heure d'envoi) → l'ordre chronologique et la fenêtre de fraîcheur restent corrects même après synchro différée.
- Conflits : la notation est **commutative** par rapport au « meilleur effort retenu ». Que les efforts arrivent dans le désordre ne change pas le résultat final (on garde le max dans la fenêtre). Donc **pas de résolution de conflit complexe** : l'idempotence suffit pour éviter les doublons, et la règle « meilleur effort » rend l'ordre indifférent. C'est un choix de simplicité délibéré.
- Lecture hors-ligne : le hub, le radar et le dernier WOD sont servis depuis le **cache local** (snapshot du dernier `GET /me/...`) avec bannière « hors-ligne ».

---

## 7. Découpage en modules NestJS

### 7.1 `apps/api` — modules
| Module | Responsabilité | MVP (Phase 1) ? |
|---|---|---|
| `AuthModule` | email + Apple + Google, JWT, refresh (Redis), age-gating | **Oui** |
| `UsersModule` | user, profile, avatar, RGPD (export/suppression) | **Oui** |
| `OnboardingModule` | flux avatar→objectif→matériel→estimation→reveal | **Oui** |
| `WodsModule` | référentiel des 15 WODs + lecture | **Oui** |
| `ResultsModule` | soumission, idempotence, bornes physio, appel score-service | **Oui** (cœur) |
| `IndexModule` | lecture Index/radar, historique, projection | **Oui** |
| `LeaguesModule` | classements Redis (2 ligues + 15 WOD) | **Oui** |
| `RivalModule` | calcul rival + recompute | **Oui** |
| `SocialModule` | profils publics, explore, feed, follow, compare | **Oui** (lecture) |
| `ShareModule` | cartes partageables (rendu in-process) | **Oui** (minimal) |
| `NotificationsModule` | FCM, prefs, quiet hours | **Oui** (rival/séance basiques) |
| `ScoreClientModule` | client HTTP typé vers score-service (contrat interne) | **Oui** |
| `RecommendationModule` | reco par règles, ciblage d'axe | **Oui** (ciblage d'axe + Index projeté requis Phase 1) |
| `ChallengesModule` | défis | Phase 2 |
| `ReactionsModule` | kudos | Phase 2 |
| `BadgesModule` | badges & trophées complets | Phase 2 (déblocages de base au MVP) |
| `BoxModule` | classement box/amis | Après 200 users |

Modules infra (transverses) : `PrismaModule`, `RedisModule`, `PostHogModule`, `SentryModule`, `ConfigModule`.

### 7.2 `apps/score-service` — modules
| Module | Responsabilité | MVP ? |
|---|---|---|
| `ScoringModule` | sous-score (f), agrégation radar, Hybrid Index, percentile, projection | **Oui** |
| `VersionsModule` | registre `scoring_version`, version active | **Oui** |
| `DistributionsModule` | distributions de référence, percentiles, bornes physio, pro reference | **Oui** |
| `RecomputeModule` | recalcul historique versionné (jobs par lots, no-drop) | **Oui** (mécanisme prêt même si peu utilisé en Phase 1) |

### 7.3 Thin slice Phase 1 (chemin critique minimal)
Onboarding (avatar + matériel + course/estimation + reveal) → log d'un WOD parmi les 15 (Benchmark Zéro / PFT en mode guidé) → notation par score-service → radar + Index (Force proxy + confiance) → ciblage d'axe + Index projeté → 2 ligues H/F + rival → profils publics + Explorer → cartes partageables → logging hors-ligne → réglages RGPD de base.
**Reporté :** WODs custom, kudos, défis, badges complets, box/amis, vérification (source verified), commentaires, Card Render en worker séparé.

---

## Annexe A — Redis : clés & stratégie de cache

| Usage | Structure | Clé | Notes |
|---|---|---|---|
| Ligue par sexe | Sorted Set | `lb:league:{sex}` | membre = userId, score = hybrid_index.value |
| Activité (rival) | Sorted Set | `active:{sex}` | score = epoch du dernier effort ; purge > 30 j |
| Rival (calcul) | — | `ZINTERSTORE tmp lb:league:{sex} active:{sex}` puis `ZRANGEBYSCORE` au-dessus du user | actif + classé |
| Leaderboard par WOD | Sorted Set ×15×2 | `lb:wod:{wodId}:{sex}` | membre = userId, score = sub_score (review='ok') |
| Cache radar/index | String (JSON) | `cache:radar:{userId}` / `cache:index:{userId}` | TTL court (ex. 60 s) ; invalidé à chaque nouveau résultat |
| Idempotence | String | `idem:{userId}:{key}` | TTL 24 h, valeur = réponse sérialisée |
| Sessions / refresh | String/Set | `rt:{userId}:{jti}` | rotation des refresh tokens |

**Cohérence :** Postgres = source de vérité durable ; Redis = vue de lecture rapide. Écriture : transaction Postgres d'abord, puis `ZADD` Redis (et publication d'événement de réindexation en cas d'incohérence détectée). Au boot/secours, un job peut reconstruire un sorted set depuis `index(value DESC)` Postgres.

---

## Annexe B — CI minimale (GitHub Actions)

```
on: [push, pull_request]
jobs:
  ts:        # lint → typecheck → test (api, score-service, packages) ; couverture score bloquante
  flutter:   # flutter analyze → flutter test → build debug
  contracts: # vérifie que openapi.json est à jour (drift = échec)
```

---

## RÉSUMÉ DES DÉCISIONS CLÉS & ALERTES

1. **Monorepo pnpm + Turborepo** ; Flutter géré à part via `pub`. Frontière de langage = OpenAPI émis par l'`api` → client Dart généré (pas de partage TS↔Dart direct).
2. **Deux services au MVP, pas plus** : `api` (BFF monolithe modulaire NestJS) + `score-service` (microservice physiquement séparé, versionné). Toute formule de score vit uniquement dans `score-service`.
3. **Frontière interne versionnée** `/v1/score/*` ; chaque valeur notée (sub_score, attribute_score, index, history) porte une `scoringVersionId`.
4. **Postgres unique, deux schémas** (`app` propriété api / `scoring` propriété score-service) ; Redis pour 2 ligues + 15 leaderboards WOD + cache + sessions + idempotence.
5. **« Score ne baisse jamais » modélisé** par : meilleur effort dans la fenêtre 26 sem. (`best_result_id`), et **no-drop dur sur l'Index** lors d'un recalcul de version (max(ancien, nouveau)).
6. **Anti-triche** : bornes physiologiques (rejet 422) + détection d'anomalie (review='pending_review' → exclu des classements via `WHERE review='ok'`).
7. **Offline-first** : Outbox SQLite (Drift), idempotency-key = local_id, `unique(user_id, idempotency_key)` serveur, `performed_at` réel → ordre indifférent, pas de résolution de conflit complexe (règle « meilleur effort » commutative).
8. **RGPD/age-gating** : `date_of_birth` + CHECK ≥ 15 ans, consents jsonb, export + suppression différée. `visibility` présent partout (public au MVP, réversible).
9. **Format d'erreur standard** unique (`{error:{code,message,details,traceId}}`) défini dans `packages/contracts`.

**Alertes / incohérences signalées à l'humain (je ne tranche pas seul) :**
- **A1 — Décroissance par péremption vs « ne baisse jamais ».** §5.4 dit « le score ne diminue jamais automatiquement », mais §5.2 borne le meilleur effort à 26 semaines. À la sortie de fenêtre, sans re-test, un attribut **peut** baisser. J'ai interprété « jamais de baisse sur un mauvais jour » (ponctuel) ≠ « jamais de péremption » (26 sem.). À **valider** : veut-on un no-drop absolu même hors fenêtre (alors la fenêtre ne sert qu'à `is_stale`), ou une péremption assumée ?
- **A2 — No-drop dur lors d'un recalcul de version** masque la « vraie » nouvelle valeur. C'est conforme à l'ego protégé, mais peut figer artificiellement des Index gonflés par une ancienne formule. Confirmer le choix (no-drop dur vs ramp/lissage).
- **A3 — Card Render in-process au MVP.** Le rendu d'images est CPU-bound ; si le K-factor explose, l'extraire en worker (Phase 2). Acceptable au MVP, signalé.
- **A4 — `sex` verrouillé après onboarding.** Changer de sexe invaliderait tous les percentiles/classements. À confirmer : modification interdite, ou recalcul complet de l'historique de l'utilisateur ?
- **A5 — Rival « actif » via set Redis 30 j** : si Redis est vidé, le rival fallback temporairement. Acceptable (recomputé 1×/j), signalé.
