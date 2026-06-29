# Plan d'architecture — Temps réel des messages (WebSocket)

> Auteur : Architecte. Statut : PROPOSITION (à valider avant code).
> Objectif : pousser instantanément au DESTINATAIRE un signal léger quand il reçoit un DM,
> pour rafraîchir le fil / la liste de conversations sans attendre le poll.
> Principe directeur : **ADDITIF, JAMAIS RÉGRESSIF**. Le polling REST actuel reste en place
> comme filet de sécurité ; le WebSocket n'est qu'une couche d'accélération par-dessus.

---

## 0. État actuel (constat, non modifié par ce plan)

- Backend : `MessagingService.send()` (`apps/api/src/modules/messaging/messaging.service.ts`)
  crée le message en base et appelle `notifyRecipient()` (push FCM best-effort). Aucune notification
  temps réel en cours de session.
- Front chat (`apps/mobile/lib/features/messaging/chat_screen.dart`) : `Timer.periodic` à **2 s**
  (`_startPolling` / `_pollMessages`), suspendu en arrière-plan, ré-armé au `resumed`.
- Front liste (`apps/mobile/lib/features/messaging/conversations_screen.dart`) : `Timer.periodic`
  à **3 s** (`_load`).
- Auth : JWT Bearer, secret partagé via `JwtModule.register({ secret: resolveJwtSecret() })`
  (`apps/api/src/modules/auth/auth.module.ts`), payload `{ sub: userId, email }`, expiration 30 j.
  Le `JwtAuthGuard` vérifie en plus que le compte est `active` (cache Redis `usrok:{id}`, 60 s).
- CORS : `apps/api/src/app.config.ts`, `CORS_ORIGINS` (liste) ou `*` en dev ; web Flutter sur `:8080`,
  api sur `:3000`.
- Le token côté Flutter est porté par `ApiClient` (`setToken`), persisté `shared_preferences`
  clé `hi_token` ; base URL = `Env.apiBaseUrl` (`apps/mobile/lib/core/env.dart`).

Coût du polling actuel : à 2 s/3 s par client ouvert, la charge croît linéairement avec le nombre
de sessions actives. Le WebSocket supprime ce coût pour les conversations inactives (un client au
repos n'émet plus de requêtes) tout en réduisant la latence de réception de ~2 s à < 200 ms.

---

## 1. TRANSPORT — RAW WebSocket (recommandé), PAS socket.io

### Décision : `@nestjs/platform-ws` + `ws` (back) / `package:web_socket_channel` (Flutter).

**Pourquoi raw WS et non socket.io :**

1. **Protocole léger.** socket.io ajoute sa propre couche d'engine.io (handshake HTTP préalable,
   trames d'enveloppe `42["event",payload]`, heartbeat propriétaire, fallback long-polling). On n'a
   besoin d'aucune de ces fonctions : notre événement est un simple JSON `{type,conversationId}`.
   Le raw WS = une seule trame texte, zéro overhead protocolaire.

2. **Compatibilité Flutter Web.** `package:web_socket_channel` s'appuie sur l'API `WebSocket`
   native du navigateur (`dart:html`) en Web et sur `dart:io` en mobile, via une seule API
   `WebSocketChannel.connect(uri)`. Le client officiel socket.io pour Dart n'est pas maintenu par
   l'équipe socket.io et alourdit l'app ; `web_socket_channel` est maintenu par l'équipe Dart et
   pèse très peu. **Contrainte projet : l'app tourne aussi en Web (démo navigateur)** → la pile
   native WebSocket est le choix sûr.

3. **Dépendances minimales.** Back : `@nestjs/platform-ws` + `ws` (+ `@types/ws`). Pas de
   `@nestjs/websockets` côté socket.io ni d'`engine.io`. Front : un seul package Dart.

4. **Pas de fonctionnalités socket.io requises.** On n'utilise ni rooms riches, ni acks, ni
   namespaces, ni reconnexion « magique » : notre besoin est unidirectionnel (serveur → client,
   signal de refresh). Le multiplexage par utilisateur, on le fait nous-mêmes avec une `Map`
   simple. Le fallback réseau, c'est notre polling REST conservé.

**Conséquence build :** rester sur `@nestjs/platform-ws` permet d'utiliser le `WebSocketGateway`
de Nest sans embarquer socket.io. Le serveur HTTP Nest (Express) et le serveur WS partagent le
**même port** (`PORT`/`API_PORT`/3000) : `ws` se greffe sur l'`upgrade` HTTP. Aucun port
supplémentaire à exposer en prod.

> Note dépendances : le `pnpm-lock.yaml` référence déjà `@nestjs/websockets` comme peer optionnel
> de `@nestjs/platform-ws`. À l'installation, ajouter explicitement dans `apps/api/package.json` :
> `@nestjs/platform-ws`, `@nestjs/websockets`, `ws`, et en dev `@types/ws`. Installer avec
> `NODE_OPTIONS=--use-system-ca pnpm install` (CA système — cf. MEMORY).

---

## 2. AUTH — JWT à la connexion, réutilise le secret/stratégie REST

### 2.1 Passage du token

Le navigateur **ne permet pas** d'ajouter des en-têtes custom à `new WebSocket()`. Pour rester
Web-compatible, le token transite en **query param** : `wss://host/ws/messaging?token=<JWT>`.
(En mobile, `web_socket_channel` accepte aussi les headers, mais on garde le query param unique
pour un seul code path.)

Risque connu du token en query : journalisation d'URL. Mitigation :
- Ne JAMAIS logger l'URL de connexion complète côté gateway (logger uniquement `userId` une fois
  validé).
