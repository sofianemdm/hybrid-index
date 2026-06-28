# Recalibration des paliers de notation — juin 2026

> **Demande produit (humain)** : rendre **débutant** (`occasional`) et **intermédiaire**
> (`intermediate`) plus **indulgents/atteignables** sur TOUTES les séances, sans jamais
> toucher à l'**élite** (`champion`). Objectif : ne frustrer personne. Un débutant qui
> *termine* une séance ne doit jamais se sentir « en dessous du débutant », et l'intermédiaire
> doit correspondre à « quelqu'un qui fait du sport depuis 3-6 mois », pas à un pratiquant confirmé.

Ce document est la **spec prête à coller**. Les ingénieurs reportent :
- les colonnes `intermediate` / `occasional` dans **`apps/score-service/src/wods/wod-levels.data.ts`** ;
- la colonne `nouveau model+params` dans **`apps/score-service/src/wods/wods.data.ts`** (champ `model` de chaque sexe).

Ne modifier QUE ces deux fichiers. **`champion` et `proReference` restent strictement inchangés.**

---

## 1. Philosophie de la recalibration

### Le problème
Aujourd'hui, l'intermédiaire est calé sur un *pratiquant régulier compétent* et le débutant
sur un *pratiquant loisir*. Résultat : un vrai grand débutant (qui finit péniblement) tombe
sous le palier « occasionnel » et obtient un sous-score proche de 0 — frustrant et faux
(il a quand même fini une séance dure).

### La cible
On déplace les deux paliers bas **vers le bas** (vers le débutant), en gardant l'élite fixe :

| Palier | Ancienne signification | **Nouvelle signification** | Percentile cible |
|---|---|---|---|
| `champion` | Record / élite | **inchangé** (record / élite) | ~P95-P99 |
| `intermediate` | Pratiquant régulier compétent | **Loisir 3-6 mois, régulier mais pas avancé = MÉDIANE** | **P50** |
| `occasional` | Pratiquant loisir | **Grand débutant qui TERMINE la séance** | **P12-P15** (jamais P0) |

### Conséquence sur le scoring (non négociable)
Changer les paliers d'affichage ne suffit pas : le **sous-score** vient de la distribution
de `wods.data.ts`. On recale donc chaque distribution pour que :
- `champion` → ~**P95+** (donc sous-score ~970-990) — préservé,
- `intermediate` → ~**P50** (sous-score ~500, soit ~50/100 affiché) — la nouvelle médiane,
- `occasional` → ~**P12-P15** (sous-score ~150-200, soit ~15-20/100) — **un score honnête, pas 2/100**.

Concrètement, sur chaque distribution on **abaisse la médiane** (= nouvel intermédiaire) et,
si besoin, on **élargit σ** pour que la queue lente/faible attrape l'occasionnel à ~P12-15
sans laisser le champion descendre sous P95.

### Rappels de modèle (vérifiés dans `scoring-core/src/distribution.ts`)
- `lognormalFromMedian(med, σ)` → **médiane = `med`** ; `q(p) = med · exp(σ·z(p))`. (`time`, dir −1)
- `lnArithMean(mean, σ)` (helper local, Grace) → **médiane = `mean·exp(−σ²/2)`**.
- `normal(mu, σ)` → P50 = `mu` ; `q(p) = mu + σ·z(p)`. (`reps`/`load`, dir +1)
- `pointTable` → interpolation directe (p, r) ; **demande un traitement nœud par nœud** (cf. §5).
- Valeurs z utiles : z(.10)=−1.2816, z(.12)≈−1.175, z(.15)=−1.0364, z(.20)=−0.8416,
  z(.50)=0, z(.90)=+1.2816, z(.95)=+1.6449, z(.99)=+2.3263.

> **Règle de cohérence des σ (time, dir −1)** : champion à ~P95 ⟹ `ln(med/champ) ≈ 1.645·σ`.
> On choisit σ pour respecter l'écart med↔champion réel, puis occasional ≈ `med·exp(1.18·σ)`
> (P≈12). Si l'écart med↔champion est petit, on garde un σ plus serré et l'occasionnel reste
> proche de la médiane (normal : le WOD est « peu dispersé »).

---

## 2. WODs `time` log-normaux (avec/sans matériel)

