// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Your comparable hybrid-fitness score.';

  @override
  String get navHome => 'Home';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navCommunity => 'Community';

  @override
  String get navProgress => 'Progress';

  @override
  String get navLeaderboard => 'Ranking';

  @override
  String get commonRetry => 'Retry';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'System';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get authLogIn => 'Log in';

  @override
  String get authCreateAccount => 'Create my account';

  @override
  String get authSignInAction => 'Sign in';

  @override
  String get authUsername => 'Username';

  @override
  String get authPassword => 'Password (8+)';

  @override
  String get authDateOfBirth => 'Date of birth';

  @override
  String get authChoose => 'Choose…';

  @override
  String get authOr => 'or';

  @override
  String get ageRestricted => 'You must be at least 13.';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonLogout => 'Log out';

  @override
  String get onbAvatarTitle => 'Create your avatar';

  @override
  String get onbAvatarSubtitle =>
      'Personalize it (you can change it anytime in settings).';

  @override
  String get onbRevealTitle => 'Reveal your Index';

  @override
  String get onbRevealSubtitle =>
      'One effort is enough. Add more for a more precise Index.';

  @override
  String get onbMaxPushups => 'Max strict push-ups (one set)';

  @override
  String get onbMaxSquats => 'Max bodyweight squats (one set)';

  @override
  String get onbRevealCta => 'Reveal my HYBRID INDEX';

  @override
  String get onbRunTitle => 'Run (enter your distance)';

  @override
  String get onbRunHint =>
      'E.g. 3 km in 15:00. We compute your pace and adjust it to any distance.';

  @override
  String get onbEstimatedIndexHere => 'Your estimated Index will appear here.';

  @override
  String get onbEstimatedIndexLabel => 'ESTIMATED INDEX';

  @override
  String get onbNeedEffort => 'Add a run, push-ups or squats.';

  @override
  String get onbRunNeedsBoth =>
      'Distance (0.4–42 km) and time required for the run.';
}