- Le JWT a déjà une portée de session (30 j) identique à celui des appels REST ; on n'introduit
  pas de surface nouvelle. (Évolution possible : court-lived « ticket WS » émis par un endpoint REST
  authentifié, échangé à la connexion — hors périmètre de ce premier incrément, noté en §6.)

### 2.2 Validation au handshake

Le gateway valide le token **à la connexion** (`handleConnection`) en réutilisant **exactement**
la même brique que REST :
- `JwtService.verify()` avec le **même secret** (le `JwtModule` est `@Global`, donc `JwtService`
  est injectable dans le gateway sans reconfigurer le secret) → garantit un seul secret de vérité.
- Même contrôle « compte actif » que `JwtAuthGuard.isActive()` : on **extrait cette logique dans un
  service partagé réutilisable** (`AuthTokenService`, voir §6) afin que REST et WS partagent le
  cache Redis `usrok:{id}` et ne divergent jamais.

Échec de validation (token absent / invalide / expiré / compte non actif) ⇒ on **ferme** la socket
immédiatement avec un code applicatif clair (close code `4401` « unauthorized », convention
4xxx = espace applicatif). Le client interprète `4401` comme « ne pas retenter avec ce token »
(re-login requis) plutôt que comme une coupure réseau.

### 2.3 Registre userId → sockets (multi-onglets / multi-device)

Un même utilisateur peut avoir plusieurs sockets ouvertes (plusieurs onglets, mobile + web).
Le gateway tient un registre en mémoire :

```
private readonly sockets = new Map<string /*userId*/, Set<WebSocket>>();
```

- `handleConnection` : après validation, `sockets.get(userId) ?? new Set()`, `.add(ws)`, on stocke
  `userId` sur l'instance socket (`(ws as any).userId`) pour le retrouver à la déconnexion.
- `handleDisconnect` : retirer la socket du `Set` ; si le `Set` devient vide, supprimer la clé.
- `emitToUser(userId, payload)` : itère sur le `Set` et `ws.send(JSON.stringify(payload))` sur
  chaque socket `readyState === OPEN`. No-op si l'utilisateur n'a aucune socket (déconnecté → le
  polling REST / la notif push prendront le relais).

**Heartbeat / sockets mortes.** `ws` expose `ping`/`pong`. Le gateway envoie un `ping` toutes les
~30 s ; toute socket sans `pong` au cycle suivant est terminée (`ws.terminate()`) et retirée du
registre. Indispensable derrière les proxies/load-balancers (Railway) qui coupent les connexions
inactives.

