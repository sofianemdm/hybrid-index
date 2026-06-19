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

## Principe directeur
La qualité vient de la **discipline**, pas du nombre d'agents :
spec = source de vérité → plan avant code → petits incréments → revue systématique → portes
de validation humaines entre les phases.

## Modèles des agents
`opus` par défaut pour le jugement (architecture, design, sport, gamification, revue). Tu peux
basculer certains en `sonnet` pour réduire le coût sur les tâches à fort volume — édite le champ
`model:` dans le frontmatter de chaque agent.