Format params : `lognormalFromMedian(<médiane=nouvel intermediate>, <σ>)` — `hardMin/hardMax/proReference` **inchangés**.
Vérif : `champ→P` = Φ(ln(med/champ)/σ) ; `occ→P` = Φ(−ln(occ/med)/σ).

### hyrox_sprint
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 660 | **1020** *(était 960)* | **1380** *(était 1260)* | `lognormalFromMedian(1020, 0.26)` | P97 / P14 |
| female | 750 | **1140** *(était 1080)* | **1560** *(était 1440)* | `lognormalFromMedian(1140, 0.26)` | P96 / P14 |

### fran
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 113 | **390** *(était 345)* | **660** *(était 540)* | `lognormalFromMedian(390, 0.42)` | P99 / P12 |
| female | 135 | **450** *(était 390)* | **780** *(était 660)* | `lognormalFromMedian(450, 0.42)` | P99 / P12 |

> fran très dispersé (la majorité scale) → σ large assumée, occasionnel franchement lent (11 min H).

### grace *(helper `lnArithMean`, médiane = mean·exp(−σ²/2))*
On vise une **médiane** (= nouvel intermédiaire) ; le param `mean` se déduit : `mean = médiane / exp(−σ²/2) = médiane·exp(σ²/2)`.
| Sexe | champion | **intermediate (médiane visée)** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 68 | **230** *(était 203)* | **400** *(était 360)* | `lnArithMean(252, 0.45)` *(med≈230)* | P98 / P13 |
| female | 85 | **268** *(était 236)* | **460** *(était 420)* | `lnArithMean(290, 0.42)` *(med≈268)* | P98 / P14 |