> **Portée mono-instance.** Le registre `Map` est local au process. Tant que l'API tourne en
> **une seule instance** (cas actuel Railway), c'est suffisant et correct. Le passage multi-instance
> nécessitera un bus Redis Pub/Sub (chaque instance publie l'event, toutes les instances le
> relaient à leurs sockets locales). Documenté en §5 / §6 comme évolution, **non implémenté ici**
> (YAGNI tant qu'on est mono-instance). Le contrat d'event ne change pas : seule l'implémentation
> de `emitToUser` évoluera.

---

## 3. ÉVÉNEMENTS — signal léger, jamais le contenu

À l'envoi d'un DM, `MessagingService.send()` notifie le DESTINATAIRE (et l'expéditeur, pour le
multi-device) via un event minimal :

```jsonc
// Reçu d'un nouveau DM (pour le destinataire ET les autres sockets de l'expéditeur)
{ "type": "dm", "conversationId": "<uuid>" }
```

**Pourquoi pas le contenu complet :**
- Sécurité/cohérence : le client refetch via REST (`GET /v1/conversations/:id/messages`), qui
  applique déjà filtrage modération (`status: visible`), pagination par curseur, et **marquage
  « lu »**. Pousser le corps dupliquerait cette logique et risquerait des incohérences (message
  masqué après coup, accusés de lecture).
- Légèreté : un signal de refresh suffit à supprimer la latence du poll. La source de vérité reste
  REST.

**Where it fires.** Dans `MessagingService.send()`, **après** la création du message (transaction
réussie), en best-effort non bloquant (comme `notifyRecipient`) :

```
this.realtime.emitToUser(toUserId, { type: "dm", conversationId: conv.id });
this.realtime.emitToUser(me,        { type: "dm", conversationId: conv.id }); // multi-device expéditeur
```

- `me === toUserId` impossible (interdit par `assertCanDm`), pas de double envoi à craindre.
- Émission **best-effort** : enveloppée pour ne jamais faire échouer l'envoi REST si le gateway a
  un souci (try/catch interne à `emitToUser`). Le DM est déjà persisté ; le temps réel est un bonus.
- L'event est émis **après** le commit DB pour qu'un refetch immédiat du client voie bien le message.

**Évolutions d'event (non implémentées, réservées) :** on garde un champ `type` discriminant pour
pouvoir ajouter sans casse `{ type: "read", conversationId }` (accusés de lecture temps réel) ou
`{ type: "typing", conversationId }` plus tard. Le client **ignore tout `type` inconnu** (forward-
compatible).

---

## 4. CLIENT — service de connexion + abonnements, polling conservé en filet

### 4.1 Service `RealtimeService` (nouveau)

Fichier `apps/mobile/lib/data/realtime_service.dart`. Responsabilités :

- **Connexion** : `WebSocketChannel.connect(Uri.parse('$wsBaseUrl/ws/messaging?token=$token'))`.
  `wsBaseUrl` dérivé de `Env.apiBaseUrl` (http→ws, https→wss) + override `WS_BASE_URL`
  (`String.fromEnvironment`) pour la prod.
- **Expose un `Stream<RealtimeEvent>`** (broadcast) ; les écrans s'y abonnent. `RealtimeEvent` =
  `{ type, conversationId }` (parsé depuis le JSON ; events inconnus filtrés).
- **Reconnexion auto avec backoff exponentiel + jitter** : 1 s, 2 s, 4 s… plafonné à ~30 s,
  réinitialisé à la première trame reçue. Se déclenche sur fermeture inattendue.
  - **Sauf** sur close code `4401` (auth) : on **n'insiste pas** (le token est mauvais → laisser la
    session gérer le re-login). On loggue et on reste déconnecté jusqu'au prochain `connect()`.
- **Cycle de vie / batterie** : suspendre la connexion en arrière-plan (`AppLifecycleState.paused`)
  et reconnecter au `resumed` — symétrique du polling actuel.
