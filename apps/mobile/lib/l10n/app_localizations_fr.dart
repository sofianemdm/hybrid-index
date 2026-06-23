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
}