> `mean_H = 230·exp(0.45²/2) = 230·1.105 = 254 ≈ 252` (arrondi pour rester proche de l'ancien style).
> `mean_F = 268·exp(0.42²/2) = 268·1.090 = 292 ≈ 290`. Vérifier en test que médiane ≈ intermédiaire.

### row_2k
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 336 | **450** *(était 420)* | **570** *(était 540)* | `lognormalFromMedian(450, 0.115)` | P99 / P14 |
| female | 381 | **510** *(était 480)* | **648** *(était 630)* | `lognormalFromMedian(510, 0.115)` | P99 / P14 |

> Aviron peu dispersé (effort mesuré) → σ resté modeste mais élargi de 0.085→0.115 pour
> remonter le débutant (P14 au lieu d'écrasé). 7min30 H = grand débutant qui finit.

### helen
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 390 | **640** *(était 590)* | **900** *(était 840)* | `lognormalFromMedian(640, 0.29)` | P96 / P12 |
| female | 450 | **720** *(était 674)* | **1020** *(était 960)* | `lognormalFromMedian(720, 0.29)` | P96 / P13 |

### ergo_skill (Machine & Mur)
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 360 | **660** *(était 600)* | **960** *(était 900)* | `lognormalFromMedian(660, 0.31)` | P97 / P13 |
| female | 420 | **750** *(était 690)* | **1080** *(était 1020)* | `lognormalFromMedian(750, 0.31)` | P96 / P13 |

### run_3k
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 600 | **990** *(était 810)* | **1560** *(était 1470)* | `lognormalFromMedian(990, 0.30)` | P95 / P12 |
| female | 690 | **1140** *(était 960)* | **1770** *(était 1650)* | `lognormalFromMedian(1140, 0.30)` | P95 / P13 |

> Gros recul de l'intermédiaire (810→990 H = 16min30, un joggeur loisir vrai). σ 0.22→0.30
> pour garder champion à P95 malgré la médiane plus lente, et faire descendre le débutant (26min).

### run_1k
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 131 | **330** *(était 255)* | **500** *(était 450)* | `lognormalFromMedian(330, 0.35)` | P99 / P14 |
| female | 148 | **390** *(était 288)* | **588** *(était 540)* | `lognormalFromMedian(390, 0.35)` | P99 / P14 |

> Intermédiaire 5min30/km H = vrai débutant régulier. σ élargi (0.22→0.35) car la médiane
> loisir d'un 1 km est très loin du champion sprinté.

### run_free_distance *(normalisé Riegel sur 5 km — c'est une distribution "5 km")*
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 1050 | **1980** *(était 1620)* | **3000** *(était —)* | `lognormalFromMedian(1980, 0.30)` | P96 / P13 |
| female | 1170 | **2280** *(était 1860)* | **3420** *(était —)* | `lognormalFromMedian(2280, 0.30)` | P96 / P13 |

> Pas de ligne dédiée dans `wod-levels.data.ts` (course saisie en distance libre) ; seul le
> `model` change. Médiane 33min/5km H = joggeur loisir débutant. σ 0.22→0.30.

### league_sprint_ladder (La Flèche — Ligue)
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 290 | **480** *(était 420)* | **720** *(était 600)* | `lognormalFromMedian(480, 0.31)` | P95 / P13 |
| female | 335 | **540** *(était 480)* | **810** *(était 690)* | `lognormalFromMedian(540, 0.31)` | P95 / P13 |

### league_hybrid_chipper (Le Chaos — Ligue)
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 400 | **720** *(était 660)* | **1020** *(était 870)* | `lognormalFromMedian(720, 0.30)` | P97 / P13 |
| female | 460 | **780** *(était 720)* | **1080** *(était 900)* | `lognormalFromMedian(780, 0.28)` | P96 / P14 |

> `hardMax` actuel = 900 s : **à relever à 1200 s** (sinon l'occasionnel 1020 s dépasse hardMax
> et est clampé). Note ingé : bump `hardMax` male 900→1200, female 900→1200.

---

## 3. WODs « Autre » `time` log-normaux (hyrox_solo, isabel, murph, courses longues)

Même logique. `proReference`/`hardMin`/`hardMax` inchangés.

### hyrox_solo
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 3119 | **5700** *(était 4500)* | **7800** *(était 7050)* | `lognormalFromMedian(5700, 0.255)` | P99 / P13 |
| female | 3265 | **6300** *(était 5100)* | **8700** *(était 7850)* | `lognormalFromMedian(6300, 0.255)` | P99 / P14 |

> Intermédiaire ramené au **finisher médian réel** (~1h35 H / 1h45 F), plus du tout « amateur solide ».

### isabel
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 55 | **165** *(était 150)* | **290** *(était 232)* | `lognormalFromMedian(165, 0.46)` | P99 / P12 |
| female | 70 | **210** *(était 190)* | **360** *(était 294)* | `lognormalFromMedian(210, 0.46)` | P99 / P13 |

### murph
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 2000 | **3300** *(était 3300)* | **4850** *(était 4850)* | `lognormalFromMedian(3300, 0.32)` | P95 / P13 |
| female | 2400 | **3600** *(était 3600)* | **5300** *(était 5300)* | `lognormalFromMedian(3600, 0.30)` | P95 / P14 |

> Déjà calé sur le finisher médian (intermédiaire affiché = médiane scoring). On élargit σ
> 0.30→0.32 (H) pour bien remonter le débutant à P13. Paliers d'affichage inchangés.

### track_10000m
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 1571 | **3300** *(était 2580)* | **4900** *(était 4500)* | `lognormalFromMedian(3300, 0.32)` | P98 / P13 |
| female | 1734 | **3600** *(était 2880)* | **5300** *(était 4900)* | `lognormalFromMedian(3600, 0.31)` | P98 / P13 |

> Intermédiaire ramené au finisher médian réel (~55min H / 60min F). σ 0.24→0.32.

### half_marathon
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 3440 | **7000** *(était 5700)* | **9300** *(était 9000)* | `lognormalFromMedian(7000, 0.24)` | P99 / P13 |
| female | 3772 | **7800** *(était 6300)* | **10400** *(était 10200)* | `lognormalFromMedian(7800, 0.24)` | P99 / P14 |

> Intermédiaire = finisher médian RunRepeat (1h57 H / 2h10 F). σ 0.20→0.24 pour remonter le débutant.

### marathon
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 7170 | **15600** *(était 11700)* | **20400** *(était 19800)* | `lognormalFromMedian(15600, 0.24)` | P99 / P13 |
| female | 7796 | **16800** *(était 13200)* | **22200** *(était 21600)* | `lognormalFromMedian(16800, 0.24)` | P99 / P14 |

> Intermédiaire = finisher médian réel (~4h20 H / 4h40 F). σ 0.20→0.24.

---

## 4. WODs `reps` / `load` (modèle `normal`, dir +1)

mu = **nouvel intermédiaire (médiane)**. σ choisie pour : champion≈P95 (donc `σ ≈ (champ−mu)/1.645`)
ET occasional à P12-15 (`occ ≈ mu − 1.18·σ`, plancher `hardMin`). On **élargit σ vers le bas**
en abaissant mu, ce qui remonte mécaniquement le débutant. `proReference`/`hardMin`/`hardMax` inchangés.

### cindy *(score en TOURS)*
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 27 | **12** *(était 15)* | **6** *(était 8)* | `normal(12, 5.0)` | P100? non → P99.9 ; voir note | 
| female | 23 | **10** *(était 12)* | **5** *(était 6)* | `normal(10, 4.2)` | — |

> Avec mu=12, σ=5 : champ 27 → z=3.0 → P99.9 (élite très au-dessus, OK, reste ≈ top score).
> occ 6 → z=−1.2 → **P12**. Bon. (Si on veut champ pile ~P97, garder σ=5 reste acceptable :
> l'élite Cindy *doit* écraser.) Femme mu=10 σ=4.2 : champ 23 → z=3.1 (P99.9) ; occ 5 → z=−1.19 → P12.

### max_pushups
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 60 | **20** *(était 25)* | **8** *(était 10)* | `normal(20, 13)` | champ z=3.08 (P99.9) / occ z=−0.92 (P18) |
| female | 35 | **10** *(était 12)* | **4** *(était 4)* | `normal(10, 8)` | champ z=3.1 (P99.9) / occ z=−0.75 (P23) |

> Pompes très dispersées ; on abaisse mu (20 H / 10 F = vrai loisir 3-6 mois). occasionnel
> remonté à P18-23 — un débutant qui fait 8 pompes n'est plus « sous le débutant ». σ élargi.

### max_air_squats_2min
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 85 | **42** *(était 50)* | **25** *(était 30)* | `normal(42, 16)` | champ z=2.69 (P99.6) / occ z=−1.06 (P14) |
| female | 80 | **38** *(était 45)* | **22** *(était 28)* | `normal(38, 15)` | champ z=2.80 (P99.7) / occ z=−1.07 (P14) |

### burpees_7min
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 125 | **58** *(était 70)* | **35** *(était 40)* | `normal(58, 24)` | champ z=2.79 (P99.7) / occ z=−0.96 (P17) |
| female | 110 | **48** *(était 60)* | **28** *(était 35)* | `normal(48, 21)` | champ z=2.95 (P99.8) / occ z=−0.95 (P17) |

### max_air_squats *(une série à l'échec)*
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 150 | **65** *(était 80)* | **35** *(était —)* | `normal(65, 38)` | champ z=2.24 (P98.7) / occ z=−0.79 (P21) |
| female | 135 | **55** *(était 70)* | **30** *(était —)* | `normal(55, 34)` | champ z=2.35 (P99.1) / occ z=−0.74 (P23) |

### max_strict_pullups
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 30 | **6** *(était 9)* | **2** *(était 2)* | `normal(6, 7)` | champ z=3.43 (P99.9) / occ z=−0.57 (P28) |
| female | 18 | **2** *(était 3)* | **0** *(était 0)* | `normal(2, 3.5)` | champ z=4.6 (≈P100) / occ z=−0.57 (P28) |

> Mouvement asymétrique (beaucoup font 0-2). On abaisse mu pour que faire **1 traction**
> donne déjà un score décent (≈P40 H). hardMin=0 garde le plancher. L'élite (30/18) écrase,
> normal pour une vraie démonstration de force.

### squat_1rm *(load, kg)*
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 220 | **85** *(était 100)* | **45** *(était 50)* | `normal(85, 42)` | champ z=3.21 (P99.9) / occ z=−0.95 (P17) |
| female | 145 | **52** *(était 60)* | **30** *(était 32)* | `normal(52, 28)` | champ z=3.32 (P99.9) / occ z=−0.79 (P21) |

> Intermédiaire 85 kg H / 52 kg F = back squat d'un loisir 3-6 mois (≈ barre + ~40/30 kg),
> pas un « Intermediate StrengthLevel ». occasionnel = grand débutant (45/30 kg).

### league_engine_12 (Le Moteur — reps)
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 210 | **115** *(était 140)* | **65** *(était 90)* | `normal(115, 45)` | champ z=2.11 (P98.3) / occ z=−1.11 (P13) |
| female | 130 | **80** *(était 100)* | **45** *(était 70)* | `normal(80, 30)` | champ z=1.67 (P95) / occ z=−1.17 (P12) |

### league_grind_squats (Le Pilier — reps)
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 520 | **320** *(était 400)* | **180** *(était 250)* | `normal(320, 125)` | champ z=1.60 (P95) / occ z=−1.12 (P13) |
| female | 330 | **230** *(était 290)* | **130** *(était 175)* | `normal(230, 90)` | champ z=1.11 (P87) / occ z=−1.11 (P13) |

> Femme : champion 330 proche de la médiane 230 (WOD peu dispersé chez F) → champ ≈ P87.
> Acceptable car proReference F (400) — pas le champion d'affichage — sert au scoring haut.
> Si l'on veut champ≈P95, réduire σ_F à 60, mais alors occ remonte trop ; on **privilégie
> l'indulgence du débutant** (consigne) → on garde σ=90.

### league_power_amrap (La Détente — reps)
| Sexe | champion | **intermediate** | **occasional** | **nouveau model** | champ→P / occ→P |
|---|---|---|---|---|---|
| male | 360 | **175** *(était 215)* | **100** *(était 130)* | `normal(175, 72)` | champ z=2.57 (P99.5) / occ z=−1.04 (P15) |
| female | 195 | **105** *(était 127)* | **60** *(était 80)* | `normal(105, 42)` | champ z=2.14 (P98.4) / occ z=−1.07 (P14) |

---

## 5. Cas particuliers `pointTable` (traitement nœud par nœud)

Les `pointTable` ne se pilotent pas par (médiane, σ) : il faut **réécrire chaque nœud (p, r)**
pour que le nœud P50 = nouvel intermédiaire et que la queue lente (P10) ≥ occasionnel.
Règle appliquée : on **conserve les nœuds rapides** (P0.90, P0.99 — ils ancrent le champion à
P95+ et **ne doivent pas bouger**, donc le `proReference` garde son percentile élevé) et on
**ralentit P0.10, P0.25, P0.50** vers les nouveaux paliers indulgents.

### jackie (`points`, dir −1)
| Sexe | champion | **intermediate** (=P50) | **occasional** (≈P12) | **nouveaux nodes** |
|---|---|---|---|---|
| male | 300 | **540** *(était 480)* | **720** *(était 660)* | `[[0.1,780],[0.25,615],[0.5,540],[0.75,450],[0.9,375],[0.99,315]]` |
| female | 340 | **615** *(était 555)* | **840** *(était 780)* | `[[0.1,900],[0.25,705],[0.5,615],[0.75,510],[0.9,435],[0.99,360]]` |

> P0.90 / P0.99 inchangés (375/315 H) → champion 300 reste au-dessus de P99 (top score). On
> a ralenti P0.10→0.50. Affichage occasional = nœud ~P10-12.

### karen (`points`, dir −1)
| Sexe | champion | **intermediate** (=P50) | **occasional** | **nouveaux nodes** |
|---|---|---|---|---|
| male | 300 | **600** *(était 555)* | **840** *(était 780)* | `[[0.1,900],[0.25,720],[0.5,600],[0.75,480],[0.9,390],[0.99,300]]` |
| female | 360 | **720** *(était 660)* | **990** *(était 900)* | `[[0.1,1050],[0.25,840],[0.5,720],[0.75,570],[0.9,465],[0.99,360]]` |

> P0.90/0.99 inchangés (390/300 H) → champion à P99. Médiane et nœuds lents ralentis.

### benchmark_zero (`points`, dir −1) — confidence `low`, à recalibrer N≥200
| Sexe | champion | **intermediate** (=P50) | **occasional** | **nouveaux nodes** |
|---|---|---|---|---|
| male | 345 | **630** *(était 570)* | **900** *(était 840)* | `[[0.1,960],[0.25,765],[0.5,630],[0.75,510],[0.9,420],[0.99,345]]` |
| female | 390 | **720** *(était 645)* | **1020** *(était 945)* | `[[0.1,1080],[0.25,855],[0.5,720],[0.75,585],[0.9,480],[0.99,390]]` |

> P0.99 = proReference (345/390) inchangé → champion reste P99.

### run_5k (`points`, dir −1)
| Sexe | champion | **intermediate** (=P50) | **occasional** | **nouveaux nodes** |
|---|---|---|---|---|
| male | 1020 | **1800** *(était 1380)* | **2520** *(était 2400)* | `[[0.1,2640],[0.5,1800],[0.9,1200],[0.99,1020]]` |
| female | 1170 | **2040** *(était 1620)* | **2820** *(était 2700)* | `[[0.1,2940],[0.5,2040],[0.9,1350],[0.99,1170]]` |

> Intermédiaire = joggeur loisir médian (30 min/5 km H, 34 min F). P0.90/0.99 inchangés
> (champion à P99). Forte indulgence demandée ⇒ médiane bien ralentie.

### profil_express (`points`, dir −1) — séance d'entrée, estimation moteur
| Sexe | champion | **intermediate** (=P50) | **occasional** | **nouveaux nodes** |
|---|---|---|---|---|
| male | 205 | **400** *(était 342)* | **600** *(était 536)* | `[[0.1,640],[0.5,400],[0.9,240],[0.99,205]]` |
| female | 232 | **470** *(était 401)* | **740** *(était 668)* | `[[0.1,760],[0.5,470],[0.9,272],[0.99,232]]` |

> Médiane ralentie (l'entrée doit récompenser le débutant qui finit). P0.90/0.99 inchangés
> → le profil express ne sur-note pas l'élite. NB : c'est de l'estimé (radar complet en `estimated`),
> l'indulgence ici sert surtout au **premier ressenti** d'onboarding.

---

## 6. Récapitulatif des effets de bord à gérer (note ingé)

1. **`league_hybrid_chipper`** : relever `hardMax` de **900 → 1200** (H et F), sinon l'occasionnel
   1020/1080 s est clampé. C'est la seule modif hors `model` autorisée par cette recalibration
   (sécurité du clamp), à valider avec le PO.
2. **Grace** : penser à recalculer `mean` du helper `lnArithMean` (j'ai donné 252/290 pour
   viser médiane 230/268) ; **ajouter un test** vérifiant `quantile(0.5) ≈ intermédiaire`.
3. **Monotonie** : pour tous les `time`, vérifier `champion < intermediate < occasional` ;
   pour `reps`/`load`/tours, `champion > intermediate > occasional`. Tous les nombres ci-dessus
   respectent la monotonie.
4. **Tests de score** (couverture élevée, exigée par la constitution) : ajouter, par WOD et sexe,
   trois assertions — `subScore(champion) ≳ 950`, `subScore(intermediate) ∈ [450,560]`,
   `subScore(occasional) ∈ [120,230]`. Si un cas sort de ces bornes, ajuster σ (pas le palier).
5. **`pointTable`** : ne pas piloter par σ ; reporter les nœuds tels quels (§5). P0.90/P0.99
   restent **identiques** à l'existant pour préserver le percentile du champion / `proReference`.
6. **Champion / proReference** : aucune valeur de `champion` ni de `proReference` n'a été modifiée
   dans tout ce document. Seuls `intermediate`, `occasional` et les `model` bougent.

---

## 7. Sources et niveau de confiance

- **Distributions course** (3k/5k/1k/10000m/semi/marathon) : RunRepeat « Marathon / Half-Marathon
  Statistics » + Marastats/IAAF (percentiles de finish par sexe). Confiance **moyenne-haute**.
- **CrossFit benchmarks** (Fran, Grace, Helen, Jackie, Karen, Cindy) : bases de temps publiques
  (BTWB / Beyond the Whiteboard, WODBoard). Médiane *loisir* ré-estimée vers le bas par décision
  produit (anti-frustration) → confiance **moyenne**, à recalibrer N≥200/sexe.
- **Rameur 2k** : tables Concept2 logbook (percentiles par sexe). Confiance **haute** ; médiane
  élargie volontairement vers le débutant.
- **Force / calisthénie** (pompes, tractions, squats, squat 1RM) : normes ACSM + StrengthLevel,
  réinterprétées « loisir 3-6 mois » (sous le niveau « Intermediate » de StrengthLevel). Confiance
  **moyenne**.
- **WODs Ligue + Benchmark Zéro + Profil Express** : barèmes **estimés** (`low`), à recalibrer
  sur la communauté après le 1er mois. Confiance **basse** (assumé, marqué dans le code).
- Les percentiles « champ→P / occ→P » de ce doc sont des **estimations analytiques** (z-scores),
  pas des mesures terrain ; ils servent à garantir la cohérence paliers↔scoring, pas à publier.