- **Fermeture propre** : `dispose()` ferme le channel (`sink.close(status.normalClosure)`) et annule
  le timer de backoff. Appelée au `logout()` (et token change ⇒ reconnexion avec le nouveau token).
- **Intégration session** : connecter quand `AuthStatus.loggedIn` (et token connu), déconnecter au
  `logout`. Branché via Riverpod (`realtimeServiceProvider`), démarré dans le bootstrap de session.

### 4.2 Abonnements écrans

- **`chat_screen.dart`** : s'abonner au stream ; sur event `type=='dm' && conversationId==_convId`,
  appeler `_pollMessages()` (déjà silencieux, déjà protégé contre l'écrasement d'historique). Aucun
  changement de logique d'affichage — on **déclenche** simplement le `_load`/`_pollMessages` existant
  plus tôt que le timer.
- **`conversations_screen.dart`** : sur **tout** event `type=='dm'`, appeler `setState(_load)`
  (refresh de la liste — non-lus, dernier message, ordre).

### 4.3 Fallback — le polling RESTE (ralenti)

**Impératif : additif, jamais régressif.** Le polling existant n'est pas supprimé, il est
**ralenti** quand le WS est connecté et **rétabli au rythme nominal** s'il tombe :

- Chat : 2 s → **10 s** quand WS connecté ; revient à 2 s si WS down.
- Liste : 3 s → **10 s** quand WS connecté ; revient à 3 s si WS down.

Mécanisme : `RealtimeService` expose aussi un `ValueListenable<bool> connected`. Chaque écran
choisit l'intervalle du `Timer.periodic` selon cet état (re-arme le timer au changement). Ainsi :
- WS OK → latence < 200 ms via push, poll lent en sécurité (rattrape un event manqué).
- WS KO (proxy, réseau, gateway down) → on retombe exactement sur le comportement actuel, **zéro
  régression**.

Aucun fichier de modèle/REST n'est modifié ; le client `ApiClient` reste la source de vérité du
contenu.

---

## 5. CORS / ORIGINE — accepter `:8080` en local, `wss` en prod

### Local
- Web Flutter sert sur `http://localhost:8080`, api+WS sur `:3000`. Le **handshake WebSocket est une
  requête HTTP `Upgrade`** : le navigateur applique sa propre vérification d'`Origin` mais n'est pas
  soumis au CORS « fetch » classique. On **valide l'`Origin` manuellement** dans le gateway
  (`verifyClient` de `ws`) contre la **même liste `CORS_ORIGINS`** que REST (réutilisation directe
  de la conf de `app.config.ts`), pour ne pas accepter de connexions d'origines arbitraires.
- En dev (`CORS_ORIGINS` absent) : accepter toute origine (parité avec le `*` REST actuel).
- Ajouter explicitement `http://localhost:8080` à `CORS_ORIGINS` en dev si on resserre.

### Prod (Railway / Netlify)
- L'API derrière HTTPS Railway ⇒ le client doit utiliser **`wss://`** (TLS). La dérivation
  http→ws / **https→wss** côté Flutter le garantit.
- Railway termine TLS et proxifie l'`Upgrade` WebSocket vers le process Node (supporté nativement) ;
  pas de config réseau spéciale, **même port** que l'API.
- `CORS_ORIGINS` prod doit lister l'origine Netlify (ex. `https://<site>.netlify.app`) — déjà requis
  par REST (`app.config.ts` lève une erreur si absent en prod), donc **aucune variable nouvelle**
  pour le WS.
- Heartbeat ping/pong (§2.3) indispensable : les proxies coupent les connexions WS inactives.

### Multi-instance (futur, non implémenté)
Si Railway scale > 1 instance, le registre `Map` en mémoire ne voit que les sockets locales.
Solution : **Redis Pub/Sub** (`RedisService` déjà présent) — `emitToUser` publie sur un canal
`rt:user:{id}`, chaque instance est abonnée et relaie à ses sockets locales. Le **contrat d'event
ne change pas**. Noté comme évolution ; YAGNI tant qu'on est mono-instance.

---

## 6. DÉCOUPAGE EN INCRÉMENTS + FICHIERS

