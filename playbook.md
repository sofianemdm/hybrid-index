# PLAYBOOK HYBRID INDEX — fondé sur les études

*Engagement durable et éthique pour une app de fitness hybride (CrossFit/HYROX).*
Chaque affirmation porte un **niveau de preuve** : **SOLIDE** (méta-analyses, réplications, standards) / **MODÉRÉ** / **FAIBLE-ANECDOTIQUE** (source unique, secteur, étude sous-puissante).

---

## 0. Le cadre directeur (à lire avant tout)

Deux résultats robustes doivent piloter toutes les décisions ci-dessous, parce qu'ils déterminent si vos mécaniques tiennent dans la durée ou s'effondrent au bout de 4 à 8 semaines.

**(a) La gamification "marche", mais l'effet est petit et décroît.** Méta-analyse de référence (Mazeas et al., 2022, *JMIR*, 16 RCT, 2 407 participants) : effet global sur l'activité physique **g = 0,42** (petit-à-moyen), qui tombe à **g = 0,15** au suivi (~14 semaines après la fin) — donc l'effet persiste *au-delà de la nouveauté*, mais s'affaiblit nettement. Contre des groupes actifs non-gamifiés, l'effet n'est que **g = 0,23**. La grande méta-analyse 2024 (eClinicalMedicine, 36 RCT, n = 10 079) confirme des effets **petits** : ~+489 pas/jour, −1,92 % de masse grasse.
→ Sources : https://www.jmir.org/2022/1/e26779 ; https://www.thelancet.com/journals/eclinm/article/PIIS2589-5370(24)00377-8/fulltext — **SOLIDE**.
**Implication :** ne survendez pas la gamification. Elle est un *accélérateur*, pas le moteur. Le moteur, c'est (b).

**(b) Ce qui prédit l'adhésion LONG TERME, c'est la motivation autonome, pas la pression externe.** Revue systématique SDT/exercice (Teixeira et al., 2012, 66 études) : la **régulation identifiée** ("je le fais parce que c'est important pour moi") prédit surtout l'**adoption initiale** ; la **motivation intrinsèque** ("j'y prends plaisir") prédit surtout l'**adhésion durable** ; la satisfaction du besoin de **compétence** prédit la participation de façon transversale. Les motivations contrôlées (récompenses, pression, culpabilité) initient moins bien et tiennent moins.
→ Source : https://pubmed.ncbi.nlm.nih.gov/22726453/ — **SOLIDE**. Méta SDT-santé (Ntoumanis et al., 2021) : effets réels mais modestes, médiés par la motivation autonome (https://www.tandfonline.com/doi/full/10.1080/17437199.2020.1718529).
**Implication :** vos mécaniques doivent nourrir **autonomie + compétence + lien social** (les 3 besoins SDT). Tout ce qui les attaque (pression culpabilisante, comparaison écrasante, perte punitive) booste le court terme et sabote le long terme.

C'est exactement la ligne qui sépare l'engagement durable du dark pattern.

---

## 1. MÉCANISMES D'ENGAGEMENT / RÉTENTION

### A) Ce que dit la recherche

**Goal-gradient + endowed progress — SOLIDE.** Kivetz, Urminsky & Zheng (2006, *J. of Marketing Research*) : sur 948 clients réels d'une carte de fidélité café, l'effort accélère à l'approche du but (~20 % de réduction du délai entre achats du 1er au dernier tampon). Robuste à travers formats (barre, anneau, jalons), contextes et échantillons. Corollaire majeur — l'**endowed progress effect** : une carte "achetez 12, 2 déjà tamponnés" surconvertit une carte "achetez 10 partant de zéro", à effort identique. Limite documentée : le **post-reward reset** — la motivation retombe juste après l'atteinte du but ; c'est là qu'on perd l'utilisateur.
→ https://journals.sagepub.com/doi/abs/10.1509/jmkr.43.1.39

