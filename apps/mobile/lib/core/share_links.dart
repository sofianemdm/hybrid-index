/// Liens PARTAGEABLES de l'app (WhatsApp/SMS/réseaux). Chaque lien pointe vers le site web ;
/// sur un téléphone avec l'APK installé, les App Links Android (cf. AndroidManifest + go_router)
/// ouvrent directement le BON écran de l'app. Sans l'app → le site web (repli universel).
library;

/// Base publique de l'app (le site Netlify — même domaine que les App Links du manifest).
// URL RÉELLE du site Netlify de prod (cf. mémoire deploy-prod-topology) : `hybrid-index.netlify.app`
// n'a JAMAIS existé — la renommer casserait CORS_ORIGINS + l'origine Google OAuth, donc on pointe
// l'existante. Si un domaine propre arrive un jour (athleteleague.fr), changer ICI uniquement.
const String kAppWebBase = 'https://scintillating-rolypoly-582e42.netlify.app';

/// Lien d'invitation générique (page d'accueil).
String inviteLink() => kAppWebBase;

/// Lien vers le détail d'une séance (ex. « viens battre mon temps sur Fran »).
String wodLink(String wodId) => '$kAppWebBase/seance/$wodId';

/// Lien vers le profil public d'un athlète.
String profileLink(String userId) => '$kAppWebBase/profil/$userId';

/// Pages légales publiques (hébergées avec la version web ; URLs déclarées aux stores).
String legalPrivacyUrl() => '$kAppWebBase/legal/confidentialite.html';
String legalTermsUrl() => '$kAppWebBase/legal/cgu.html';
