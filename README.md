# HYBRID INDEX — Starter (Claude Code)

Structure de démarrage prête à l'emploi pour construire l'app **HYBRID INDEX** avec Claude Code
et des agents spécialisés.

## Contenu

```
hybrid-index/
├── CLAUDE.md                      ← Constitution du projet (lue auto par Claude Code)
├── README.md                      ← Ce fichier
├── docs/
│   ├── cahier-des-charges.md      ← LA spec de référence (source de vérité)
│   └── PROMPT-DE-LANCEMENT.md     ← Le prompt à coller dans Claude Code
└── .claude/
    └── agents/
        ├── architect.md           ← Architecture, stack, data model, API
        ├── ui-ux-designer.md      ← Design system, écrans, "feel"
        ├── sport-science.md       ← 15 WODs, formules de score, données
        ├── gamification.md        ← Engagement, rival, rangs, badges
        └── reviewer.md            ← Relecture qualité/sécurité (lecture seule)
```

## Démarrage rapide

1. **Place ce dossier comme racine de ton repo Git** (`git init` si besoin).
2. **Installe / ouvre Claude Code** dans ce dossier (voir https://docs.claude.com/en/docs/claude-code/overview).
3. **Vérifie les agents** : lance `claude`, tape `/agents` pour les voir/éditer. *(Astuce : si tu
   modifies un fichier d'agent à la main, redémarre la session pour le recharger. Via `/agents`,
   c'est immédiat.)*
4. **Active le mode plan**, puis colle le prompt de `docs/PROMPT-DE-LANCEMENT.md`.
5. **Valide les specs** produites par les agents, puis le **plan du MVP**, puis construis
   **incrément par incrément** (chaque incrément relu par `reviewer`).

## Développement du monorepo (backend TS)

Prérequis : **Node ≥ 22**, **pnpm 10**. *(Si erreur de certificat TLS derrière un proxy
d'entreprise : préfixer les commandes par `NODE_OPTIONS=--use-system-ca`.)*

```bash
pnpm install          # installe le workspace (apps/api, apps/score-service, packages/*)
pnpm build            # build incrémental (turbo)
pnpm test             # tests (logique de score = couverture élevée, bloquant en CI)
pnpm typecheck        # vérification de types
```

Services (dev local complet via Docker — Postgres + Redis + api + score-service) :

```bash
docker compose -f infra/docker-compose.yml up --build
# api → http://localhost:3000/health   (score-service est interne, non exposé)
```

Structure : `apps/api` (BFF NestJS) · `apps/score-service` (microservice Score versionné) ·
`apps/mobile` (Flutter, hors workspace pnpm — voir `apps/mobile/README.md`) ·
`packages/contracts` (enums/DTO Zod = source de vérité). Détails : `docs/architecture.md`.

## Principe directeur
La qualité vient de la **discipline**, pas du nombre d'agents :
spec = source de vérité → plan avant code → petits incréments → revue systématique → portes
de validation humaines entre les phases.

## Modèles des agents
`opus` par défaut pour le jugement (architecture, design, sport, gamification, revue). Tu peux
basculer certains en `sonnet` pour réduire le coût sur les tâches à fort volume — édite le champ
`model:` dans le frontmatter de chaque agent.