Chaque incrément est petit, testable, et **non régressif** (le polling reste à chaque étape).

### Incrément 1 — Brique d'auth partagée (refactor sûr, zéro comportement nouveau)
Extraire la validation token+statut de `JwtAuthGuard` dans un service réutilisable, pour que REST et
WS partagent une seule vérité (secret + cache Redis `usrok`).
- **Nouveau** `apps/api/src/modules/auth/auth-token.service.ts`
  — `verifyToken(token): Promise<AuthenticatedUser>` (verify JWT + `isActive`), throw si invalide.
- **Modifié** `apps/api/src/modules/auth/jwt-auth.guard.ts` — délègue à `AuthTokenService`
  (comportement identique ; tests existants doivent rester verts).
- **Modifié** `apps/api/src/modules/auth/auth.module.ts` — provide + export `AuthTokenService`.
- **Test** `apps/api/test/auth-token.service.spec.ts` (ou unit) — token valide/invalide/expiré,
  compte non actif, cache Redis.

### Incrément 2 — Gateway WebSocket + registre (back, sans émission encore)
- **Nouveau** `apps/api/src/modules/realtime/realtime.gateway.ts`
  — `@WebSocketGateway({ path: '/ws/messaging' })`, `handleConnection` (valide via
  `AuthTokenService`, ferme `4401` si KO, enregistre), `handleDisconnect`, `verifyClient` (Origin
  vs `CORS_ORIGINS`), heartbeat ping/pong.
- **Nouveau** `apps/api/src/modules/realtime/realtime.service.ts`
  — registre `Map<userId, Set<WebSocket>>`, `register`/`unregister`/`emitToUser` (best-effort).
- **Nouveau** `apps/api/src/modules/realtime/realtime.module.ts` — déclare gateway + service,
  exporte `RealtimeService`. Importe `AuthModule` (pour `AuthTokenService`).
- **Modifié** `apps/api/src/app.module.ts` — importe `RealtimeModule`.
- **Modifié** `apps/api/package.json` — deps `@nestjs/platform-ws`, `@nestjs/websockets`, `ws`,
  dev `@types/ws`.
- **Modifié** `apps/api/src/main.ts` — `app.useWebSocketAdapter(new WsAdapter(app))` (adapter `ws`).
- **Test** `apps/api/test/realtime.e2e.spec.ts` — connexion avec token valide OK ; token absent/
  invalide ⇒ close `4401` ; multi-sockets pour un user ; `emitToUser` atteint toutes les sockets ;
  déconnexion nettoie le registre.

### Incrément 3 — Émission à l'envoi d'un DM (back)
- **Modifié** `apps/api/src/modules/messaging/messaging.service.ts` — injecter `RealtimeService`,
  émettre `{ type:'dm', conversationId }` au destinataire **et** à l'expéditeur après commit
  (best-effort).
