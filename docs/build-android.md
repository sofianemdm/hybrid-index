# Mettre HYBRID INDEX sur ton téléphone Android

Le projet Flutter contient désormais la **plateforme Android** (`apps/mobile/android/`). Il ne
manque que la **toolchain Android** (le SDK), qui s'installe via Android Studio. Une fois fait, tu
génères un APK installable sur ton téléphone.

## 1. Installer la toolchain (une seule fois)
1. Installe **Android Studio** : https://developer.android.com/studio
2. Au premier lancement, accepte l'installation du **Android SDK** + **SDK Platform-Tools**.
3. Accepte les licences :
   ```powershell
   & 'C:\flutter\bin\flutter.bat' doctor --android-licenses
   ```
4. Vérifie :
   ```powershell
   & 'C:\flutter\bin\flutter.bat' doctor
   ```
   La ligne **Android toolchain** doit être ✓.

## 2. Construire l'APK
```powershell
cd "E:\HYBRID INDEX\hybrid-index-starter\hybrid-index\apps\mobile"
& 'C:\flutter\bin\flutter.bat' build apk --release --dart-define=API_BASE_URL=http://TON_IP_LOCALE:3000
```
- Remplace `TON_IP_LOCALE` par l'IP de ton PC sur le réseau Wi-Fi (ex. `192.168.1.20`) : le téléphone
  doit pouvoir joindre l'API. (`http://localhost:3000` ne marche PAS depuis le téléphone.)
- Le backend doit tourner sur le PC (`.\demarrer-app.ps1` ou les services manuels) et le PC et le
  téléphone être sur le **même réseau**. Pense à autoriser le port 3000 dans le pare-feu Windows.
- L'APK est généré dans `build\app\outputs\flutter-apk\app-release.apk`.

## 3. Installer sur le téléphone
- **Le plus simple** : branche le téléphone en USB (mode débogage activé) puis :
  ```powershell
  & 'C:\flutter\bin\flutter.bat' run --release --dart-define=API_BASE_URL=http://TON_IP_LOCALE:3000
  ```
- **Ou** : copie `app-release.apk` sur le téléphone et installe-le (autoriser les sources inconnues).

## Notes
- **iOS** : nécessite un Mac + Xcode (impossible sur Windows). Le code Flutter est identique.
- **Connexion Google** : pour l'activer sur mobile, ajoute `GOOGLE_CLIENT_ID` (serveur + app) et le
  package `google_sign_in` (cf. docs/decisions-log.md D11). Sinon, email + mot de passe fonctionnent.
- **Notifications push (FCM)** : nécessite un projet Firebase (google-services.json). Le flux in-app
  (`/v1/me/notifications/feed`) fonctionne déjà sans Firebase.
