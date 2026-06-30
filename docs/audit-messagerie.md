# Audit messagerie temps réel (DM) — Athlete League

> Audit LECTURE SEULE réalisé le 30/06/2026 par l'agent « expert messagerie temps réel ».
> Périmètre : chaîne complète d'un message direct, du `POST /v1/messages` jusqu'à l'affichage
> chez le destinataire — backend (messaging + realtime + push) et mobile (WS + chat + badge).
>
> **NOTE GLOBALE : 6,5 / 10.** Architecture saine et prudente (WS auth au handshake, registre
> multi-device, heartbeat, reconnexion backoff, optimiste à l'envoi, accusés de lecture + typing
> déjà amorcés). MAIS l'instantanéité réelle est plombée par **deux défauts de conception** qui
> répondent exactement au problème signalé par l'humain :
> 1. le WS ne transporte PAS le message → le destinataire fait un **round-trip REST** à chaque DM ;
> 2. le push « nouveau message » passe par un **gating (quietHours + dailyCap=2/jour)** qui le
>    SUPPRIME silencieusement la nuit et au-delà de 2 notifs/jour.

---

## 1. Cartographie de la chaîne actuelle

### Backend
- `messaging.service.ts` — `send()` : valide → upsert conversation → crée le message → `notifyRecipient()` (push) → `emitToUser(dest, {type:'dm', conversationId})` + `emitToUser(moi, …)`. **Le payload WS ne contient AUCUN contenu** (ni id, ni body, ni senderId, ni createdAt) — juste `conversationId`. Commentaire explicite dans le code : « Pas de contenu : le client refetch via REST ».
- `messages()` : pagination curseur descendante + marquage « lu » de la page la plus récente → si ≥1 message marqué, `emitToUser(other, {type:'read'})`.
- `relayTyping()` : valide la participation + blocage, puis `emitToUser(other, {type:'typing'})`.
- `realtime.service.ts` — registre en mémoire `userId -> Set<socket>`, `emitToUser` best-effort, **mono-instance** (pas de Redis Pub/Sub).
- `realtime.gateway.ts` — `ws` brut, path `/ws/messaging`, auth token au handshake (même secret que REST), origine vérifiée, heartbeat ping/pong 30 s. Canal montant : `typing` uniquement.
- `push.service.ts` — `notifyNewMessage()` → `sendToUser()` → **`gate()`** (opt-out + quietHours + dailyCap + cooldown) → FCM HTTP v1 avec bloc `notification:` + `data:{type:'new-message'}` (PAS de `conversationId` dans `data`).

### Mobile
- `realtime_service.dart` — WS app-level, connecté **au login** (`sessionProvider` → `connect()`, `fireImmediately:true`), suspendu en arrière-plan, repris au premier plan, reconnexion backoff+jitter, pas de retry sur close 4401. Émet 3 events typés : `DmReceived`, `ReadReceipt`, `TypingSignal` — **tous ne portent que `conversationId`** (reflet fidèle du backend).
- `chat_screen.dart` — sur `DmReceived(convId == ouvert)` → **`_pollMessages()`** = `GET /v1/conversations/:id/messages` (REST). Poll de repli `Timer.periodic(5 s)`. Optimiste à l'envoi (`_pending`), puis refetch complet après `sendMessage`. `ReadReceipt` → `_markAllMineRead()` (local, instantané). `TypingSignal` → indicateur 3 s.
- `conversations_screen.dart` — sur `DmReceived` → `setState(_load)` (refetch liste REST). Poll repli 10 s.
- `app.dart` `inboxBadgeProvider` — `StreamProvider` : s'abonne au WS, un `DmReceived` réveille un `Completer` → refetch `conversations()` immédiat. Poll repli **4 s si WS down, 20 s si WS up**. Suspendu hors premier plan.
- `push_service.dart` — FCM ; foreground → bannière snackbar ; tap → route. `new-message` → onglet Communauté + `ConversationsScreen` (**PAS le chat précis**, faute de `conversationId` dans `data`).

---

## 2. Latence de bout en bout — réponses précises aux 4 questions

### Q1 — B envoie à A, A EST dans la conversation : par quel chemin ? quelle latence ? pourquoi pas « direct » ?
**Chemin actuel (2 sauts réseau séquentiels) :**
1. `send()` persiste + `emitToUser(A, {type:'dm', conversationId})` → WS arrive chez A (~quelques ms à dizaines de ms).
2. `chat_screen` reçoit `DmReceived` → appelle `_pollMessages()` → **nouveau round-trip REST** `GET …/messages` (DB + sérialisation + réseau) → `setState`.

