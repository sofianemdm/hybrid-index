# HYBRID INDEX — Constitution du projet

## Le projet en une phrase
App mobile (iOS + Android) qui transforme la condition physique hybride en un score unique
comparable — le HYBRID INDEX — avec radar d'attributs, classement public, avatar évolutif,
système de rival, et coach qui propose des entraînements ciblés. Avec ou sans matériel.

## Source de vérité
`docs/cahier-des-charges.md` est LA référence. En cas de doute, on s'y réfère. On ne
contredit jamais ses "Décisions verrouillées". Si une décision pose problème, on le SIGNALE
à l'humain — on ne la modifie pas unilatéralement.

## Décisions verrouillées (ne JAMAIS contourner)
- Nom de l'APP : « Athlete League » ; nom du SCORE : « Athlete Index » (renommage validé par
  l'humain le 25 juin 2026, ex-« HYBRID INDEX »). Score normalisé PAR SEXE uniquement.
- iOS + Android, base de code unique ; 100 % gratuit pour l'instant ; données déclarées.
- App 100 % utilisable sans matériel ni box ; question "avec/sans matériel".
- ~3 entraînements suffisent pour un Index complet ; avatar créé en 30 s max.
- SUPPRIMÉS : quêtes, saisons, score de fatigue, catégories de poids.
- Ligues : 2 (Hommes / Femmes), classées par Hybrid Index ; box/amis seulement après 200 users.
- 15 WODs de référence (8 avec matériel, 7 sans), temps de tous, par sexe.
- Temps de course à l'onboarding : conseillé, non obligatoire.
- Tout est public (prévoir un champ `visibility` pour l'avenir).

## Stack
- Mobile : Flutter (base unique iOS+Android).
- Backend : NestJS (Node.js) + PostgreSQL + Redis (classements via sorted sets).
- Auth : email + Apple + Google. Notifications : FCM. Analytics : PostHog.
- Service Score (Index + notation WOD) : microservice séparé et VERSIONNÉ.

## Règles de travail (qualité avant vitesse — IMPÉRATIF)
1. PLANIFIER AVANT DE CODER. Pour toute tâche non triviale : proposer un plan et ATTENDRE
   ma validation. Ne pas échafauder toute l'app d'un coup.
2. PETITS INCRÉMENTS. Une fonctionnalité à la fois, dans l'ordre de la roadmap (thin slice
   d'abord). Commits petits et atomiques avec messages clairs.
3. DEMANDER, NE PAS SUPPOSER. Si une spec est ambiguë, poser la question plutôt que d'inventer.
4. TESTS OBLIGATOIRES sur la logique critique, surtout le calcul du HYBRID INDEX et la notation
   des WODs (la justesse du score est non négociable).
5. REVUE SYSTÉMATIQUE. Tout incrément significatif passe par l'agent `reviewer` avant d'être
   considéré comme terminé.
6. RESPECTER LE DESIGN SYSTEM et les conventions définies par l'architecte et le designer.

## Définition de "Terminé" (Definition of Done)
- [ ] Correspond au cahier des charges et aux décisions verrouillées.
- [ ] Tests écrits et qui passent (logique de score = couverture élevée).
- [ ] Relu par l'agent `reviewer` (aucune alerte bloquante).
- [ ] Pas de secret en dur, entrées validées, gestion d'erreur présente.
- [ ] États d'écran gérés (vide / chargement / erreur / succès) côté front.

## Les agents et quand les utiliser
- `architect` : structure du projet, stack, modèle de données, contrats d'API, décisions techniques.
- `ui-ux-designer` : design system, écrans, composants, "feel", tokens.
- `sport-science` : les 15 WODs (données), formules de score, distributions de référence, tags d'attributs, bibliothèque de séances.
- `gamification` : boucle d'engagement, logique de rival, badges, courbes de progression, notifications.
- `reviewer` : relecture qualité/sécurité/conformité de chaque incrément (lecture seule).
La session principale ORCHESTRE et IMPLÉMENTE en s'appuyant sur les specs produites par les experts.