**Loss aversion / streaks — SOLIDE pour le biais, MODÉRÉ pour l'application app.** L'aversion à la perte (Kahneman & Tversky) est l'un des effets les plus répliqués en psychologie : perdre fait ≈2× plus mal que gagner l'équivalent. Les streaks l'exploitent. Donnée secteur (Duolingo, source unique, **MODÉRÉ-FAIBLE**) : utilisateurs avec streak ≥7 jours retenus ~2,4× plus. **Mais l'enseignement le plus important est contre-intuitif et favorable à l'éthique** : Duolingo a augmenté l'engagement *long terme* en rendant les streaks **plus faciles** à tenir (streak freeze, "1 leçon/jour" au lieu d'objectifs XP ambitieux) — près de 40 % des apprenants actifs 2 jours d'affilée n'avaient aucun streak quand l'objectif était trop dur. Assouplir la perte > durcir la perte.
→ https://www.trypropel.ai/resources/duolingo-customer-retention-strategy

**Comparaison sociale / classements — MODÉRÉ, à double tranchant.** La comparaison ascendante ("meilleurs que moi") *peut* motiver, mais la recherche sur Strava montre qu'elle génère aussi pression, anxiété et démotivation, surtout chez les personnes à forte orientation comparative et faible auto-compassion (effets plus marqués chez les femmes dans une étude ; le motif "reconnaissance sociale" amplifie les effets négatifs). Les classements **filtrés / par pairs** (âge, niveau, groupe restreint) sont vécus comme plus pertinents et moins écrasants que les classements globaux dominés par l'élite.
→ https://www.sciencedirect.com/science/article/pii/S0378873322000909 ; CHI 2025 : https://dl.acm.org/doi/10.1145/3706598.3713737

**Feedback / compétence — SOLIDE (via SDT).** Feedback positif structuré + objectifs réalistes + progression visible nourrissent la compétence, premier prédicteur de motivation autonome. C'est le ressort le plus défendable scientifiquement, et le mieux aligné sur votre produit (radar d'attributs, score).

**"Variable rewards" (récompenses variables, façon *Hooked*) — FAIBLE/contesté.** Le modèle popularisé par Eyal s'appuie sur Skinner (animaux). Chez l'humain, en app de santé, l'effet additionnel d'une récompense *aléatoire* par-dessus une récompense fiable n'est pas robustement démontré — la méta-analyse gamification mesure l'effet d'un *bundle* de mécaniques, pas de la variabilité isolée. À utiliser avec parcimonie, jamais comme pilier.

### B) Quoi faire exactement pour HYBRID INDEX

1. **Faire du Hybrid Index lui-même la boucle de compétence.** Chaque entraînement loggé met à jour le score et le radar d'attributs en temps réel, avec un feedback explicite "tu as gagné +X sur l'Endurance, ton point faible". C'est votre mécanique la plus solide (compétence + feedback). Priorité absolue.
2. **Goal-gradient sur le prochain palier d'attribut.** Ne jamais afficher une barre vide. Montrez "Force : niveau 6, plus que 2 séances de tirage pour le niveau 7" et **pré-créditez la progression** au démarrage (endowed progress : l'avatar RPG commence niveau 1 avec une barre déjà entamée, pas à zéro).
3. **Contrer le post-reward reset.** Au moment où un palier/niveau d'avatar est atteint, révélez immédiatement le palier suivant *et* un objectif latéral (un autre attribut faible) pour éviter le creux de motivation.
4. **Streaks "doux".** Streak d'entraînement, oui — mais avec filet : tolérance hebdomadaire (jours de repos prévus dans le sport hybride !), "gel" de streak, et seuil bas (1 séance compte). Le repos fait partie de la performance : un streak qui punit le repos est anti-physiologique et anti-rétention.
5. **Rival + classements filtrés.** Votre système de rival est excellent *s'il est apparié au niveau* (comparaison proche = motivante, comparaison écrasante = démotivante). Classement public par sexe : ajoutez des filtres par **tranche de niveau / âge / box** pour que chacun ait un "match" gagnable. Mettez en avant la **progression personnelle** (PR, courbe du Hybrid Index) au moins autant que le rang absolu.
6. **Coach = autonomie.** Que le coach *propose* (plusieurs options) plutôt qu'il n'*impose* : le choix nourrit l'autonomie (3e besoin SDT). "Voici 3 séances pour ton point faible, choisis."