**Latence estimée : ~150–500 ms** en bon réseau (le WS est quasi instantané, mais on RAJOUTE un aller-retour HTTP complet derrière), et bien pire en réseau dégradé/cold DB. Pire encore : `_pollMessages()` **ne fait rien si l'utilisateur n'est pas `_isNearBottom()`** (remontée d'historique) — le nouveau message peut alors n'apparaître qu'au prochain retour en bas.

**Pourquoi pas « direct » ?** Décision de conception assumée (« le WS ne porte qu'un signal, REST est la source de vérité »). C'est robuste mais **non instantané** : on a le coût d'un WS SANS le bénéfice (zéro round-trip). Une vraie messagerie pro pousse le **message complet** dans la trame WS et l'**append** directement.

### Q2 — A n'est PAS dans la conversation : la pastille/notif arrive-t-elle « à la seconde » ?
- **App au premier plan, hors écran chat** : OUI quasi instantané pour la PASTILLE. `inboxBadgeProvider` est abonné au WS et réveille son `Completer` sur `DmReceived` → refetch `conversations()` immédiat (~1 round-trip REST). Bon. **Mais aucun bandeau/toast in-app** n'est montré (seul le chiffre de la cloche bouge) → l'utilisateur sur un autre onglet ne « voit » pas vraiment le message arriver.
- **App en arrière-plan / tuée** : dépend ENTIÈREMENT du **push FCM**, et c'est là le problème majeur — voir §3. Le push « new-message » est **gaté** : supprimé en quietHours (22:00–07:00 par défaut) et **après 2 notifs/jour (dailyCap par défaut = 2, tous types confondus)**. Donc « à la seconde » N'EST PAS GARANTI : la nuit, ou dès la 3ᵉ notif de la journée, le destinataire ne reçoit **rien**.
- **Cooldown** : `new-message` a `cooldown:"0"` (bon, pas de throttle par type), mais le dailyCap global l'écrase quand même.

### Q3 — Le WS est-il connecté dès le login au niveau APP (pas seulement écran messagerie monté) ?
**OUI.** `realtimeServiceProvider` écoute `sessionProvider` avec `fireImmediately:true` : dès `AuthStatus.loggedIn`, `connect()`. Indépendant des écrans messagerie. C'est correct et c'est une bonne base. Le provider n'est toutefois instancié que s'il est `read`/`watch` quelque part tôt — `inboxBadgeProvider` le `read` ; à vérifier qu'il est bien monté dès `HomeShell` (sinon la connexion ne démarre qu'à la première lecture du badge).

### Q4 — Robustesse : ordre, doublons, reconnexion, accusés de lecture, typing
- **Ordre** : backend trie `createdAt` puis `id` (tie-breaker déterministe) — bon. Côté client, l'append se fait via refetch complet → pas de problème d'ordre, mais au prix de la latence.
- **Doublons (optimiste vs WS vs poll)** : géré par le **remplacement intégral** de `_messages` par la vérité serveur après chaque send/poll + suppression du `_pending` correspondant. Ça évite les doublons MAIS au prix de re-rendus complets et de sauts de scroll. Il n'y a **pas de dédup par id** (réconciliation fine optimiste↔serveur) — indispensable dès qu'on passera à l'append direct.
- **Reconnexion** : backoff exponentiel plafonné 30 s + jitter, pas de retry sur 4401, reprise au premier plan, `_pollMessages()` de rattrapage au resume. Solide. **Trou** : pendant une coupure WS, les events `dm/read/typing` émis sont **perdus** (best-effort, pas de file ni de « catch-up » dédié) — heureusement le poll repli (5 s chat / 4 s badge) rattrape, mais ça ré-introduit de la latence.
- **Accusés de lecture** : `read` poussé en temps réel → `_markAllMineRead()` local instantané. Bon. Limite : un seul event « tout lu », pas de granularité par message (suffisant pour du 1-à-1).
- **Typing** : débounce 2 s à l'émission, extinction 3 s à la réception, coupé par blocage. Propre.

---

## 3. Défauts classés

### P0 — Bloquants pour « instantané »
1. **WS sans contenu → round-trip REST sur chaque message reçu** (`messaging.service.ts` send, `chat_screen.dart` `_pollMessages`). C'est LA cause n°1 du « pas assez instantané » signalé. Ajoute 150–500 ms+ inutiles et casse l'affichage quand on n'est pas en bas du fil.
2. **Push DM soumis au gating quietHours + dailyCap** (`push.service.ts` `gate()` appliqué à `new-message`). Les notifs « à la seconde » sont **supprimées la nuit et au-delà de 2/jour**. Contredit frontalement la demande de l'humain. Un message direct 1-à-1 est une notif transactionnelle, pas marketing : elle ne doit JAMAIS être throttlée comme un nudge d'engagement.

### P1 — Importants
3. **Aucun bandeau in-app hors écran chat** (premier plan, autre onglet) : seule la pastille bouge. Une vraie messagerie pro affiche un toast « X : <message> » cliquable.
4. **Push new-message sans `conversationId` dans `data`** → impossible de deep-linker vers le bon chat (on tombe sur la liste). (`push.service.ts` compose + `push_service.dart` `_route`.)
5. **Perte d'events pendant coupure WS** : pas de mécanisme de catch-up dédié (on dépend du poll repli). Acceptable aujourd'hui, à blinder.

### P2 — Robustesse / dette
6. **Pas de dédup par id côté client** — bloquant DÈS qu'on append en direct (P0-1).
7. **Mono-instance** : `RealtimeService` en mémoire. En multi-instance (scaling Railway), un message envoyé via l'instance A n'atteint pas un socket connecté à l'instance B. Pas un souci tant qu'1 seule instance, mais à anticiper (Redis Pub/Sub).
8. **`_jumpToEnd()` systématique au poll** peut interrompre la lecture si l'utilisateur n'est pas tout en bas (atténué par le garde `_isNearBottom`, mais le saut reste brutal lors d'un refetch complet).

---

## 4. Plan 10/10 — incréments actionnables

> Objectif : message ENTRANT affiché **directement** (zéro round-trip) dans le chat ouvert, et
> notif/pastille **à la seconde** hors conversation, sans dépendre du polling. Ordre = impact/risque.

### Incrément 1 — Le WS transporte le message complet + append direct (cœur du problème) ⭐
**Ce qu'on fait :**
- Backend `send()` : enrichir la trame WS au destinataire ET à l'expéditeur avec le message complet :
  `{type:'dm', conversationId, message:{id, senderId, body, createdAt, sentAt, readAt:null, isMine:false}}`
  (calculer `isMine` par destinataire, ou laisser le client le dériver de `senderId`).
- Client `realtime_service.dart` : enrichir `DmReceived` pour porter un `DmMessage?` (parser le sous-objet `message`). Rétro-compatible : si `message` absent → comportement actuel (refetch).
- Client `chat_screen.dart` : sur `DmReceived` avec message, **append direct** dans `_messages` (plus de `_pollMessages`), avec **dédup par id** (ignorer si id déjà présent ; remplacer un `_pending` optimiste correspondant). Conserver `_pollMessages` UNIQUEMENT comme repli quand le payload ne porte pas le message (WS down → poll).
- Réconciliation optimiste : à la réception de MON propre message via WS (multi-device) ou de la réponse REST `send()`, faire correspondre par id serveur et retirer le `tmp_…`.

**Fichiers :** `apps/api/src/modules/messaging/messaging.service.ts`, `apps/api/src/modules/realtime/realtime.service.ts` (élargir `RealtimeEvent`), `apps/mobile/lib/data/realtime_service.dart`, `apps/mobile/lib/features/messaging/chat_screen.dart`.
**Risque :** moyen — dédup/ordre à tester (optimiste vs WS vs poll). Mitigation : map par id + tests e2e « B→A append sans REST ». **Gain : latence ~150–500 ms → ~10–50 ms (1 saut WS).**

### Incrément 2 — Push DM exempté du gating quietHours/dailyCap (notif « à la seconde ») ⭐
**Ce qu'on fait :**
- Dans `gate()` (ou via un flag sur le trigger), traiter les notifs **transactionnelles** (`new-message`, et idéalement `comment-reply`/`mention`) comme **non throttlables** : on conserve l'opt-out par préférence (l'utilisateur garde le contrôle) mais on RETIRE quietHours + dailyCap + cooldown pour ces clés. Reco : ajouter un champ `transactional: true` dans `NOTIFICATION_TRIGGERS` et court-circuiter le gating si `transactional` (sauf opt-out explicite).
- Garder le `notificationLog` pour l'audit, mais ne pas faire COMPTER les DM dans le dailyCap des nudges (ou les loguer dans un type exclu du comptage).

**Fichiers :** `apps/api/src/modules/engagement/push.service.ts` (`gate()` / `sendToUser`), `apps/api/src/modules/engagement/notifications.data.ts` (flag `transactional`), `apps/api/src/modules/engagement/notification-gating.ts` (helper `isTransactional`).
**Risque :** faible — bien borné aux clés transactionnelles, l'opt-out reste respecté. Tests : un 3ᵉ DM le même jour et un DM à 23 h DOIVENT partir.

### Incrément 3 — `conversationId` dans le push + deep-link vers le bon chat
**Ce qu'on fait :**
- Backend : ajouter `conversationId` (et `senderName`) dans `data` du push `new-message`. Passer `conversationId` à `notifyRecipient`/`notifyNewMessage`.
- Mobile `push_service.dart` `_route` : pour `new-message`, ouvrir directement `ChatScreen(conversationId, otherUserId, otherName)` au lieu de la liste.

**Fichiers :** `messaging.service.ts`, `push.service.ts`, `notifications.data.ts`, `apps/mobile/lib/data/push_service.dart`.
**Risque :** faible. Veiller à inclure `otherUserId`/`otherName` dans `data` pour construire `ChatScreen`.

### Incrément 4 — Bandeau in-app temps réel hors écran chat (premier plan)
**Ce qu'on fait :**
- Un listener WS app-level (au niveau `HomeShell` ou via un provider monté dès le login) qui, sur `DmReceived` **alors qu'on n'est PAS dans ce chat**, affiche un toast/bandeau « <expéditeur> : <aperçu> » cliquable (réutiliser `appMessengerKey` comme le foreground push). Le message complet de l'Incrément 1 fournit l'aperçu sans REST.
- Mettre à jour la pastille en même temps (déjà fait par `inboxBadgeProvider`).

**Fichiers :** `apps/mobile/lib/app.dart` (ou un nouveau widget observateur monté dans `HomeShell`), `apps/mobile/lib/features/home/home_shell.dart`.
**Risque :** faible/moyen — éviter le bandeau quand on EST déjà dans le chat concerné (vérifier le `_convId` courant via un provider d'« écran actif »).

### Incrément 5 — Dédup/ordre/reconnexion blindés + catch-up
**Ce qu'on fait :**
- Dédup par id généralisée (map `id -> DmMessage`) dans `chat_screen`, tri stable `createdAt,id`.
- Au retour de connexion WS (`channel.ready` après une coupure) : déclencher un **catch-up** explicite (`_pollMessages` + refresh badge) — déjà partiellement fait au resume lifecycle, à étendre au cas « WS reconnecté sans changement de lifecycle ».
- Scroll : n'auto-scroller que si `_isNearBottom()` au moment de l'append (déjà la logique, à conserver avec l'append direct).

**Fichiers :** `apps/mobile/lib/data/realtime_service.dart` (exposer un event/callback « reconnected »), `apps/mobile/lib/features/messaging/chat_screen.dart`.
**Risque :** faible.

### Incrément 6 (anticipation scaling) — Redis Pub/Sub pour le multi-instance
**Ce qu'on fait :** quand on passera à >1 instance API, `emitToUser` publie sur un canal Redis `rt:user:<id>` ; chaque instance s'abonne et délivre à ses sockets locales. Le contrat `emitToUser` ne change pas.
**Fichiers :** `apps/api/src/modules/realtime/realtime.service.ts` (+ provider Redis).
**Risque :** moyen — à ne lancer QUE quand le scaling l'exige (aujourd'hui mono-instance suffit). À documenter comme dette connue.

---

## 5. Latences mesurées/estimées & chemin le plus court vers « instantané »

| Scénario | Aujourd'hui | Après plan |
|---|---|---|
| A dans le chat, B envoie | WS + **1 round-trip REST** ≈ **150–500 ms** (pire si pas en bas / cold DB) | **1 saut WS ≈ 10–50 ms** (append direct) |
| A hors chat, premier plan | pastille ≈ 1 round-trip REST sur event WS (~100–300 ms), **pas de bandeau** | pastille immédiate + **bandeau in-app instantané** |
| A en arrière-plan / tué | push FCM **mais supprimé la nuit / au-delà de 2 notifs/jour** | push **toujours délivré** (transactionnel), deep-link vers le chat |
| Accusé de lecture | WS `read` → instantané (déjà bon) | inchangé |
| Typing | WS, débounce 2 s / extinction 3 s (déjà bon) | inchangé |

**Chemin le plus court vers « instantané » (2 incréments suffisent pour répondre à l'humain) :**
- **Incrément 1** (WS porte le message → append direct) règle « message qui apparaît DIRECTEMENT dans la conversation ouverte ».
- **Incrément 2** (push DM exempté de quietHours/dailyCap) règle « notif à la seconde ».
Les incréments 3–6 sont du polish (deep-link, bandeau in-app, robustesse, scaling).

**NOTE : 6,5 / 10.** Bonnes fondations (WS app-level dès le login, auth, reconnexion, optimiste,
read/typing temps réel). Les deux P0 ci-dessus sont la différence entre « ça marche avec un léger
délai » et « vraie messagerie pro instantanée ». Une fois les incréments 1 et 2 livrés : **≥ 9/10**.
