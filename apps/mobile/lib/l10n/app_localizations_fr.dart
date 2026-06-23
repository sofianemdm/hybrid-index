// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTagline =>
      'Ton score de condition physique hybride, comparable.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSessions => 'Séances';

  @override
  String get navCommunity => 'Communauté';

  @override
  String get navProgress => 'Progrès';

  @override
  String get navLeaderboard => 'Classement';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'Système';

  @override
  String get authSignUp => 'Inscription';

  @override
  String get authLogIn => 'Connexion';

  @override
  String get authCreateAccount => 'Créer mon compte';

  @override
  String get authSignInAction => 'Se connecter';

  @override
  String get authUsername => 'Pseudo';

  @override
  String get authPassword => 'Mot de passe (8+)';

  @override
  String get authDateOfBirth => 'Date de naissance';

  @override
  String get authChoose => 'Choisir…';

  @override
  String get authOr => 'ou';

  @override
  String get ageRestricted => 'Tu dois avoir au moins 13 ans.';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonLogout => 'Déconnexion';

  @override
  String get onbAvatarTitle => 'Crée ton avatar';

  @override
  String get onbAvatarSubtitle =>
      'Personnalise-le (modifiable à tout moment dans les paramètres).';

  @override
  String get onbRevealTitle => 'Révèle ton Index';

  @override
  String get onbRevealSubtitle =>
      'Un effort suffit. Ajoutes-en plus pour un Index plus précis.';

  @override
  String get onbMaxPushups => 'Max pompes strictes (une série)';

  @override
  String get onbMaxSquats => 'Max squats à vide (une série)';

  @override
  String get onbRevealCta => 'Révéler mon HYBRID INDEX';

  @override
  String get onbRunTitle => 'Course (saisis ta distance)';

  @override
  String get onbRunHint =>
      'Ex. 3 km en 15:00. On calcule ton allure et on l’ajuste à toutes distances.';

  @override
  String get onbEstimatedIndexHere => 'Ton Index estimé s’affichera ici.';

  @override
  String get onbEstimatedIndexLabel => 'INDEX ESTIMÉ';

  @override
  String get onbNeedEffort => 'Ajoute une course, des pompes ou des squats.';

  @override
  String get onbRunNeedsBoth =>
      'Distance (0,4–42 km) et temps requis pour la course.';
}