### C) À éviter (mythes / dark patterns)

- **Notifications culpabilisantes / FOMO punitif** ("Tu as déchu de la Ligue", "Ton rival t'a dépassé pendant que tu ne faisais rien"). Cela crée de la motivation *contrôlée* → meilleur court terme, pire long terme (SDT), et dégrade réputation/désinstallations. Duolingo lui-même a *réduit* la pression pour gagner en rétention.
- **Streak punitif sans filet** : pousse au surentraînement, ignore les jours de repos, transforme le sport en corvée (anti-motivation intrinsèque, le seul prédicteur d'adhésion durable).
- **Classement global unique** où 95 % des utilisateurs sont écrasés par l'élite : démotivation documentée.
- **Surinvestir dans les "récompenses variables aléatoires"** comme levier central : preuve faible, et glissement facile vers des mécaniques de type machine à sous.

---

## 2. NOM DE L'APP

### A) Ce que dit la recherche

**Fluence de traitement (processing fluency) — MODÉRÉ-SOLIDE.** Un nom facile à prononcer génère un affect positif, est jugé plus familier, plus sûr et plus digne de confiance (Song & Schwarz, 2009 ; Alter & Oppenheimer, 2009). La fluence est un effet réel mais d'ampleur modeste.
→ https://pmc.ncbi.nlm.nih.gov/articles/PMC4429570/

**Nuance importante — MODÉRÉ.** La difficulté n'est pas toujours un défaut : les noms *difficiles* à prononcer sont perçus comme plus **innovants, uniques, "spéciaux"** (Cho & Schwarz, 2006 ; Pocheptsova et al., 2010). Pour une marque qui veut signaler la performance et la distinction, un peu de friction peut servir l'image.

**Longueur / mémorabilité — FAIBLE.** Les noms courts et à pertinence sémantique sont jugés plus mémorables (études sur les marques). Le chiffre "6–8 caractères optimal" circule mais provient de sources d'agences, pas de méta-analyses : **à traiter comme heuristique, pas comme loi.**

**Distinctivité (ASO) — MODÉRÉ.** Sur les stores, un nom doit être (1) trouvable (mots-clés), (2) distinctif (ne pas se noyer parmi les concurrents). "Index" est un mot très commun → risque de faible distinctivité et de collision de marque/recherche.

### B) Quoi faire exactement pour HYBRID INDEX

- **Gardez "HYBRID INDEX" comme nom de marque** : les deux mots sont fluents et prononçables en anglais comme en français, et "Hybrid" est un mot-clé ASO en or pour CrossFit/HYROX (la catégorie s'appelle littéralement "hybrid fitness/athlete"). La structure "[catégorie] + [bénéfice]" est lisible et descriptive.
- **Vérifiez la distinctivité AVANT de vous engager** : recherchez "Index" sur les deux stores — beaucoup d'apps l'utilisent, ce qui peut diluer votre référencement et votre rappel. Si collision, envisagez de réserver "Hybrid Index" comme nom long et d'ajouter un **sous-titre porteur de mots-clés** (voir §5).
- **Format de la fiche store** : "Hybrid Index – Score & Classement Hybride" (nom + sous-titre = surface mots-clés maximale, voir §3/§5).
- **Testez le rappel** (protocole simple, gratuit) : faites prononcer le nom à 5–10 personnes après lecture, puis demandez-leur de le rappeler une semaine plus tard. Si >1 personne bute à la prononciation ou ne le retrouve pas, c'est un signal.

### C) À éviter

- **Surcharger le nom de mots-clés** ("Hybrid Index: HYROX CrossFit Workout Tracker Score Fitness") — pénalisé par les stores, nuit à la fluence et à la distinctivité.
- **Croire qu'un nom court "doit" faire 6–8 lettres** : preuve faible, ne sacrifiez pas la clarté à une règle de pouce.
- **Un nom invented/abstrait illisible** par pur souci de "branding" : vous perdriez l'avantage ASO du mot "Hybrid".

---

## 3. DÉCISION DE TÉLÉCHARGER (conversion de la fiche store)

### A) Ce que dit la recherche — données ASO (A/B tests sur gros volumes, **SOLIDE** au sens industriel)

**Ordre d'importance des leviers de conversion** (SplitMetrics, AppTweak *ASO Benchmarks 2025*, études de cas Apple) :

1. **Icône** — le plus gros levier unique. Jusqu'à **+30 %** de conversion (SplitMetrics) ; **+22,8 % iOS / +20,2 % Android** (AppTweak 2025) ; cas Apple "Peak" : **+8 % à 98 % de confiance**. C'est la première chose vue, en search comme en page.
2. **Captures (2 premières surtout)** — **+21,7 % iOS / +24,3 % Android**. La majorité des utilisateurs ne scrollent pas au-delà des 2 premières : elles font l'essentiel du travail.
3. **Note moyenne** — seuil critique **4,0+** : 90 % des apps mises en avant sur l'App Store sont à 4,0+ ; sous **3,5**, visibilité fortement réduite. La note agit comme preuve sociale ET comme facteur de classement.
4. **Vidéo / aperçu** puis **sous-titre** (très visible en search) puis **description** (sur iOS, la description n'influence ni le classement ni l'indexation, mais elle "ferme" l'utilisateur déjà intéressé ; sur Google Play elle est indexée).

Conversion moyenne de fiche : ~**25 % App Store**, **27,3 % Google Play** (AppTweak, S1 2024). Les benchmarks varient fortement par catégorie : comparez-vous à votre verticale (Santé/Forme), pas à un "30 %" générique.
→ https://www.apptweak.com/en/aso-blog/aso-app-store-trends-benchmarks-report ; https://kirro.io/app-store-conversion-rate ; https://adapty.io/blog/app-store-conversion-rate/

### B) Quoi faire exactement pour HYBRID INDEX

1. **Investir d'abord dans l'icône** (cf. §4) — c'est le meilleur retour sur effort.
2. **Capture #1 = la promesse en une image : le Hybrid Index lui-même.** Un grand score chiffré + radar d'attributs, avec un bénéfice en surtitre court ("Ton niveau hybride en un score"). Pas un screenshot brut d'UI. Capture #2 = la dimension sociale (classement/rival). Ces deux-là portent la conversion.
3. **Atteindre et défendre 4,0+** : déclenchez la demande d'avis (prompt natif iOS/Android) **après un moment de réussite** (nouveau PR, palier d'avatar atteint), jamais au lancement de l'app. C'est le levier de preuve sociale le plus rentable.
4. **Sous-titre (30 car. iOS) porteur de mots-clés et de bénéfice** : ex. "Score, classement & coach hybride".
5. **Mettre en place l'A/B test natif** (Product Page Optimization iOS / Store Listing Experiments Google Play) : un seul élément à la fois, ≥14 jours, ≥2 000 vues/variante/jour. Tester icône → capture #1 → vidéo, dans cet ordre.

### C) À éviter

- **Premières captures = UI générique** sans valeur lisible : ~20 % de conversion en moins vs des visuels montrant le résultat concret.
- **Demander l'avis trop tôt / de façon insistante** : casse la note et agace (dark pattern de notation).
- **Optimiser une métadonnée qui ne convertit pas sur votre store** (ex. soigner la description longue iOS en pensant qu'elle référence — elle ne le fait pas).
- **Comparer votre conversion à un benchmark générique** au lieu de votre catégorie.

---

## 4. LOGO / ICÔNE

### A) Ce que dit la recherche

- **L'icône est le premier levier de conversion** (cf. §3, **SOLIDE** côté ASO).
- **Fluence visuelle des logos — MODÉRÉ** : les logos simples, traités sans effort, sont mieux évalués (Bottomley & Doyle, 2006 ; van Grinsven & Das, 2014).
- **Reconnaissance à petite taille / contraste / différenciation** : principes de design établis (lisibilité d'un signe à 1× sur fond clair et sombre, silhouette distinctive). Niveau : consensus pratique **SOLIDE** sur la lisibilité, plus heuristique sur l'esthétique.

### B) Quoi faire exactement pour HYBRID INDEX

- **Un seul élément focal, mémorisable en silhouette** : un monogramme géométrique fort (ex. un "H" structuré, ou une forme évoquant le radar/score) plutôt qu'une scène détaillée d'haltères (cliché de la catégorie, peu différenciant).
- **Contraste élevé**, test obligatoire à **petite taille (≈48–60 px)** et sur fond **clair ET sombre** (l'icône doit tenir en dark mode store/écran d'accueil).
- **Se différencier de la concurrence fitness** : la verticale sature de noir + rouge/orange + haltères. Une couleur d'accent distinctive et une forme abstraite vous démarquent dans la grille de résultats.
- **Pas de texte dans l'icône** (illisible en petit).
- **A/B testez l'icône en premier** (meilleur ROI, §3).

### C) À éviter

- **Icône chargée / multi-éléments** illisible en petit.
- **Mimétisme** avec les leaders de la catégorie (silhouette d'haltère générique) : vous devenez invisible.
- **Dépendre d'une couleur seule** pour la reconnaissance (pensez daltonisme : la forme doit fonctionner en niveaux de gris).

---

## 5. DESCRIPTION (store listing)

### A) Ce que dit la recherche

- **Seules les ~3 premières lignes** (~252 caractères avant le "plus/more") sont vues par défaut : c'est là que se joue la conversion (**SOLIDE**, secteur).
- **Sous-titre/première ligne = bénéfice concret > liste de fonctionnalités** : une promesse claire convertit mieux qu'une énumération (MobileAction, ASOMobile).
- **iOS** : la description **n'est pas indexée** (le référencement passe par titre + sous-titre + champ keywords) ; elle sert à *convaincre*, pas à *être trouvée*. **Google Play** : la description **est indexée** → densité de mots-clés naturelle utile.
→ https://www.mobileaction.co/blog/how-to-increase-app-conversion-rate/ ; https://asomobile.net/en/blog/how-to-improve-app-store-conversion-rate-metadata-screenshots-and-cro-tips/

### B) Quoi faire exactement pour HYBRID INDEX

- **3 premières lignes = la promesse + la preuve + l'appel.** Ex. :
  > "Transforme ta condition physique en un seul score comparable, le Hybrid Index. Suis tes attributs (force, endurance, puissance…), grimpe au classement, défie ton rival. Le coach te propose les séances qui te font progresser."
- **iOS** : remplir le champ **keywords (100 car.)** avec hyrox, crossfit, hybrid, wod, score, classement, endurance, force… (séparés par virgules, sans espaces, sans répéter le titre). Ne pas "bourrer" la description iOS de mots-clés (inutile car non indexée).
- **Google Play** : description longue rédigée naturellement, avec mots-clés répartis 2–3 fois, sans sur-optimiser.
- **Structurer pour le scan** : courts paragraphes/puces, bénéfices d'abord, fonctionnalités ensuite.

### C) À éviter

- **Ouvrir sur une liste de features** ou du jargon avant la promesse : ignoré.
- **Keyword stuffing** (surtout dans la description iOS, où c'est sans effet et peut nuire à la lisibilité ; sur Google Play, le bourrage est pénalisé).
- **Croire que la description longue iOS améliore le classement** : elle ne le fait pas.

---

## 6. COULEURS & TYPOGRAPHIE DANS L'APP

### A) Ce que dit la recherche

**La "psychologie des couleurs" populaire (bleu = confiance, rouge = urgence…) — FAIBLE / contesté. À démystifier.** La revue de référence (Elliot, 2015, *Frontiers in Psychology* ; Elliot & Maier, *Annual Review of Psychology*, 2014) conclut que le champ est à un **stade naissant**, avec beaucoup d'études **sous-puissantes** et des effets **dépendants du contexte et de la culture** ; elle recommande explicitement **prudence et patience** avant toute conclusion. L'effet emblématique "le rouge dégrade la performance cognitive" (Elliot & Niesta, 2008) était sous-puissant et sujet à caution réplicative. **Conclusion : ne fondez aucune décision produit sur des associations émotionnelles couleur→émotion.**
→ https://pmc.ncbi.nlm.nih.gov/articles/PMC4383146/

**Ce qui EST solide, c'est le contraste et la lisibilité — SOLIDE.**
- **Polarité positive (texte sombre sur fond clair)** est généralement supérieure pour l'acuité et la lisibilité chez les personnes à vision normale, et **l'avantage grandit quand la police rétrécit** (revue NN/g ; Tinker ; Humar et al., 2014, *Applied Ergonomics*). Mécanisme : plus de lumière → pupille plus contractée → image plus nette.
→ https://www.nngroup.com/articles/dark-mode/
- **Dark mode (polarité négative)** : ressenti comme **moins exigeant mentalement** (NASA-TLX) et **réduit la fatigue en environnement sombre / la nuit** ; économise la batterie sur OLED ; bénéfique pour certaines basses visions (cataracte). Mais résultats objectifs **mixtes** sur la lisibilité fine. → Verdict : **proposez les deux**, ne tranchez pas idéologiquement.
- **Contraste = le facteur causal** : plus le contraste luminance texte/fond est élevé, meilleure la lisibilité.

**WCAG 2.x — standard SOLIDE (consensus normatif).**
- Niveau **AA** : ratio de contraste **4,5:1** pour le texte normal, **3:1** pour le grand texte (≥ 18 pt, ou 14 pt gras) et pour les composants d'UI/icônes signifiantes.
- Niveau **AAA** : **7:1** (texte normal), **4,5:1** (grand texte).

### B) Quoi faire exactement pour HYBRID INDEX

1. **Décider la palette sur des critères de design (cohérence de marque, hiérarchie, accessibilité), PAS sur la "signification" des couleurs.** Choisissez une couleur d'accent distinctive de la concurrence (cf. §4) et tenez-vous-y comme *actif de marque*, pour la reconnaissance — pas pour "transmettre une émotion".
2. **Supporter dark mode ET light mode, défaut = réglage système** ; mémoriser le choix, le synchroniser. C'est ce que la preuve mixte + les préférences contextuelles recommandent.
3. **Respecter WCAG AA partout, viser AAA sur le corps de texte** : 4,5:1 minimum pour le texte courant, 3:1 pour gros chiffres (le score, parfait pour le grand affichage) et icônes. Vérifiez chaque paire texte/fond avec un contrôleur de contraste.
4. **Éviter le noir pur (#000) sur blanc pur (#FFF)** et le blanc pur sur noir pur : préférez un quasi-noir / off-white et, en dark mode, un gris très foncé (≈ #121212) avec texte légèrement adouci — tout en gardant le contraste ≥ AA. Cela réduit l'éblouissement/halo sans sacrifier la lisibilité.
5. **Couleur jamais seule porteuse d'information** (radar, classement, états gagné/perdu) : doublez par forme, libellé ou icône (daltonisme ≈ 8 % des hommes).
6. **Typographie** : une police lisible à fort contraste, tailles confortables (corps ≥ 16 px), hiérarchie nette. Le **grand chiffre du Hybrid Index** est votre élément signature : exploitez-le en très grand (l'avantage de lisibilité du texte large vous laisse plus de liberté de couleur ici).

### C) À éviter

- **Choisir des couleurs "parce que bleu = confiance / rouge = énergie"** : base scientifique faible, dépendante de la culture. Mythe à abandonner.
- **Texte gris clair sur fond clair** "pour l'esthétique" : échec WCAG, illisible au soleil (cas d'usage typique en salle/extérieur pour du sport).
- **Imposer un seul mode** (tout-dark "parce que c'est sportif") : ignore la supériorité de lisibilité du light mode en plein jour et les préférences contextuelles.
- **Couleur seule pour coder une info** (rouge = perdu / vert = gagné sans autre indice).

---

## CHECKLIST « À FAIRE EXACTEMENT » (priorisée)

**P0 — Fondations de rétention (le plus rentable)**
1. Mettre à jour le **Hybrid Index + radar en temps réel** après chaque séance, avec feedback de compétence explicite ("+X sur ton point faible").
2. **Barres de progression jamais vides** + **endowed progress** (avatar/attributs démarrent avec une barre déjà entamée).
3. **Streaks avec filet** : jours de repos tolérés, gel de streak, seuil = 1 séance. Jamais punitif.
4. **Rival apparié au niveau** + **classements filtrés** (sexe × niveau × âge/box) + mise en avant de la **progression personnelle**.
5. **Coach qui propose des choix** (autonomie SDT).

**P0 — Conversion store (le plus rentable)**
6. **Icône** : monogramme/forme abstraite distinctive, testée à 48–60 px sur fonds clair et sombre. **A/B test en premier.**
7. **Capture #1** = le score + radar avec bénéfice en surtitre ; **#2** = social/rival.
8. **Atteindre 4,0+** : prompt d'avis natif déclenché **après une réussite**.
9. **Sous-titre + champ keywords iOS** optimisés (hybrid, hyrox, crossfit, score, classement…).

**P1 — Listing & contenu**
10. **3 premières lignes de description** = promesse + preuve + appel ; features ensuite.
11. Description **Google Play** rédigée avec mots-clés naturels ; ne pas bourrer iOS.
12. Mettre en place **PPO (iOS) / Store Listing Experiments (Google Play)** : 1 variable, ≥14 j, ≥2 000 vues/variante/jour.

**P1 — Couleurs & typo**
13. **Dark + light mode**, défaut système, choix mémorisé.
14. **WCAG AA partout, AAA sur le corps de texte** ; contrôler chaque paire.
15. Quasi-noir/off-white plutôt que purs ; **couleur jamais seule** pour coder l'info ; corps ≥ 16 px.

**P2 — Garde-fous**
16. **Bannir** notifications culpabilisantes / FOMO punitif. Notifs = valeur (rappel utile, proposition de séance), pas culpabilité.
17. Comparer la conversion à la **catégorie Santé/Forme**, pas à un benchmark générique.

---

## CE QUE LES ÉTUDES NE PROUVENT PAS (croyances à abandonner)

- **« Les couleurs transmettent des émotions fiables (bleu = confiance, etc.). »** Champ naissant, études souvent sous-puissantes, effets dépendants du contexte et de la culture. Ne pilotez pas le design avec ça. (Elliot, 2015 — **FAIBLE/contesté**)
- **« Les récompenses variables/aléatoires façon *Hooked* sont un levier majeur. »** Extrapolation depuis Skinner (animaux) ; l'effet additionnel isolé chez l'humain en app de santé n'est pas robustement établi. (**FAIBLE**)
- **« Plus de gamification = beaucoup plus d'engagement. »** L'effet est **petit** (g ≈ 0,42) et **décroît** dans le temps (g ≈ 0,15 au suivi). C'est un accélérateur, pas un moteur. (Mazeas et al., 2022 — **SOLIDE**)
- **« La pression / culpabilité / FOMO retient les utilisateurs. »** À court terme oui, à long terme non : la motivation contrôlée prédit moins bien l'adhésion durable que la motivation autonome. Duolingo a gagné en rétention en *réduisant* la pression. (Teixeira et al., 2012 — **SOLIDE**)
- **« Les classements motivent tout le monde. »** À double tranchant : la comparaison écrasante démotive, surtout les profils à faible auto-compassion. Filtrez et privilégiez la progression personnelle. (Strava, Franken et al. — **MODÉRÉ**)
- **« La description longue de l'App Store améliore le référencement. »** Faux sur iOS (non indexée). (**SOLIDE**, secteur)
- **« Un bon nom doit faire 6–8 lettres. »** Heuristique d'agence, pas une loi méta-analytique. La fluence et la distinctivité comptent plus que le compte de lettres. (**FAIBLE**)
- **« Le dark mode est objectivement meilleur (ou pire). »** Résultats mixtes : light mode plus lisible en plein jour et en petit ; dark mode plus confortable la nuit. → Offrir les deux. (NN/g — **SOLIDE** sur le caractère contextuel)

---

### Note de méthode
Les chiffres ASO (icône +30 %, captures +22 %, seuil 4,0+) viennent de benchmarks d'industrie agrégés (SplitMetrics, AppTweak, études de cas Apple) : robustes en pratique mais **non publiés en revue à comité de lecture** — traitez-les comme des ordres de grandeur, et **revalidez par vos propres A/B tests**, car l'ampleur réelle dépend de votre catégorie et de votre trafic.
