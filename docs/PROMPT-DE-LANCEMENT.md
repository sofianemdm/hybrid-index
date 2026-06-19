# Prompt de lancement (à coller dans Claude Code, en MODE PLAN)

Lance `claude` à la racine du repo, active le mode plan, puis colle le prompt ci-dessous.

---

## Prompt initial (étape 1 — pas de code)

```
Tu es l'orchestrateur du projet HYBRID INDEX. Avant tout : lis `docs/cahier-des-charges.md`
et `CLAUDE.md` en entier.

MÉTHODE DE TRAVAIL (impérative) :
- On travaille QUALITÉ AVANT VITESSE. Tu ne produis JAMAIS toute l'app d'un coup.
- Tu PLANIFIES d'abord, tu attends ma validation, PUIS tu construis — par petits incréments.
- Tu délègues aux agents spécialisés selon leur domaine : `architect`, `ui-ux-designer`,
  `sport-science`, `gamification`. Tu fais relire chaque incrément par `reviewer` avant de le
  considérer terminé.
- Tu respectes strictement les décisions verrouillées. Si quelque chose est ambigu, tu me
  POSES LA QUESTION plutôt que de supposer.

CE QUE JE VEUX MAINTENANT (étape 1, pas de code encore) :
1. Fais établir par `architect` la structure du repo, le modèle de données et les contrats d'API.
2. Fais produire par `sport-science` la spec des 15 WODs + la chaîne de notation + les sources
   des distributions de référence.
3. Fais produire par `gamification` la spec de la boucle d'engagement, du rival, des rangs/badges
   et des notifications.
4. Fais produire par `ui-ux-designer` le design system et la liste des écrans avec leurs états.
5. Tous ces livrables sont committés dans `docs/`.
6. Puis propose-moi un PLAN DÉTAILLÉ du MVP "thin slice" (Phase 1 de la roadmap), découpé en
   incréments livrables et testables, dans l'ordre de construction.

Ne commence à coder qu'après ma validation du plan. Pose-moi toutes tes questions d'abord.
```

---

## Prompt par incrément (phase de build)

```
Implémente UNIQUEMENT l'incrément [X] du plan validé. Écris les tests d'abord pour la logique de
score. Quand c'est prêt, fais relire par `reviewer` et corrige les points bloquants/majeurs avant
de me présenter le résultat.
```

---

## Les 6 règles qui empêchent d'aller trop vite
1. Plan d'abord, code après validation (mode plan + prompt ci-dessus).
2. Petits incréments dans l'ordre de la roadmap.
3. Definition of Done (dans `CLAUDE.md`) vérifiée à chaque fois.
4. Agent `reviewer` en porte de sortie de chaque incrément.
5. Tests sur la logique de score (justesse du HYBRID INDEX non négociable).
6. Portes de revue humaines entre les phases.
