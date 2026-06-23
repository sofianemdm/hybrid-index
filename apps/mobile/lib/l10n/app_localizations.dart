import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your comparable hybrid-fitness score.'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// No description provided for @navLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get navLeaderboard;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogIn;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create my account'**
  String get authCreateAccount;

  /// No description provided for @authSignInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInAction;

  /// No description provided for @authUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsername;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (8+)'**
  String get authPassword;

  /// No description provided for @authDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get authDateOfBirth;

  /// No description provided for @authChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get authChoose;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @ageRestricted.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 13.'**
  String get ageRestricted;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get commonLogout;

  /// No description provided for @onbAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your avatar'**
  String get onbAvatarTitle;

  /// No description provided for @onbAvatarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize it (you can change it anytime in settings).'**
  String get onbAvatarSubtitle;

  /// No description provided for @onbRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Reveal your Index'**
  String get onbRevealTitle;

  /// No description provided for @onbRevealSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One effort is enough. Add more for a more precise Index.'**
  String get onbRevealSubtitle;

  /// No description provided for @onbMaxPushups.
  ///
  /// In en, this message translates to:
  /// **'Max strict push-ups (one set)'**
  String get onbMaxPushups;

  /// No description provided for @onbMaxSquats.
  ///
  /// In en, this message translates to:
  /// **'Max bodyweight squats (one set)'**
  String get onbMaxSquats;

  /// No description provided for @onbRevealCta.
  ///
  /// In en, this message translates to:
  /// **'Reveal my HYBRID INDEX'**
  String get onbRevealCta;

  /// No description provided for @onbRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Run (enter your distance)'**
  String get onbRunTitle;

  /// No description provided for @onbRunHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. 3 km in 15:00. We compute your pace and adjust it to any distance.'**
  String get onbRunHint;

  /// No description provided for @onbEstimatedIndexHere.
  ///
  /// In en, this message translates to:
  /// **'Your estimated Index will appear here.'**
  String get onbEstimatedIndexHere;

  /// No description provided for @onbEstimatedIndexLabel.
  ///
  /// In en, this message translates to:
  /// **'ESTIMATED INDEX'**
  String get onbEstimatedIndexLabel;

  /// No description provided for @onbNeedEffort.
  ///
  /// In en, this message translates to:
  /// **'Add a run, push-ups or squats.'**
  String get onbNeedEffort;

  /// No description provided for @onbRunNeedsBoth.
  ///
  /// In en, this message translates to:
  /// **'Distance (0.4–42 km) and time required for the run.'**
  String get onbRunNeedsBoth;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsCustomizeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Customize my avatar'**
  String get settingsCustomizeAvatar;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & privacy (GDPR)'**
  String get settingsPrivacy;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get settingsExport;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent: all your data will be erased.'**
  String get deleteAccountBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
