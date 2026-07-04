# Architecture Auth v1 — Athlete League

Statut : SPEC (à valider avant implémentation). Auteur : architect. Date : 2026-07-04.

Contexte : l'ancienne auth (branche `wipe-auth`, teardown au HEAD) a été RASÉE. Le module
`apps/api/src/modules/auth/` a été supprimé en entier. Deux shims temporaires tiennent l'app
debout et doivent être remplacés :

- Back : `apps/api/src/common/current-user.decorator.ts` — renvoie un `DEV_USER_ID` fixe
  (ou l'en-tête `x-dev-user`), SANS aucune vérification de token.
- Front : `apps/mobile/lib/data/session.dart` — session factice `loggedIn`, token `'dev'`
  injecté dans `apiClientProvider` ; `apps/mobile/lib/app.dart` route directement vers
  `HomeShell` et affiche un `_AuthPlaceholder` quand le profil est `null`.

Objectif : reconstruire une auth email + mot de passe simple, propre, robuste (10/10), sans
reproduire les bugs vécus. Google/Apple = phase 2 optionnelle (le code existe en git et se
rebranche presque tel quel — voir §8).

Bonne nouvelle constatée à l'inspection : le schéma Prisma, le `MailService`, la
`ZodValidationPipe`, le `RateLimitGuard`, le `HttpExceptionFilter` (avec CORP cross-origin) et
les helpers `@hybrid-index/contracts` (`MIN_AGE_YEARS`, `isOldEnough`, `Sex`, `Goal`) sont
TOUJOURS EN PLACE. Seul le dossier `modules/auth/` a été supprimé. **Aucune migration de base
n'est nécessaire.**

---

## 1. Modèle de données

### 1.1 État actuel (schema.prisma) — INTACT, aucune migration

Le modèle `User` (lignes 156-198) a déjà tout ce qu'il faut :

```
model User {
  id                  String   @id @default(uuid()) @db.Uuid
  email               String?  @unique
  passwordHash        String?  @map("password_hash")
  dateOfBirth         DateTime @map("date_of_birth") @db.Date
  ageVerified         Boolean  @default(false) @map("age_verified")
  consents            Json
  status              String   @default("active")
  ...
  identities        AuthIdentity[]
  passwordResets    PasswordResetCode[]
  profile           Profile?
  ...
}
```

Sont également présents et réutilisés tels quels :
- `AuthIdentity` (`provider`, `providerSubject`, unique `[provider, providerSubject]`) — sert
  l'identité `email` (phase 1) et Google/Apple (phase 2).
- `PasswordResetCode` (`codeHash`, `expiresAt`, `attempts`) — flux « mot de passe oublié ».
- `Profile.displayName` (unique) — pseudo verrouillé.

**Décision migration : NON.** `prisma generate` suffit (le client TS peut avoir été régénéré
lors du teardown ; le vérifier au démarrage). Ne PAS lancer `prisma migrate` / `db push` : le
schéma n'est pas modifié. Si un `prisma migrate status` signalait une dérive, la traiter à part
— elle n'est pas causée par ce chantier.

### 1.2 Hachage du mot de passe : `bcryptjs`, cost 10 — DÉCISION

On garde **`bcryptjs`** (déjà la dépendance historique du repo, pur JS, aucune compilation
native — crucial sous Windows/PowerShell et sur Railway sans toolchain C++), cost factor **10**.

Justification vs argon2 :
- argon2 (node-argon2) exige un binding natif → risque de casse au build (Windows + Railway),
  contraire à l'objectif « robuste, pas de surprise de déploiement ».
- bcrypt cost 10 reste tout à fait sûr pour une app grand public gratuite à données déclarées
  (~100 ms/hash, borne le brute-force). Le rate-limit login (§3.3) est la vraie défense de
  premier rang.
- Continuité : tous les comptes/tests existants et le flux reset utilisent déjà bcryptjs. Pas
  de migration de hash, pas de double algorithme à maintenir.

Règle : hacher email en minuscules trim avant recherche/unicité ; ne JAMAIS logguer le hash ni
le mot de passe.

---

## 2. Stratégie de token : JWT access SEUL, longue durée + révocation par statut — DÉCISION

**Choix : un seul JWT d'accès, `expiresIn: 30d`, PAS de refresh token.**

Justification (simplicité + sûreté pour une app gratuite grand public) :
- Un access+refresh ajoute un endpoint `/refresh`, un stockage de refresh tokens, une rotation
  et une logique de révocation à double étage — sur-ingénierie ici. Les salles ont un mauvais
  réseau : moins d'allers-retours d'auth = mieux.
- La révocation NÉCESSAIRE (compte supprimé / banni) est déjà couverte SANS refresh par le
  contrôle « compte actif » côté serveur : `AuthTokenService.isActive()` vérifie
  `User.status === 'active'` à chaque requête, avec cache Redis `usrok:{id}` (TTL 60 s). Un
  compte désactivé est rejeté en ≤ 60 s, JWT encore valide ou non. **Jamais fail-open** : si
  Redis est down, on interroge la DB (un compte banni reste rejeté).
- Payload minimal : `{ sub: userId, email }`. Aucune donnée sensible. Signé HS256.

Durée : **30 jours**. À l'échéance, l'utilisateur ressaisit ses identifiants (rare, acceptable
pour du grand public gratuit). Pas de rotation silencieuse à maintenir.

### 2.1 Stockage côté client
- Clé `SharedPreferences` : **`hi_token`** (nom historique, on le conserve).
- Écrit à l'inscription/connexion, lu au démarrage (`bootstrap()` → auto-login), supprimé au
  `logout()`.
- Injecté dans `ApiClient.setToken(token)` → en-tête `Authorization: Bearer <token>` et exposé
  via `ApiClient.token` pour le handshake WebSocket (`?token=`).

### 2.2 Secret JWT
- `process.env.JWT_SECRET`. **Obligatoire en production** (refuser de démarrer sinon). Défaut
  `dev-secret-...-not-for-prod` UNIQUEMENT hors production (fonction `resolveJwtSecret()`
  reprise de l'ancien `auth.module.ts`). Aucun secret en dur committé.

---

## 3. Contrats d'API

Enveloppe d'erreur commune (posée par `HttpExceptionFilter`, CORP `cross-origin` garanti) :
`{ "error": { "code": string, "message": string, "details"?: object } }`.

Succès `AuthResponse` :
```json
{ "token": "<jwt>", "user": { "id": "uuid", "email": "a@b.com", "displayName": "Neo" } }
```

Validation via `ZodValidationPipe` (DTO zod, cf. §5). Email toujours `toLowerCase().trim()`.

### 3.1 POST /v1/auth/register
Corps :
```json
{
  "email": "a@b.com",
  "password": "min 8 chars",
  "displayName": "2..24 chars",
  "dateOfBirth": "2005-04-01",
  "sex": "male|female",
  "goal": "all_round (défaut)",
  "equipmentPref": "none|equipped|both (défaut both)"
}
```
Réponses :
- `201` → `AuthResponse`.
- `400 VALIDATION_ERROR` — champ invalide (email mal formé, password < 8, displayName hors 2..24).
- `403 AGE_RESTRICTED` — `isOldEnough(dateOfBirth) === false` (MIN_AGE_YEARS = 15). Vérifié
  AVANT toute écriture.
- `409 CONFLICT` — email déjà utilisé OU pseudo déjà pris (message distinct, code identique).
  Gérer aussi la course concurrente Prisma `P2002` → 409 ciblé (jamais 500).
- `429 RATE_LIMITED` — 30 inscriptions / heure / IP.

### 3.2 POST /v1/auth/login
Corps : `{ "email": "a@b.com", "password": "..." }`.
Réponses :
- `200` → `AuthResponse`.
- `400 VALIDATION_ERROR` — email absent/mal formé, password vide.
- `401 UNAUTHENTICATED` — **message NON énumérant** : « Identifiants invalides. » pour TOUS les
  cas (email inconnu, compte social sans passwordHash, mot de passe faux). Aucune distinction.
- `429 RATE_LIMITED` — 20 tentatives / 15 min / IP.

### 3.3 POST /v1/auth/forgot  (mot de passe oublié)
Corps : `{ "email": "a@b.com" }`. Réponse **TOUJOURS** `200 { "ok": true }` (aucune énumération
d'emails, même si inconnu ou compte social). Anti-spam cooldown 60 s par compte. Code 6 chiffres
haché bcrypt, TTL 15 min, 5 essais. Rate-limit 5 / 15 min / IP. Envoi via `MailService`.

### 3.4 POST /v1/auth/reset
Corps : `{ "email": "...", "code": "123456", "newPassword": "min 8" }`. Réponse `200 { ok:true }`.
Erreur UNIQUE et générique `400 RESET_INVALID` (code faux / expiré / trop d'essais / email
inconnu) — rien révélé. Compteur d'essais incrémenté AVANT comparaison. Rate-limit 10 / 15 min / IP.

### 3.5 Flux profil — GET /v1/me/profile (déjà en place, à NE PAS modifier)
Après register/login, le front lit `GET /v1/me/profile` :
- `200` → profil complet (Index révélé) → `HomeShell`.
- `404 NOT_FOUND` → profil incomplet → **onboarding**. C'EST NORMAL, pas une erreur.
  **Le 404 DOIT porter `Cross-Origin-Resource-Policy: cross-origin`** (déjà garanti par
  `HttpExceptionFilter` ligne ~65). Côté front, `myProfile()` reconnaît le 404 → renvoie `null`
  (déjà implémenté dans `api_client.dart`). NE PAS régresser ce comportement.

Note : à l'inscription, le `Profile` est créé (displayName/sex/goal/equipmentPref) mais l'Index
n'est révélé qu'après ~3 WODs. Le routage onboarding vs home se fait sur la présence de l'Index
dans le profil, pas sur le 404 seul — respecter la logique existante de `myProfile()`.

### 3.6 (Refresh ?) — NON. Pas d'endpoint refresh en v1 (cf. §2).

---

## 4. Guard + décorateur réels (remplacent les shims)

On restaure la brique d'auth partagée de l'ancien code (elle était bonne). Emplacement :
`apps/api/src/modules/auth/`.

### 4.1 `AuthTokenService` (vérité unique REST + WS)
`verifyToken(rawJwt)` :
1. token absent → `401 UNAUTHENTICATED`.
2. `jwt.verify` échoue → `401 UNAUTHENTICATED` (« Token invalide ou expiré »).
3. `isActive(sub)` false → `401` (« Session expirée. Reconnecte-toi »).
4. sinon → `{ userId: sub, email }`.
`isActive()` : cache Redis `usrok:{id}` (60 s), repli DB, **jamais fail-open**.

### 4.2 `JwtAuthGuard`
Lit `Authorization: Bearer`, délègue à `AuthTokenService`, pose `request.user`. Appliqué
globalement OU par contrôleur (voir §5.4 : décision d'application).

### 4.3 `current-user.decorator.ts` (le remplaçant du shim)
Le shim actuel (`common/current-user.decorator.ts`) est REMPLACÉ par la version qui lit
`request.user` (posé par le guard). **Point clé de compatibilité** : ~20 contrôleurs importent
`{ CurrentUser, AuthenticatedUser }` depuis `"../../common/current-user.decorator"`. Pour NE PAS
toucher ces 20 fichiers, on **garde le chemin `common/current-user.decorator.ts`** comme façade
qui ré-exporte le vrai décorateur et le type :
```ts
export type { AuthenticatedUser } from "../modules/auth/auth-token.service";
export { CurrentUser } from "../modules/auth/current-user.decorator";
```
`DEV_USER_ID` disparaît (plus de shim). Vérifier qu'aucun code de PROD ne l'importe hors des
shims (realtime.gateway l'importe — voir §4.4).

### 4.4 WebSocket handshake (remise en sécurité)
`realtime.gateway.ts` (lignes ~91-94) prend aujourd'hui le `?token=` TEL QUEL comme userId.
À remplacer par la vraie validation :
- Injecter `AuthTokenService` dans le gateway (rebrancher la dépendance `AuthModule` dans
  `realtime.module.ts`, retirée au teardown).
- `const { userId } = await authToken.verifyToken(token)`. En cas d'échec → `client.close(4401)`
  (constante `CLOSE_UNAUTHORIZED` déjà définie). Supprimer l'import `DEV_USER_ID`.
- Conserver la vérification d'origine existante.

### 4.5 Rate-limit `by: 'user'` (remise en sécurité)
`rate-limit.guard.ts` limite aujourd'hui TOUT par IP (le `by:'user'` était neutralisé au
teardown). Rebrancher : quand `opts.by === 'user'`, lire `request.user?.userId` (posé par le
guard, si la route est protégée) et l'utiliser comme identité ; repli sur IP si absent. NE PAS
faire confiance à un id fourni par le client — uniquement `request.user` validé.

---

## 5. Plan fichier par fichier

### 5.1 Back — à CRÉER (recopier depuis git `be515db~1`, adapter)
Récupération : `git show be515db~1:<path>` pour chaque fichier ci-dessous.

- `apps/api/src/modules/auth/auth.dto.ts` — DTO zod (RegisterRequest, LoginRequest,
  ForgotPasswordRequest, ResetPasswordRequest ; Google/Apple en phase 2). Réutiliser tel quel.
- `apps/api/src/modules/auth/auth.service.ts` — register / login / forgotPassword /
  resetPassword. **Retirer** en phase 1 les méthodes `google()` / `apple()` et les imports des
  verifiers (les remettre en phase 2). Garder `sign()`, `uniqueViolation()`, messages non
  énumérants. bcryptjs cost 10.
- `apps/api/src/modules/auth/auth.controller.ts` — routes register/login/forgot/reset avec
  `@RateLimit`. Retirer les routes google/apple en phase 1.
- `apps/api/src/modules/auth/auth-token.service.ts` — tel quel (vérité REST+WS).
- `apps/api/src/modules/auth/jwt-auth.guard.ts` — tel quel.
- `apps/api/src/modules/auth/optional-jwt-auth.guard.ts` — tel quel (routes publiques qui
  surlignent l'utilisateur connecté).
- `apps/api/src/modules/auth/current-user.decorator.ts` — tel quel (lit `request.user`).
- `apps/api/src/modules/auth/auth.module.ts` — `@Global`, `JwtModule.register({ secret:
  resolveJwtSecret(), signOptions: { expiresIn: '30d' } })`, providers AuthService +
  AuthTokenService + guards, exports AuthTokenService/guards/JwtModule. Retirer verifiers +
  Google/Apple en phase 1. Garder l'import `MailModule` (forgot/reset).

### 5.2 Back — à MODIFIER
- `apps/api/src/common/current-user.decorator.ts` — remplacer le SHIM par la façade de
  ré-export (§4.3). Supprime `DEV_USER_ID` / `x-dev-user`.
- `apps/api/src/app.module.ts` — importer `AuthModule` (le premier des imports, `@Global`).
  Décision d'application du guard : voir §5.4.
- `apps/api/src/modules/realtime/realtime.module.ts` — réimporter `AuthModule` (retiré au
  teardown) pour injecter `AuthTokenService`.
- `apps/api/src/modules/realtime/realtime.gateway.ts` — vraie validation du token au handshake
  (§4.4) ; retirer l'import `DEV_USER_ID`.
- `apps/api/src/common/rate-limit.guard.ts` — rebrancher `by:'user'` sur `request.user.userId`
  (§4.5).

### 5.3 Back — tests (à recréer depuis git, ajuster au périmètre phase 1)
- `apps/api/test/auth-token.service.spec.ts` — verifyToken (absent/invalide/inactif/ok, cache
  Redis, non fail-open).
- `apps/api/test/auth.e2e.spec.ts` (NOUVEAU ou repris) — register (201, 409 email, 409 pseudo,
  403 âge, 400 validation), login (200, 401 non énumérant), forgot/reset (200 générique,
  RESET_INVALID), + vérifier l'en-tête CORP `cross-origin` sur une réponse d'erreur (garde
  anti-régression du bug 04/07). Base de test dédiée (`hybrid_index_test` + Redis db1) — cf.
  mémoire projet.

### 5.4 Décision — application du `JwtAuthGuard`
**Recommandation : guard global** via `APP_GUARD`, avec un décorateur `@Public()` (metadata)
pour whitelister les routes non authentifiées : `POST /v1/auth/*`, `GET /v1/meta/app`,
`GET /health`, et les routes publiques de lecture (leaderboard/profils publics) qui utilisent
déjà `OptionalJwtAuthGuard`. Avantage : aucune route protégée ne peut être oubliée (fail-safe).
Alternative plus simple mais risquée : `@UseGuards(JwtAuthGuard)` par contrôleur (20 fichiers) —
rejetée (risque d'oubli = fuite de données). **À VALIDER avec toi** : le passage en guard global
doit vérifier que les endpoints publics existants (leaderboard, profils publics, meta) sont bien
marqués `@Public()` sinon ils casseront. C'est le seul point structurant — je fais l'inventaire
exact des routes publiques avant de coder.

### 5.5 Front — `apps/mobile/lib/data/api_client.dart` (recréer les méthodes)
Remplacer le bloc balisé `--- Auth --- (auth-rebuild)` par les méthodes (reprises de
`be515db~1`), passant par `_send` (donc bénéficiant du `_retryDelay` isolé + gestion enveloppe) :
```dart
Future<({String token, AuthUser user})> register(Map<String, dynamic> payload);   // POST /v1/auth/register
Future<({String token, AuthUser user})> login(String email, String password);      // POST /v1/auth/login
Future<void> forgotPassword(String email);                                          // POST /v1/auth/forgot
Future<void> resetPassword(String email, String code, String newPassword);          // POST /v1/auth/reset
```
NE PAS toucher `_send` / `_retryDelay` / l'extraction d'enveloppe (patterns anti-bug déjà en
place et load-bearing). `AuthUser` existe déjà dans `models.dart`.

### 5.6 Front — `apps/mobile/lib/data/session.dart` (réécriture en vraie session)
Reprendre la version `be515db~1:apps/mobile/lib/data/session.dart` (déjà complète et correcte) :
- `apiClientProvider` : `Provider<ApiClient>((ref) => ApiClient())` — **retirer** le
  `setToken('dev')`.
- Clé `_kToken = 'hi_token'`, persistance via `shared_preferences`.
- `bootstrap()` : lit `hi_token` → si null `loggedOut` ; sinon `setToken`, `me()`, `identify`,
  `loggedIn` ; en cas d'échec purge token + `loggedOut`.
- `register()` / `login()` : appellent l'API, `_persist(token)`, `Analytics.identify`, état
  `loggedIn`.
- `logout()` : `Analytics.reset`, reset onglet home, `prefs.remove(_kToken)`, `setToken(null)`,
  `loggedOut`.
- `refreshMe()` : conservée (déjà appelée par les réglages).
- Ajouter `forgotPassword` / `resetPassword` (délégation simple à l'`ApiClient`).
- `SessionNotifier(...)` démarre en `AuthStatus.loading` (plus `loggedIn` factice).

### 5.7 Front — `apps/mobile/lib/app.dart` (câblage AuthGate)
Restaurer l'aiguillage à 3 états :
- `session.status == loading` → `_Splash`.
- `session.status == loggedOut` → **écran de connexion / création de compte** (à recréer, cf.
  5.8) — remplace `_AuthPlaceholder`.
- `session.status == loggedIn` → `myProfile.when(...)` :
  - `loading` → `_Splash` ; `error` → `ErrorRetry` ;
  - `data == null` (404 → profil incomplet) → **onboarding** ;
  - `data != null` → `HomeShell`.
Appeler `session.bootstrap()` au démarrage (dans `main.dart` ou au premier build du gate).

### 5.8 Front — écran d'auth (à recréer)
`apps/mobile/lib/features/auth/auth_screen.dart` (repris/inspiré de `be515db~1`, version
email-only en phase 1) : onglets Connexion / Créer un compte, champs email + mot de passe
(+ displayName, date de naissance, sexe, préférence matériel à l'inscription), lien « mot de
passe oublié » (`forgot_password_screen.dart`). Gérer les 4 états (vide/chargement/erreur/succès)
et mapper les codes d'erreur : `CONFLICT` → message sur le champ concerné, `AGE_RESTRICTED` →
message âge, `UNAUTHENTICATED` → « Identifiants invalides », `RATE_LIMITED` → « Trop de
tentatives ». Boutons Google/Apple = phase 2 (le code existe en git).

### 5.9 Onboarding (à recréer — hors périmètre strict de l'auth mais requis par l'AuthGate)
L'onboarding a été supprimé (`_AuthPlaceholder`). Le rebrancher est nécessaire pour que le
routage `profil null → onboarding` mène quelque part. À traiter comme incrément SÉPARÉ, après
l'auth. Le back onboarding (`/v1/onboarding/*`) et les méthodes client ont été retirés au
teardown → même chantier de restauration depuis git. **Signalé** : à planifier explicitement.

---

## 6. Sécurité & états d'erreur (récapitulatif des garde-fous)

- Secrets via env uniquement : `JWT_SECRET` (obligatoire en prod), `DATABASE_URL`, mail, etc.
  Aucun secret en dur. `resolveJwtSecret()` refuse de démarrer en prod sans secret.
- Login non énumérant : `401 UNAUTHENTICATED` identique pour tous les échecs.
- Forgot non énumérant : `200 { ok:true }` systématique. Reset : `400 RESET_INVALID` unique.
- Hachage bcryptjs cost 10 ; jamais de hash/mot de passe dans les logs.
- Rate-limits : register 30/h, login 20/15min, forgot 5/15min, reset 10/15min (par IP).
  `RateLimitGuard` non fail-open (repli mémoire si Redis down).
- Révocation compte (supprimé/banni) via `status !== 'active'`, contrôlé à chaque requête
  (cache 60 s), non fail-open.
- **CORP `cross-origin` sur TOUTE réponse, erreurs comprises** — déjà garanti par
  `HttpExceptionFilter` (ligne ~65) et `helmet({ crossOriginResourcePolicy: 'cross-origin' })`
  dans `app.config.ts`. Test e2e anti-régression exigé (§5.3). Ne JAMAIS repasser en
  `same-origin` (bug « serveur injoignable » vécu le 04/07).
- Web release dart2js : ne PAS introduire de `Future.delayed` générique dans `_send` ; le
  pattern `_retryDelay()` isolé + `@pragma('dart2js:noInline')` reste intact.
- Service worker web : déploiement `--pwa-strategy=none` ; prévoir un client qui ne laisse pas
  un vieux SW servir un build périmé (hors périmètre auth, rappelé pour le déploiement).

---

## 7. Validation attendue avant implémentation
1. OK pour **bcryptjs cost 10** (pas argon2) ? 
2. OK pour **JWT access seul 30 j, sans refresh** (révocation par statut) ?
3. OK pour **guard global + `@Public()`** (vs `@UseGuards` par contrôleur) — le seul point
   structurant (§5.4) ?
4. Confirmer que la restauration de l'**onboarding** (§5.9) est un incrément séparé planifié
   après l'auth.

## 8. Phase 2 (optionnelle) — Google / Apple
Rebranchable presque tel quel depuis git : `google-verifier.ts`, `apple-verifier.ts`, méthodes
`google()`/`apple()` de `auth.service.ts`, routes `/v1/auth/google|apple`, DTO GoogleAuthRequest
/AppleAuthRequest, boutons front. Nécessite `GOOGLE_CLIENT_ID` / `APPLE_BUNDLE_ID` en env. Flux
déjà conçu (identité connue → login ; email existant → liaison ; sinon création avec profil +
age-gate). AUCUNE migration (modèle `AuthIdentity` déjà présent).