- **Modifié** `apps/api/src/modules/messaging/messaging.module.ts` — importer `RealtimeModule`.
- **Test** `apps/api/test/messaging.e2e.spec.ts` (étendu) — après `POST /v1/messages`, le
  destinataire connecté en WS reçoit l'event `{type:'dm',conversationId}` ; l'expéditeur multi-device
  aussi ; aucun event si destinataire déconnecté (et l'envoi REST reste 200).

### Incrément 4 — Service client Flutter + reconnexion (front, pas encore branché aux écrans)
- **Modifié** `apps/mobile/pubspec.yaml` — `web_socket_channel: ^3.0.0`.
- **Nouveau** `apps/mobile/lib/data/realtime_service.dart` — connexion (ws/wss dérivé d'`Env`),
  `Stream<RealtimeEvent>` broadcast, backoff+jitter, no-retry sur `4401`, cycle de vie, `dispose`,
  `ValueListenable<bool> connected`.
- **Modifié** `apps/mobile/lib/core/env.dart` — `WS_BASE_URL` optionnel (défaut dérivé d'`apiBaseUrl`).
- **Modifié** `apps/mobile/lib/data/session.dart` — `realtimeServiceProvider` ; connecter au login/
  bootstrap, fermer au logout (passage du token).
- **Test** `apps/mobile/test/realtime_service_test.dart` — parse d'event valide/inconnu ; pas de
  retry sur close `4401` ; backoff croît puis se réinitialise.

### Incrément 5 — Abonnement des écrans + polling ralenti (front)
- **Modifié** `apps/mobile/lib/features/messaging/chat_screen.dart` — abonnement stream → trigger
  `_pollMessages` sur event de la conversation courante ; intervalle de poll 2 s↔10 s selon
  `connected`.
- **Modifié** `apps/mobile/lib/features/messaging/conversations_screen.dart` — abonnement stream →
  `_load` sur tout event `dm` ; intervalle 3 s↔10 s selon `connected`.
- **Test** widget : à réception d'un event simulé, l'écran déclenche son `_load`/`_pollMessages` ;
  WS down ⇒ l'intervalle de poll revient au rythme nominal (non régressif).

### Incrément 6 (futur, NON implémenté maintenant) — robustesse prod
- Ticket WS court-lived (endpoint REST → token éphémère échangé à la connexion), pour ne plus passer
  le JWT de session en query.
- Redis Pub/Sub dans `emitToUser` pour le multi-instance.
- Events additionnels (`read`, `typing`) sur le même canal (champ `type` déjà discriminant).

---

## Résumé des décisions

1. **Transport : RAW WebSocket** (`@nestjs/platform-ws` + `ws` côté Nest, `WsAdapter` ; `web_socket_channel`
   côté Flutter), **pas socket.io** : protocole léger, Web-compatible, dépendances minimales, et on
   n'utilise aucune fonctionnalité avancée de socket.io. Partage le **même port** que l'API.
2. **Auth : JWT de session en query param** (`?token=`, seul mode Web-compatible), validé au
   handshake avec le **même secret et le même contrôle « compte actif »** que REST — logique
   **extraite dans `AuthTokenService`** partagé par le guard REST et le gateway. Échec ⇒ close `4401`.
3. **Multi-onglets/device** géré par un registre `Map<userId, Set<socket>>` ; `handleDisconnect`
   nettoie ; heartbeat ping/pong tue les sockets mortes (Railway). Mono-instance pour l'instant
   (Redis Pub/Sub réservé au multi-instance).
4. **Événement minimal `{ type:'dm', conversationId }`** poussé au destinataire **et** à l'expéditeur
   (multi-device) **après commit**, en **best-effort** (n'échoue jamais l'envoi REST). Pas de contenu :
   le client **refetch via REST** (qui gère modération/pagination/accusés de lecture). Champ `type`
   discriminant pour évolutions sans casse ; le client ignore les `type` inconnus.
5. **Client : `RealtimeService`** expose un `Stream` d'events ; `chat_screen` et
   `conversations_screen` s'y abonnent pour déclencher leur `_load()/_pollMessages()`. Reconnexion
   auto (**backoff + jitter**, pas de retry sur `4401`), suspension en arrière-plan, fermeture propre.
6. **Polling conservé en filet, ralenti** (chat 2 s→10 s, liste 3 s→10 s quand WS connecté ; rythme
   nominal restauré si WS down). **Additif, jamais régressif** : si le WS tombe, comportement
   strictement identique à aujourd'hui.
7. **CORS/Origine** : validation manuelle de l'`Origin` au handshake (`verifyClient`) contre la même
   liste `CORS_ORIGINS` que REST ; **`http://localhost:8080` en dev**, origine Netlify en prod ;
   client en **`wss://`** en prod (dérivation https→wss), même port, Railway proxifie l'`Upgrade`
   nativement. Aucune variable d'environnement nouvelle obligatoire.
8. **Découpage en 5 incréments livrables** (auth partagée → gateway → émission → service client →
   abonnement+poll ralenti), chacun testé, plus un incrément 6 « futur » (ticket WS, Redis Pub/Sub,
   events `read`/`typing`). **Aucun test existant cassé** ; le contrat REST de la messagerie est
   inchangé.
