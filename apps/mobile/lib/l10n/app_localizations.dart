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
  /// **'League'**
  String get navLeaderboard;

  /// No description provided for @settingsEquipmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Equipment — \"Equipped\" also unlocks equipment-free sessions'**
  String get settingsEquipmentLabel;

  /// No description provided for @settingsEquipmentNone.
  ///
  /// In en, this message translates to:
  /// **'No equipment'**
  String get settingsEquipmentNone;

  /// No description provided for @settingsEquipmentEquipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped (gym)'**
  String get settingsEquipmentEquipped;

  /// No description provided for @settingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get settingsUpdated;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsByFocus.
  ///
  /// In en, this message translates to:
  /// **'Sessions by focus'**
  String get sessionsByFocus;

  /// No description provided for @sessionsWeeklyTitle.
  ///
  /// In en, this message translates to:
  /// **'Session of the week'**
  String get sessionsWeeklyTitle;

  /// No description provided for @sessionsCountsMost.
  ///
  /// In en, this message translates to:
  /// **'Counts a lot'**
  String get sessionsCountsMost;

  /// No description provided for @sessionsAttributeHeader.
  ///
  /// In en, this message translates to:
  /// **'Workouts that count toward your {attribute} score'**
  String sessionsAttributeHeader(String attribute);

  /// No description provided for @leaderboardIntro.
  ///
  /// In en, this message translates to:
  /// **'The ranking of every athlete in your league (your sex), sorted by Athlete Index — normalized by sex for fairness. Climb by improving your score.'**
  String get leaderboardIntro;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonGenericError;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @bugReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get bugReportTitle;

  /// No description provided for @bugReportHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue: what you were doing, what happened, which screen…'**
  String get bugReportHint;

  /// No description provided for @bugReportSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get bugReportSend;

  /// No description provided for @bugReportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your report was sent. 🙏'**
  String get bugReportThanks;

  /// No description provided for @bugReportTooShort.
  ///
  /// In en, this message translates to:
  /// **'Add a few words describing the bug.'**
  String get bugReportTooShort;

  /// No description provided for @wodPredictionTitle.
  ///
  /// In en, this message translates to:
  /// **'Based on your level, you\'d do'**
  String get wodPredictionTitle;

  /// No description provided for @wodPredictionChallenge.
  ///
  /// In en, this message translates to:
  /// **'Your move: go all out and beat this estimate 🔥'**
  String get wodPredictionChallenge;

  /// No description provided for @homeBetaBanner.
  ///
  /// In en, this message translates to:
  /// **'Beta version — found a bug? Tap to learn more'**
  String get homeBetaBanner;

  /// No description provided for @homeBetaTitle.
  ///
  /// In en, this message translates to:
  /// **'App in beta'**
  String get homeBetaTitle;

  /// No description provided for @homeBetaBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s evolving fast: you may still hit bugs, inconsistencies or imperfect data. Tell us anything that looks off so we can fix it quickly — every report helps. 🙏'**
  String get homeBetaBody;

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

  /// No description provided for @homeProjection.
  ///
  /// In en, this message translates to:
  /// **'At this rate: {grade}+ in ~{weeks} wk.'**
  String homeProjection(int grade, int weeks);

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @wreSecondsRange.
  ///
  /// In en, this message translates to:
  /// **'Seconds must be between 0 and 59.'**
  String get wreSecondsRange;

  /// No description provided for @wreInvalidResult.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid result.'**
  String get wreInvalidResult;

  /// No description provided for @wreNeedDistance.
  ///
  /// In en, this message translates to:
  /// **'Enter the distance covered (in meters).'**
  String get wreNeedDistance;

  /// No description provided for @wreIndexClimbs.
  ///
  /// In en, this message translates to:
  /// **'Your Athlete Index is climbing.'**
  String get wreIndexClimbs;

  /// No description provided for @wreShareFeat.
  ///
  /// In en, this message translates to:
  /// **'Share my achievement'**
  String get wreShareFeat;

  /// No description provided for @wreBadgeUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Badge unlocked: {name}'**
  String wreBadgeUnlocked(String name);

  /// No description provided for @wreBadgesUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{count} new badges unlocked!'**
  String wreBadgesUnlocked(int count);

  /// No description provided for @wreSeeMyBadges.
  ///
  /// In en, this message translates to:
  /// **'See my badges'**
  String get wreSeeMyBadges;

  /// No description provided for @wreProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re progressing 💪'**
  String get wreProgressTitle;

  /// No description provided for @wreOutOfBounds.
  ///
  /// In en, this message translates to:
  /// **'Result outside plausible bounds.'**
  String get wreOutOfBounds;

  /// No description provided for @wreYourTime.
  ///
  /// In en, this message translates to:
  /// **'Your time'**
  String get wreYourTime;

  /// No description provided for @wreYourResult.
  ///
  /// In en, this message translates to:
  /// **'Your result ({unit})'**
  String wreYourResult(String unit);

  /// No description provided for @wreUnitTime.
  ///
  /// In en, this message translates to:
  /// **'time'**
  String get wreUnitTime;

  /// No description provided for @wreDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance covered (meters)'**
  String get wreDistanceLabel;

  /// No description provided for @wreDistanceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5000'**
  String get wreDistanceHint;

  /// No description provided for @wreResultHint.
  ///
  /// In en, this message translates to:
  /// **'result'**
  String get wreResultHint;

  /// No description provided for @wreCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get wreCategory;

  /// No description provided for @wreScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get wreScale;

  /// No description provided for @wrePro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get wrePro;

  /// No description provided for @wreRx.
  ///
  /// In en, this message translates to:
  /// **'Rx (prescribed)'**
  String get wreRx;

  /// No description provided for @wreOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get wreOpen;

  /// No description provided for @wreScaled.
  ///
  /// In en, this message translates to:
  /// **'Scaled'**
  String get wreScaled;

  /// No description provided for @wreSeparatedPro.
  ///
  /// In en, this message translates to:
  /// **'Pro and Open leaderboards are separate.'**
  String get wreSeparatedPro;

  /// No description provided for @wreSeparatedRx.
  ///
  /// In en, this message translates to:
  /// **'Rx and Scaled leaderboards are separate.'**
  String get wreSeparatedRx;

  /// No description provided for @wreSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get wreSave;

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

  /// No description provided for @onbMaxPullups.
  ///
  /// In en, this message translates to:
  /// **'Max strict pull-ups (one set)'**
  String get onbMaxPullups;

  /// No description provided for @onbSquat1rm.
  ///
  /// In en, this message translates to:
  /// **'Squat 1RM (max load, 1 rep)'**
  String get onbSquat1rm;

  /// No description provided for @onbSquat1rmHint.
  ///
  /// In en, this message translates to:
  /// **'Your heaviest back squat for a single rep, in kilograms.'**
  String get onbSquat1rmHint;

  /// No description provided for @onbRevealCta.
  ///
  /// In en, this message translates to:
  /// **'Reveal my Athlete Index'**
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

  /// No description provided for @wodTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get wodTabTitle;

  /// No description provided for @wodTabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a workout, see the records and where you stand.'**
  String get wodTabSubtitle;

  /// No description provided for @wodTabFlagshipSection.
  ///
  /// In en, this message translates to:
  /// **'⭐ Flagship workouts'**
  String get wodTabFlagshipSection;

  /// No description provided for @wodTabFlagshipCaption.
  ///
  /// In en, this message translates to:
  /// **'The 4 big challenges everyone measures themselves against.'**
  String get wodTabFlagshipCaption;

  /// No description provided for @wodTabNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'No equipment'**
  String get wodTabNoEquipment;

  /// No description provided for @wodTabWithEquipment.
  ///
  /// In en, this message translates to:
  /// **'With equipment'**
  String get wodTabWithEquipment;

  /// No description provided for @wodTabOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get wodTabOtherTitle;

  /// No description provided for @wodTabOtherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real events (HYROX, CrossFit competitions, races) + real pro times'**
  String get wodTabOtherSubtitle;

  /// No description provided for @wodTabMyHistory.
  ///
  /// In en, this message translates to:
  /// **'My workout history'**
  String get wodTabMyHistory;

  /// No description provided for @otherWorkoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Other events'**
  String get otherWorkoutsTitle;

  /// No description provided for @otherWorkoutsIntro.
  ///
  /// In en, this message translates to:
  /// **'Major real-world events (HYROX, competition WODs, races). Open one to see the details and records — and log your time.'**
  String get otherWorkoutsIntro;

  /// No description provided for @otherWorkoutsNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'No equipment'**
  String get otherWorkoutsNoEquipment;

  /// No description provided for @otherWorkoutsWithEquipment.
  ///
  /// In en, this message translates to:
  /// **'With equipment'**
  String get otherWorkoutsWithEquipment;

  /// No description provided for @otherWorkoutsCommunitySection.
  ///
  /// In en, this message translates to:
  /// **'Community workouts'**
  String get otherWorkoutsCommunitySection;

  /// No description provided for @otherWorkoutsCommunityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workouts created by users yet. Create yours via \"Build a workout\".'**
  String get otherWorkoutsCommunityEmpty;

  /// No description provided for @logWodTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a workout'**
  String get logWodTitle;

  /// No description provided for @logWodIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick a workout to see what it involves, the reference times and the leaderboard — then log your result.'**
  String get logWodIntro;

  /// No description provided for @logWodNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'No equipment'**
  String get logWodNoEquipment;

  /// No description provided for @logWodWithEquipment.
  ///
  /// In en, this message translates to:
  /// **'With equipment'**
  String get logWodWithEquipment;

  /// No description provided for @wodDetailReferenceTimes.
  ///
  /// In en, this message translates to:
  /// **'Reference times'**
  String get wodDetailReferenceTimes;

  /// No description provided for @wodDetailReferenceTimesCaption.
  ///
  /// In en, this message translates to:
  /// **'Beginner · intermediate · champion, by sex'**
  String get wodDetailReferenceTimesCaption;

  /// No description provided for @wodDetailNoTiers.
  ///
  /// In en, this message translates to:
  /// **'Tiers not available for this workout.'**
  String get wodDetailNoTiers;

  /// No description provided for @wodDetailLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get wodDetailLeaderboard;

  /// No description provided for @wodDetailDoThisWorkout.
  ///
  /// In en, this message translates to:
  /// **'Do this workout'**
  String get wodDetailDoThisWorkout;

  /// No description provided for @wodDetailMen.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get wodDetailMen;

  /// No description provided for @wodDetailWomen.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get wodDetailWomen;

  /// No description provided for @wodDetailTierChampion.
  ///
  /// In en, this message translates to:
  /// **'🏆 Champion (elite)'**
  String get wodDetailTierChampion;

  /// No description provided for @wodDetailTierIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get wodDetailTierIntermediate;

  /// No description provided for @wodDetailTierBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get wodDetailTierBeginner;

  /// No description provided for @wodDetailYou.
  ///
  /// In en, this message translates to:
  /// **'You: '**
  String get wodDetailYou;

  /// No description provided for @wodDetailPoints.
  ///
  /// In en, this message translates to:
  /// **'{n} pts'**
  String wodDetailPoints(int n);

  /// No description provided for @wodDetailMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String wodDetailMinutes(int n);

  /// No description provided for @wodDetailChallenge.
  ///
  /// In en, this message translates to:
  /// **'The challenge'**
  String get wodDetailChallenge;

  /// No description provided for @wodDetailCap.
  ///
  /// In en, this message translates to:
  /// **'Cap {cap}'**
  String wodDetailCap(String cap);

  /// No description provided for @wodDetailLoads.
  ///
  /// In en, this message translates to:
  /// **'LOADS'**
  String get wodDetailLoads;

  /// No description provided for @wodDetailRx.
  ///
  /// In en, this message translates to:
  /// **'RX: '**
  String get wodDetailRx;

  /// No description provided for @wodDetailLight.
  ///
  /// In en, this message translates to:
  /// **'Light: '**
  String get wodDetailLight;

  /// No description provided for @wodDetailScopeAll.
  ///
  /// In en, this message translates to:
  /// **'🌍 All'**
  String get wodDetailScopeAll;

  /// No description provided for @wodDetailMyClub.
  ///
  /// In en, this message translates to:
  /// **'My club'**
  String get wodDetailMyClub;

  /// No description provided for @wodDetailWorldRecord.
  ///
  /// In en, this message translates to:
  /// **'🌍 World record'**
  String get wodDetailWorldRecord;

  /// No description provided for @wodDetailElite.
  ///
  /// In en, this message translates to:
  /// **'⭐ Elite'**
  String get wodDetailElite;

  /// No description provided for @wodDetailMyPerformances.
  ///
  /// In en, this message translates to:
  /// **'My performances'**
  String get wodDetailMyPerformances;

  /// No description provided for @wodDetailLeaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Be the first to post a result 💪'**
  String get wodDetailLeaderboardEmpty;

  /// No description provided for @wodDetailVariantRx.
  ///
  /// In en, this message translates to:
  /// **'Rx'**
  String get wodDetailVariantRx;

  /// No description provided for @wodDetailVariantScaled.
  ///
  /// In en, this message translates to:
  /// **'Scaled'**
  String get wodDetailVariantScaled;

  /// No description provided for @wodDetailYouShort.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get wodDetailYouShort;

  /// No description provided for @wodDetailLeaderboardYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String wodDetailLeaderboardYou(String name);

  /// No description provided for @wodBuilderTitle.
  ///
  /// In en, this message translates to:
  /// **'Build a workout'**
  String get wodBuilderTitle;

  /// No description provided for @wodBuilderFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get wodBuilderFormat;

  /// No description provided for @wodBuilderRoundsLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of rounds: '**
  String get wodBuilderRoundsLabel;

  /// No description provided for @wodBuilderRoundsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3'**
  String get wodBuilderRoundsHint;

  /// No description provided for @wodBuilderRoundsCaption.
  ///
  /// In en, this message translates to:
  /// **'(the movements repeat N times)'**
  String get wodBuilderRoundsCaption;

  /// No description provided for @wodBuilderTimeNote.
  ///
  /// In en, this message translates to:
  /// **'No time to enter here: the score is the time you take to finish, which you\'ll log when doing the workout.'**
  String get wodBuilderTimeNote;

  /// No description provided for @wodBuilderCapLabel.
  ///
  /// In en, this message translates to:
  /// **'Cap (min): '**
  String get wodBuilderCapLabel;

  /// No description provided for @wodBuilderCapHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 12'**
  String get wodBuilderCapHint;

  /// No description provided for @wodBuilderRequiresEquipment.
  ///
  /// In en, this message translates to:
  /// **'Requires equipment'**
  String get wodBuilderRequiresEquipment;

  /// No description provided for @wodBuilderMovements.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get wodBuilderMovements;

  /// No description provided for @wodBuilderAddMovement.
  ///
  /// In en, this message translates to:
  /// **'Add a movement'**
  String get wodBuilderAddMovement;

  /// No description provided for @wodBuilderPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish this workout'**
  String get wodBuilderPublish;

  /// No description provided for @wodBuilderAddMovementError.
  ///
  /// In en, this message translates to:
  /// **'Add at least one movement.'**
  String get wodBuilderAddMovementError;

  /// No description provided for @wodBuilderCustomWorkout.
  ///
  /// In en, this message translates to:
  /// **'Custom workout'**
  String get wodBuilderCustomWorkout;

  /// No description provided for @wodBuilderWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get wodBuilderWorkout;

  /// No description provided for @wodBuilderAssignedName.
  ///
  /// In en, this message translates to:
  /// **'Assigned name'**
  String get wodBuilderAssignedName;

  /// No description provided for @wodBuilderEstimateEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add movements to see the estimate.'**
  String get wodBuilderEstimateEmpty;

  /// No description provided for @wodBuilderEstimateError.
  ///
  /// In en, this message translates to:
  /// **'Estimate unavailable.'**
  String get wodBuilderEstimateError;

  /// No description provided for @wodBuilderEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get wodBuilderEstimate;

  /// No description provided for @wodBuilderEstimated.
  ///
  /// In en, this message translates to:
  /// **'≈ estimated'**
  String get wodBuilderEstimated;

  /// No description provided for @wodBuilderEstimateChampion.
  ///
  /// In en, this message translates to:
  /// **'🏆 Champion: {result}'**
  String wodBuilderEstimateChampion(String result);

  /// No description provided for @wodBuilderEstimateIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate: {result}'**
  String wodBuilderEstimateIntermediate(String result);

  /// No description provided for @wodBuilderEstimateBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner: {result}'**
  String wodBuilderEstimateBeginner(String result);

  /// No description provided for @wodBuilderSearchMovement.
  ///
  /// In en, this message translates to:
  /// **'Search a movement'**
  String get wodBuilderSearchMovement;

  /// No description provided for @communityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get communityTitle;

  /// No description provided for @communityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Follow athletes to see their activity, or log a workout to start your feed.'**
  String get communityEmpty;

  /// No description provided for @communityPublish.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get communityPublish;

  /// No description provided for @communityExploreClubs.
  ///
  /// In en, this message translates to:
  /// **'Explore clubs'**
  String get communityExploreClubs;

  /// No description provided for @communityTooltipMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get communityTooltipMessages;

  /// No description provided for @communityTooltipPublish.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get communityTooltipPublish;

  /// No description provided for @communityTooltipClubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get communityTooltipClubs;

  /// No description provided for @communityTooltipSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get communityTooltipSearch;

  /// No description provided for @communityPostDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get communityPostDelete;

  /// No description provided for @communityPostReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get communityPostReport;

  /// No description provided for @communityReportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks, report sent.'**
  String get communityReportSent;

  /// No description provided for @communityWorkoutFallback.
  ///
  /// In en, this message translates to:
  /// **'a workout'**
  String get communityWorkoutFallback;

  /// No description provided for @communityMsgPr.
  ///
  /// In en, this message translates to:
  /// **'🏆 New PR — {wodName}'**
  String communityMsgPr(String wodName);

  /// No description provided for @communityMsgWodLogged.
  ///
  /// In en, this message translates to:
  /// **'did {wodName}'**
  String communityMsgWodLogged(String wodName);

  /// No description provided for @communityMsgRankUp.
  ///
  /// In en, this message translates to:
  /// **'is promoted to {rank} 🎖️'**
  String communityMsgRankUp(String rank);

  /// No description provided for @communityMsgBadge.
  ///
  /// In en, this message translates to:
  /// **'badge unlocked: {name}'**
  String communityMsgBadge(String name);

  /// No description provided for @communityMsgMemberJoined.
  ///
  /// In en, this message translates to:
  /// **'just joined us with a Athlete Index of {index} 👋'**
  String communityMsgMemberJoined(String index);

  /// No description provided for @communityMsgPostPerf.
  ///
  /// In en, this message translates to:
  /// **'💪 shared a perf — {wodName}'**
  String communityMsgPostPerf(String wodName);

  /// No description provided for @communityMsgDefault.
  ///
  /// In en, this message translates to:
  /// **'new activity'**
  String get communityMsgDefault;

  /// No description provided for @exploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Athletes'**
  String get exploreTitle;

  /// No description provided for @exploreSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a username'**
  String get exploreSearchHint;

  /// No description provided for @exploreFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get exploreFilterAll;

  /// No description provided for @exploreFilterMen.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get exploreFilterMen;

  /// No description provided for @exploreFilterWomen.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get exploreFilterWomen;

  /// No description provided for @exploreEmpty.
  ///
  /// In en, this message translates to:
  /// **'No athletes.'**
  String get exploreEmpty;

  /// No description provided for @composerTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get composerTitle;

  /// No description provided for @composerPickPerf.
  ///
  /// In en, this message translates to:
  /// **'Pick a perf to share.'**
  String get composerPickPerf;

  /// No description provided for @composerWriteMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a message.'**
  String get composerWriteMessage;

  /// No description provided for @composerModeMessage.
  ///
  /// In en, this message translates to:
  /// **'💬 Message'**
  String get composerModeMessage;

  /// No description provided for @composerModePerf.
  ///
  /// In en, this message translates to:
  /// **'💪 Share a perf'**
  String get composerModePerf;

  /// No description provided for @composerCaptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Caption (optional)'**
  String get composerCaptionLabel;

  /// No description provided for @composerHintPerf.
  ///
  /// In en, this message translates to:
  /// **'A word about this perf…'**
  String get composerHintPerf;

  /// No description provided for @composerHintText.
  ///
  /// In en, this message translates to:
  /// **'What\'s up, athlete?'**
  String get composerHintText;

  /// No description provided for @composerPublish.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get composerPublish;

  /// No description provided for @composerNoResults.
  ///
  /// In en, this message translates to:
  /// **'Log a workout first to be able to share a perf.'**
  String get composerNoResults;

  /// No description provided for @composerPickPerfLabel.
  ///
  /// In en, this message translates to:
  /// **'Pick the perf to share'**
  String get composerPickPerfLabel;

  /// No description provided for @chatStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation with {name} 👋'**
  String chatStartConversation(String name);

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get chatHint;

  /// No description provided for @conversationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get conversationsTitle;

  /// No description provided for @conversationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversation yet. Open an athlete\'s profile and say hi — everyone is reachable.'**
  String get conversationsEmpty;

  /// No description provided for @conversationsYouPrefix.
  ///
  /// In en, this message translates to:
  /// **'You: '**
  String get conversationsYouPrefix;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @chatStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatStatusSending;

  /// No description provided for @chatStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed — tap to retry'**
  String get chatStatusFailed;

  /// No description provided for @chatStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatStatusSent;

  /// No description provided for @chatStatusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatStatusRead;

  /// No description provided for @chatViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get chatViewProfile;

  /// No description provided for @chatBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatBlock;

  /// No description provided for @chatBlockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String chatBlockConfirmTitle(String name);

  /// No description provided for @chatBlockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be able to message each other anymore. You can unblock them later.'**
  String get chatBlockConfirmBody;

  /// No description provided for @chatBlockCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatBlockCancel;

  /// No description provided for @chatBlockConfirm.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatBlockConfirm;

  /// No description provided for @chatBlocked.
  ///
  /// In en, this message translates to:
  /// **'{name} has been blocked.'**
  String chatBlocked(String name);

  /// No description provided for @dmReasonAge.
  ///
  /// In en, this message translates to:
  /// **'Private messages are only possible between accounts in the same age range.'**
  String get dmReasonAge;

  /// No description provided for @dmReasonBlocked.
  ///
  /// In en, this message translates to:
  /// **'Can\'t message this user.'**
  String get dmReasonBlocked;

  /// No description provided for @dmReasonUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This account is no longer available.'**
  String get dmReasonUnavailable;

  /// No description provided for @messagingErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You\'re sending too many messages. Try again in a moment.'**
  String get messagingErrorRateLimited;

  /// No description provided for @messagingErrorNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Can\'t message this user.'**
  String get messagingErrorNotAllowed;

  /// No description provided for @messagingErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Conversation not found.'**
  String get messagingErrorNotFound;

  /// No description provided for @messagingErrorTooLong.
  ///
  /// In en, this message translates to:
  /// **'Message too long (2000 characters max).'**
  String get messagingErrorTooLong;

  /// No description provided for @messagingErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect. Check your connection and try again.'**
  String get messagingErrorNetwork;

  /// No description provided for @messagingErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get messagingErrorGeneric;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get notificationsSettingsTooltip;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing new for now. Log a session to get things moving!'**
  String get notificationsEmpty;

  /// No description provided for @notificationsNewMessages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new message} other{{count} new messages}}'**
  String notificationsNewMessages(int count);

  /// No description provided for @notificationsNewMessagesBody.
  ///
  /// In en, this message translates to:
  /// **'Open your conversations.'**
  String get notificationsNewMessagesBody;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are coming soon. Your preferences below will apply as soon as they go live.'**
  String get notificationSettingsComingSoon;

  /// No description provided for @notificationSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved.'**
  String get notificationSettingsSaved;

  /// No description provided for @notificationSettingsQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get notificationSettingsQuietHours;

  /// No description provided for @notificationSettingsStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get notificationSettingsStart;

  /// No description provided for @notificationSettingsEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get notificationSettingsEnd;

  /// No description provided for @notificationSettingsDailyCap.
  ///
  /// In en, this message translates to:
  /// **'Maximum per day'**
  String get notificationSettingsDailyCap;

  /// No description provided for @notificationSettingsTypes.
  ///
  /// In en, this message translates to:
  /// **'Notification types'**
  String get notificationSettingsTypes;

  /// No description provided for @notificationSettingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get notificationSettingsSave;

  /// No description provided for @clubsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get clubsTitle;

  /// No description provided for @clubsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a club'**
  String get clubsCreateTitle;

  /// No description provided for @clubsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Club name'**
  String get clubsNameLabel;

  /// No description provided for @clubsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get clubsDescriptionLabel;

  /// No description provided for @clubsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get clubsCancel;

  /// No description provided for @clubsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get clubsCreate;

  /// No description provided for @clubsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a club to join'**
  String get clubsSearchHint;

  /// No description provided for @clubsInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get clubsInvitations;

  /// No description provided for @clubsMine.
  ///
  /// In en, this message translates to:
  /// **'My clubs'**
  String get clubsMine;

  /// No description provided for @clubsDiscover.
  ///
  /// In en, this message translates to:
  /// **'All clubs'**
  String get clubsDiscover;

  /// No description provided for @clubsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in any club. Create your own or join one 👥'**
  String get clubsEmpty;

  /// No description provided for @clubsView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get clubsView;

  /// No description provided for @clubsMembers.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String clubsMembers(int count);

  /// No description provided for @clubsMembersOwner.
  ///
  /// In en, this message translates to:
  /// **'{count} members · creator'**
  String clubsMembersOwner(int count);

  /// No description provided for @clubsMembersInvite.
  ///
  /// In en, this message translates to:
  /// **'{count} members · invites you'**
  String clubsMembersInvite(int count);

  /// No description provided for @clubDetailOwnerTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re the creator'**
  String get clubDetailOwnerTitle;

  /// No description provided for @clubDetailLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the club?'**
  String get clubDetailLeaveTitle;

  /// No description provided for @clubDetailOwnerMessage.
  ///
  /// In en, this message translates to:
  /// **'Transfer the club first, or wait until you\'re alone to leave it.'**
  String get clubDetailOwnerMessage;

  /// No description provided for @clubDetailLeaveMessage.
  ///
  /// In en, this message translates to:
  /// **'You can join again later.'**
  String get clubDetailLeaveMessage;

  /// No description provided for @clubDetailCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get clubDetailCancel;

  /// No description provided for @clubDetailLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get clubDetailLeave;

  /// No description provided for @clubDetailRankingBySeance.
  ///
  /// In en, this message translates to:
  /// **'Club ranking by session'**
  String get clubDetailRankingBySeance;

  /// No description provided for @clubDetailJoin.
  ///
  /// In en, this message translates to:
  /// **'Join the club'**
  String get clubDetailJoin;

  /// No description provided for @clubDetailProgression.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get clubDetailProgression;

  /// No description provided for @clubDetailBySeance.
  ///
  /// In en, this message translates to:
  /// **'By session'**
  String get clubDetailBySeance;

  /// No description provided for @clubDetailRankingTitle.
  ///
  /// In en, this message translates to:
  /// **'Club ranking (Athlete Index)'**
  String get clubDetailRankingTitle;

  /// No description provided for @clubDetailLeaveButton.
  ///
  /// In en, this message translates to:
  /// **'Leave the club'**
  String get clubDetailLeaveButton;

  /// No description provided for @clubDetailMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String clubDetailMembers(int count);

  /// No description provided for @clubDetailRosterMe.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String clubDetailRosterMe(String name);

  /// No description provided for @publicProfileFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get publicProfileFollowing;

  /// No description provided for @publicProfileFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get publicProfileFollow;

  /// No description provided for @publicProfileMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get publicProfileMessage;

  /// No description provided for @publicProfileInviteToClub.
  ///
  /// In en, this message translates to:
  /// **'Invite to my club'**
  String get publicProfileInviteToClub;

  /// No description provided for @publicProfileInviteNoClub.
  ///
  /// In en, this message translates to:
  /// **'Create a club first to invite.'**
  String get publicProfileInviteNoClub;

  /// No description provided for @publicProfileInviteInto.
  ///
  /// In en, this message translates to:
  /// **'Invite into…'**
  String get publicProfileInviteInto;

  /// No description provided for @publicProfileInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to « {name} »'**
  String publicProfileInviteSent(String name);

  /// No description provided for @publicProfileLeaguePosition.
  ///
  /// In en, this message translates to:
  /// **'#{position} in their league'**
  String publicProfileLeaguePosition(int position);

  /// No description provided for @publicProfileLeaguePositionMine.
  ///
  /// In en, this message translates to:
  /// **'#{position} in your league'**
  String publicProfileLeaguePositionMine(int position);

  /// No description provided for @publicProfileNoIndex.
  ///
  /// In en, this message translates to:
  /// **'No Index yet.'**
  String get publicProfileNoIndex;

  /// No description provided for @publicProfileComparison.
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get publicProfileComparison;

  /// No description provided for @publicProfileTheirRadar.
  ///
  /// In en, this message translates to:
  /// **'Their radar'**
  String get publicProfileTheirRadar;

  /// No description provided for @publicProfileYourRadar.
  ///
  /// In en, this message translates to:
  /// **'Your radar'**
  String get publicProfileYourRadar;

  /// No description provided for @publicProfileCompareAhead.
  ///
  /// In en, this message translates to:
  /// **'You\'re ahead by {diff} points (you {mine} · them {other}).'**
  String publicProfileCompareAhead(int diff, int mine, int other);

  /// No description provided for @publicProfileCompareBehind.
  ///
  /// In en, this message translates to:
  /// **'They\'re ahead of you by {diff} points (you {mine} · them {other}).'**
  String publicProfileCompareBehind(int diff, int mine, int other);

  /// No description provided for @avatarTitle.
  ///
  /// In en, this message translates to:
  /// **'My avatar'**
  String get avatarTitle;

  /// No description provided for @avatarImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image too large — pick a smaller one.'**
  String get avatarImageTooLarge;

  /// No description provided for @avatarAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get avatarAddPhoto;

  /// No description provided for @avatarChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get avatarChangePhoto;

  /// No description provided for @avatarRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get avatarRemove;

  /// No description provided for @avatarPhotoHidesDrawn.
  ///
  /// In en, this message translates to:
  /// **'With a photo, the drawn avatar is hidden.'**
  String get avatarPhotoHidesDrawn;

  /// No description provided for @avatarSkin.
  ///
  /// In en, this message translates to:
  /// **'Skin tone'**
  String get avatarSkin;

  /// No description provided for @avatarHairColor.
  ///
  /// In en, this message translates to:
  /// **'Hair color'**
  String get avatarHairColor;

  /// No description provided for @avatarHaircut.
  ///
  /// In en, this message translates to:
  /// **'Haircut'**
  String get avatarHaircut;

  /// No description provided for @avatarBeard.
  ///
  /// In en, this message translates to:
  /// **'Beard'**
  String get avatarBeard;

  /// No description provided for @avatarBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get avatarBackground;

  /// No description provided for @avatarSave.
  ///
  /// In en, this message translates to:
  /// **'Save my avatar'**
  String get avatarSave;

  /// No description provided for @leagueMen.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get leagueMen;

  /// No description provided for @leagueWomen.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get leagueWomen;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'My history'**
  String get historyTitle;

  /// No description provided for @historyRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get historyRun;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No session logged yet.'**
  String get historyEmpty;

  /// No description provided for @historyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this session?'**
  String get historyDeleteTitle;

  /// No description provided for @historyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{name} · {date}\nYour Index will be recalculated.'**
  String historyDeleteBody(String name, String date);

  /// No description provided for @endgameTitle.
  ///
  /// In en, this message translates to:
  /// **'Grand Slam'**
  String get endgameTitle;

  /// No description provided for @endgameFlagshipTitle.
  ///
  /// In en, this message translates to:
  /// **'The 4 flagship sessions'**
  String get endgameFlagshipTitle;

  /// No description provided for @endgameFlagshipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a session to see what it involves and take it on.'**
  String get endgameFlagshipSubtitle;

  /// No description provided for @endgameTierBronze.
  ///
  /// In en, this message translates to:
  /// **'🥉 Bronze'**
  String get endgameTierBronze;

  /// No description provided for @endgameTierBronzeDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete the 4 flagship sessions.'**
  String get endgameTierBronzeDesc;

  /// No description provided for @endgameTierSilver.
  ///
  /// In en, this message translates to:
  /// **'🥈 Silver'**
  String get endgameTierSilver;

  /// No description provided for @endgameTierSilverDesc.
  ///
  /// In en, this message translates to:
  /// **'All 4 with a score ≥ {min}/100 — hard but reachable (~1 year of practice).'**
  String endgameTierSilverDesc(int min);

  /// No description provided for @endgameTierGold.
  ///
  /// In en, this message translates to:
  /// **'🥇 Gold'**
  String get endgameTierGold;

  /// No description provided for @endgameTierGoldDesc.
  ///
  /// In en, this message translates to:
  /// **'All 4 with a score ≥ {min}/100 — extremely demanding (~5 years).'**
  String endgameTierGoldDesc(int min);

  /// No description provided for @endgameGlobalRank.
  ///
  /// In en, this message translates to:
  /// **'Global rank'**
  String get endgameGlobalRank;

  /// No description provided for @endgameTop100.
  ///
  /// In en, this message translates to:
  /// **'Global Top 100 🌍'**
  String get endgameTop100;

  /// No description provided for @endgameHeroBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze Grand Slam'**
  String get endgameHeroBronze;

  /// No description provided for @endgameHeroSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver Grand Slam'**
  String get endgameHeroSilver;

  /// No description provided for @endgameHeroGold.
  ///
  /// In en, this message translates to:
  /// **'Gold Grand Slam'**
  String get endgameHeroGold;

  /// No description provided for @endgameHeroLocked.
  ///
  /// In en, this message translates to:
  /// **'Grand Slam — not unlocked'**
  String get endgameHeroLocked;

  /// No description provided for @endgameFlagshipDone.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} flagship sessions completed'**
  String endgameFlagshipDone(int completed, int total);

  /// No description provided for @challengeBannerLabel.
  ///
  /// In en, this message translates to:
  /// **'CHALLENGE OF THE WEEK · {theme}'**
  String challengeBannerLabel(String theme);

  /// No description provided for @challengeEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get challengeEnded;

  /// No description provided for @challengeCountdownDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h left'**
  String challengeCountdownDays(int days, int hours);

  /// No description provided for @challengeCountdownHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}min left'**
  String challengeCountdownHours(int hours, int minutes);

  /// No description provided for @challengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge of the week'**
  String get challengeTitle;

  /// No description provided for @challengeDoIt.
  ///
  /// In en, this message translates to:
  /// **'Take the challenge 🔥'**
  String get challengeDoIt;

  /// No description provided for @challengeDetails.
  ///
  /// In en, this message translates to:
  /// **'Tiers, pro references & details'**
  String get challengeDetails;

  /// No description provided for @challengeLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Challenge leaderboard'**
  String get challengeLeaderboard;

  /// No description provided for @challengeHeroTagline.
  ///
  /// In en, this message translates to:
  /// **'Everyone is measured on this session this week. Give it everything 💪'**
  String get challengeHeroTagline;

  /// No description provided for @challengeWhatToDo.
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get challengeWhatToDo;

  /// No description provided for @challengeBeFirst.
  ///
  /// In en, this message translates to:
  /// **'Be the first to take the challenge this week 🔥'**
  String get challengeBeFirst;

  /// No description provided for @challengeYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String challengeYouSuffix(String name);

  /// No description provided for @progressionTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressionTitle;

  /// No description provided for @progressionHistoryButton.
  ///
  /// In en, this message translates to:
  /// **'My session history'**
  String get progressionHistoryButton;

  /// No description provided for @progressionEndgameButton.
  ///
  /// In en, this message translates to:
  /// **'Endgame — Grand Slam & global rank'**
  String get progressionEndgameButton;

  /// No description provided for @progressionBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges ({unlocked}/{total} unlocked)'**
  String progressionBadges(int unlocked, int total);

  /// No description provided for @progressionBadgesHint.
  ///
  /// In en, this message translates to:
  /// **'For each series, your current tier and the next one to aim for.'**
  String get progressionBadgesHint;

  /// No description provided for @coachTitle.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coachTitle;

  /// No description provided for @coachWhichAxis.
  ///
  /// In en, this message translates to:
  /// **'Which axis to improve?'**
  String get coachWhichAxis;

  /// No description provided for @coachWeakPoint.
  ///
  /// In en, this message translates to:
  /// **'My weak point'**
  String get coachWeakPoint;

  /// No description provided for @coachLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load tips right now.'**
  String get coachLoadError;

  /// No description provided for @coachProgressOn.
  ///
  /// In en, this message translates to:
  /// **'Do these sessions to improve on {attribute}'**
  String coachProgressOn(String attribute);

  /// No description provided for @coachTargetedSessions.
  ///
  /// In en, this message translates to:
  /// **'TARGETED SESSIONS'**
  String get coachTargetedSessions;

  /// No description provided for @coachNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No session for this axis with your equipment.'**
  String get coachNoSessions;

  /// No description provided for @coachLogSession.
  ///
  /// In en, this message translates to:
  /// **'Do a scored session & log my time'**
  String get coachLogSession;

  /// No description provided for @coachDurationMin.
  ///
  /// In en, this message translates to:
  /// **'{min} min'**
  String coachDurationMin(int min);

  /// No description provided for @coachWithEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get coachWithEquipment;

  /// No description provided for @coachNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'No equipment'**
  String get coachNoEquipment;

  /// No description provided for @coachIntensityHigh.
  ///
  /// In en, this message translates to:
  /// **'Intense'**
  String get coachIntensityHigh;

  /// No description provided for @coachIntensityMedium.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get coachIntensityMedium;

  /// No description provided for @coachIntensityLow.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get coachIntensityLow;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingNoName.
  ///
  /// In en, this message translates to:
  /// **'Hi 👋'**
  String get homeGreetingNoName;

  /// No description provided for @homeNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get homeNotifications;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile unavailable.'**
  String get homeProfileUnavailable;

  /// No description provided for @homeRadarTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR RADAR'**
  String get homeRadarTitle;

  /// No description provided for @homeRadarHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a quality to see the sessions that boost it.'**
  String get homeRadarHint;

  /// No description provided for @homeCoachCta.
  ///
  /// In en, this message translates to:
  /// **'Coach — improve an axis'**
  String get homeCoachCta;

  /// No description provided for @homeHistory.
  ///
  /// In en, this message translates to:
  /// **'My history'**
  String get homeHistory;

  /// No description provided for @homeShareCard.
  ///
  /// In en, this message translates to:
  /// **'Share my card'**
  String get homeShareCard;

  /// No description provided for @homeFreshnessTitleOne.
  ///
  /// In en, this message translates to:
  /// **'One axis to refresh'**
  String get homeFreshnessTitleOne;

  /// No description provided for @homeFreshnessTitleMany.
  ///
  /// In en, this message translates to:
  /// **'Some axes to refresh'**
  String get homeFreshnessTitleMany;

  /// No description provided for @homeFreshnessBody.
  ///
  /// In en, this message translates to:
  /// **'{names}: your measure is a bit old. A re-test could push it up.'**
  String homeFreshnessBody(String names);

  /// No description provided for @homeAddSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a session'**
  String get homeAddSessionTitle;

  /// No description provided for @homeAddQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a session quickly'**
  String get homeAddQuickTitle;

  /// No description provided for @homeAddQuickSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a reference session'**
  String get homeAddQuickSubtitle;

  /// No description provided for @homeBuildSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Build a session'**
  String get homeBuildSessionTitle;

  /// No description provided for @homeBuildSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compose your own session, automatically estimated'**
  String get homeBuildSessionSubtitle;

  /// No description provided for @gradeSummitReached.
  ///
  /// In en, this message translates to:
  /// **'Summit reached — 100'**
  String get gradeSummitReached;

  /// No description provided for @gradeObjective.
  ///
  /// In en, this message translates to:
  /// **'Goal: {next}'**
  String gradeObjective(Object next);

  /// No description provided for @gradeAlmostReal.
  ///
  /// In en, this message translates to:
  /// **'Almost your real Index'**
  String get gradeAlmostReal;

  /// No description provided for @gradeEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated Index'**
  String get gradeEstimated;

  /// No description provided for @gradeEstimationLoading.
  ///
  /// In en, this message translates to:
  /// **'Estimated on {coverage}/6 attributes…'**
  String gradeEstimationLoading(Object coverage);

  /// No description provided for @gradeEstimationError.
  ///
  /// In en, this message translates to:
  /// **'Estimated on {coverage}/6 attributes. Complete your radar to reveal your real Index.'**
  String gradeEstimationError(Object coverage);

  /// No description provided for @gradeKeepLogging.
  ///
  /// In en, this message translates to:
  /// **'Keep logging sessions to finalize your Index.'**
  String get gradeKeepLogging;

  /// No description provided for @gradeCompletePrefix.
  ///
  /// In en, this message translates to:
  /// **'Complete '**
  String get gradeCompletePrefix;

  /// No description provided for @gradeCompleteSessionOne.
  ///
  /// In en, this message translates to:
  /// **'this session'**
  String get gradeCompleteSessionOne;

  /// No description provided for @gradeCompleteSessionMany.
  ///
  /// In en, this message translates to:
  /// **'these {n} sessions'**
  String gradeCompleteSessionMany(Object n);

  /// No description provided for @gradeCompleteSuffix.
  ///
  /// In en, this message translates to:
  /// **' to reveal your real Index:'**
  String get gradeCompleteSuffix;

  /// No description provided for @gradeUnlocks.
  ///
  /// In en, this message translates to:
  /// **'Unlocks: {covers}'**
  String gradeUnlocks(String covers);

  /// No description provided for @gradeClimbTo.
  ///
  /// In en, this message translates to:
  /// **'Keep logging your sessions to climb toward {next}.'**
  String gradeClimbTo(String next);

  /// No description provided for @gradeWorkPrefix.
  ///
  /// In en, this message translates to:
  /// **'Work on your '**
  String get gradeWorkPrefix;

  /// No description provided for @gradeWorkMiddle.
  ///
  /// In en, this message translates to:
  /// **' to aim for '**
  String get gradeWorkMiddle;

  /// No description provided for @gradeWorkSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get gradeWorkSuffix;

  /// No description provided for @rivalChasing.
  ///
  /// In en, this message translates to:
  /// **'YOU\'RE CHASING'**
  String get rivalChasing;

  /// No description provided for @rivalGapOne.
  ///
  /// In en, this message translates to:
  /// **'Just 1 point to catch up 👊'**
  String get rivalGapOne;

  /// No description provided for @rivalGapMany.
  ///
  /// In en, this message translates to:
  /// **'{gap} points to catch up 👊'**
  String rivalGapMany(Object gap);

  /// No description provided for @rivalLeaderLabel.
  ///
  /// In en, this message translates to:
  /// **'LEADER OF YOUR LEAGUE'**
  String get rivalLeaderLabel;

  /// No description provided for @rivalLeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re on top 👑'**
  String get rivalLeaderTitle;

  /// No description provided for @rivalLeaderBody.
  ///
  /// In en, this message translates to:
  /// **'Defend your spot — beat your own record.'**
  String get rivalLeaderBody;

  /// No description provided for @recapWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR WEEK'**
  String get recapWeekLabel;

  /// No description provided for @recapValidated.
  ///
  /// In en, this message translates to:
  /// **'validated ✅'**
  String get recapValidated;

  /// No description provided for @recapSessionsSingular.
  ///
  /// In en, this message translates to:
  /// **'session'**
  String get recapSessionsSingular;

  /// No description provided for @recapSessionsPlural.
  ///
  /// In en, this message translates to:
  /// **'sessions'**
  String get recapSessionsPlural;

  /// No description provided for @recapIndexPoints.
  ///
  /// In en, this message translates to:
  /// **'Index points'**
  String get recapIndexPoints;

  /// No description provided for @recapWeeksSingular.
  ///
  /// In en, this message translates to:
  /// **'week 🔥'**
  String get recapWeeksSingular;

  /// No description provided for @recapWeeksPlural.
  ///
  /// In en, this message translates to:
  /// **'weeks 🔥'**
  String get recapWeeksPlural;

  /// No description provided for @recapMessageGain.
  ///
  /// In en, this message translates to:
  /// **'Great week — your work pays off, +{delta} on your Index.'**
  String recapMessageGain(Object delta);

  /// No description provided for @recapMessageKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Well done, keep up the momentum.'**
  String get recapMessageKeepGoing;

  /// No description provided for @recapMessageStart.
  ///
  /// In en, this message translates to:
  /// **'One session is enough to kick off the week.'**
  String get recapMessageStart;

  /// No description provided for @streakDetailValidated.
  ///
  /// In en, this message translates to:
  /// **'Week validated ✅ — streak of {current}'**
  String streakDetailValidated(Object current);

  /// No description provided for @streakDetailSeries.
  ///
  /// In en, this message translates to:
  /// **'Streak of {current} weeks'**
  String streakDetailSeries(Object current);

  /// No description provided for @streakDetailLeft.
  ///
  /// In en, this message translates to:
  /// **'{left, plural, one{{left} more session to validate your week} other{{left} more sessions to validate your week}}'**
  String streakDetailLeft(num left);

  /// No description provided for @streakSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Your streak'**
  String get streakSheetTitle;

  /// No description provided for @streakSheetActive.
  ///
  /// In en, this message translates to:
  /// **'{current, plural, one{{current} active week in a row. A week counts from {goal} sessions.} other{{current} active weeks in a row. A week counts from {goal} sessions.}}'**
  String streakSheetActive(num current, Object goal);

  /// No description provided for @streakSheetStart.
  ///
  /// In en, this message translates to:
  /// **'Do {goal} sessions this week to start your streak.'**
  String streakSheetStart(Object goal);

  /// No description provided for @streakThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get streakThisWeek;

  /// No description provided for @streakBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get streakBest;

  /// No description provided for @streakBestValue.
  ///
  /// In en, this message translates to:
  /// **'{best} wk'**
  String streakBestValue(Object best);

  /// No description provided for @streakFreezeTokens.
  ///
  /// In en, this message translates to:
  /// **'Rest tokens'**
  String get streakFreezeTokens;

  /// No description provided for @streakFreezeHint.
  ///
  /// In en, this message translates to:
  /// **'Protect a missed week.'**
  String get streakFreezeHint;

  /// No description provided for @streakNoPressure.
  ///
  /// In en, this message translates to:
  /// **'No pressure: missing a week never lowers your Index.'**
  String get streakNoPressure;

  /// No description provided for @socialProofBases.
  ///
  /// In en, this message translates to:
  /// **'You\'re laying your foundations — each session brings you closer to the top of the ranking.'**
  String get socialProofBases;

  /// No description provided for @socialProofElite.
  ///
  /// In en, this message translates to:
  /// **'🔥 You\'re in the elite — right at the top of the best performers.'**
  String get socialProofElite;

  /// No description provided for @socialProofTopPrefix.
  ///
  /// In en, this message translates to:
  /// **'You\'re among the '**
  String get socialProofTopPrefix;

  /// No description provided for @socialProofTopSuffix.
  ///
  /// In en, this message translates to:
  /// **' fittest humans'**
  String get socialProofTopSuffix;

  /// No description provided for @socialProofAppPrefix.
  ///
  /// In en, this message translates to:
  /// **'Top '**
  String get socialProofAppPrefix;

  /// No description provided for @socialProofAppSuffix.
  ///
  /// In en, this message translates to:
  /// **' of HYBRID athletes'**
  String get socialProofAppSuffix;

  /// No description provided for @revealYourIndex.
  ///
  /// In en, this message translates to:
  /// **'YOUR ATHLETE INDEX'**
  String get revealYourIndex;

  /// No description provided for @revealDoProfilExpress.
  ///
  /// In en, this message translates to:
  /// **'Do the Express Profile'**
  String get revealDoProfilExpress;

  /// No description provided for @revealEstimateTitle.
  ///
  /// In en, this message translates to:
  /// **'This is an estimate'**
  String get revealEstimateTitle;

  /// No description provided for @revealEstimateBody.
  ///
  /// In en, this message translates to:
  /// **'Your starting Index is based on {coverage}/6 attributes. Log a few more sessions to unlock all 6 and reveal your true Athlete Index.'**
  String revealEstimateBody(int coverage);

  /// No description provided for @revealRadar.
  ///
  /// In en, this message translates to:
  /// **'YOUR RADAR'**
  String get revealRadar;

  /// No description provided for @revealDiscoverProfile.
  ///
  /// In en, this message translates to:
  /// **'Discover my profile'**
  String get revealDiscoverProfile;

  /// No description provided for @revealShareCard.
  ///
  /// In en, this message translates to:
  /// **'Share my card'**
  String get revealShareCard;

  /// No description provided for @revealComputing.
  ///
  /// In en, this message translates to:
  /// **'Computing your Index…'**
  String get revealComputing;

  /// No description provided for @shareCardTitle.
  ///
  /// In en, this message translates to:
  /// **'My card'**
  String get shareCardTitle;

  /// No description provided for @shareCardShareText.
  ///
  /// In en, this message translates to:
  /// **'My Athlete Index 💪 What\'s yours? #AthleteIndex'**
  String get shareCardShareText;

  /// No description provided for @shareCardDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Card downloaded 📥'**
  String get shareCardDownloaded;

  /// No description provided for @shareCardDownloadUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Download not supported here.'**
  String get shareCardDownloadUnsupported;

  /// No description provided for @shareCardNoIndex.
  ///
  /// In en, this message translates to:
  /// **'No Index to share.'**
  String get shareCardNoIndex;

  /// No description provided for @shareCardTagline.
  ///
  /// In en, this message translates to:
  /// **'Show your level — challenge your friends 🔥'**
  String get shareCardTagline;

  /// No description provided for @shareCardShareCta.
  ///
  /// In en, this message translates to:
  /// **'Share my card'**
  String get shareCardShareCta;

  /// No description provided for @shareCardDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get shareCardDownload;

  /// No description provided for @shareCardOvr.
  ///
  /// In en, this message translates to:
  /// **'LEVEL'**
  String get shareCardOvr;

  /// No description provided for @shareCardLeague.
  ///
  /// In en, this message translates to:
  /// **'LEAGUE'**
  String get shareCardLeague;

  /// No description provided for @shareCardTopPct.
  ///
  /// In en, this message translates to:
  /// **'★ TOP {pct} %'**
  String shareCardTopPct(Object pct);

  /// No description provided for @shareCardAthlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get shareCardAthlete;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardWeeklyProgress.
  ///
  /// In en, this message translates to:
  /// **'Weekly progress (by effort)'**
  String get leaderboardWeeklyProgress;

  /// No description provided for @leaderboardMen.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get leaderboardMen;

  /// No description provided for @leaderboardWomen.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get leaderboardWomen;

  /// No description provided for @leaderboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard unavailable right now.'**
  String get leaderboardUnavailable;

  /// No description provided for @leaderboardRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get leaderboardRetry;

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No athletes yet.'**
  String get leaderboardEmpty;

  /// No description provided for @leaderboardYou.
  ///
  /// In en, this message translates to:
  /// **'{name}  (you)'**
  String leaderboardYou(String name);

  /// No description provided for @progressBoardTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly progress'**
  String get progressBoardTitle;

  /// No description provided for @progressBoardClubTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress · {clubName}'**
  String progressBoardClubTitle(String clubName);

  /// No description provided for @progressBoardHeader.
  ///
  /// In en, this message translates to:
  /// **'🔥 Here we reward the effort of the week — not talent. Every session, every record, every active day moves you up.'**
  String get progressBoardHeader;

  /// No description provided for @progressBoardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody has moved yet this week. Log a session and take the lead 💪'**
  String get progressBoardEmpty;

  /// No description provided for @progressBoardMyPosition.
  ///
  /// In en, this message translates to:
  /// **'Your spot this week: #{position} · {ep} effort pts'**
  String progressBoardMyPosition(Object position, Object ep);

  /// No description provided for @progressBoardPts.
  ///
  /// In en, this message translates to:
  /// **'{ep} pts'**
  String progressBoardPts(Object ep);

  /// No description provided for @archetypeHybrid.
  ///
  /// In en, this message translates to:
  /// **'HYBRID ATHLETE'**
  String get archetypeHybrid;

  /// No description provided for @archetypeAllRound.
  ///
  /// In en, this message translates to:
  /// **'ALL-ROUND'**
  String get archetypeAllRound;

  /// No description provided for @archetypeEngine.
  ///
  /// In en, this message translates to:
  /// **'ENGINE'**
  String get archetypeEngine;

  /// No description provided for @archetypeStrength.
  ///
  /// In en, this message translates to:
  /// **'STRENGTH'**
  String get archetypeStrength;

  /// No description provided for @archetypePower.
  ///
  /// In en, this message translates to:
  /// **'EXPLOSIVE'**
  String get archetypePower;

  /// No description provided for @archetypeSpeed.
  ///
  /// In en, this message translates to:
  /// **'SPEED'**
  String get archetypeSpeed;

  /// No description provided for @archetypeMuscularEndurance.
  ///
  /// In en, this message translates to:
  /// **'RELENTLESS'**
  String get archetypeMuscularEndurance;

  /// No description provided for @rfFarBetterTitle1.
  ///
  /// In en, this message translates to:
  /// **'Outstanding performance'**
  String get rfFarBetterTitle1;

  /// No description provided for @rfFarBetterBody1.
  ///
  /// In en, this message translates to:
  /// **'You beat your prediction by {gain}. This isn\'t luck: it\'s your work paying off. Note what you did well today.'**
  String rfFarBetterBody1(String gain);

  /// No description provided for @rfFarBetterTitle2.
  ///
  /// In en, this message translates to:
  /// **'You blew past the ceiling'**
  String get rfFarBetterTitle2;

  /// No description provided for @rfFarBetterBody2.
  ///
  /// In en, this message translates to:
  /// **'{gain} above what we expected from you. Your real level just pulled ahead of the model. Keep doing exactly this.'**
  String rfFarBetterBody2(String gain);

  /// No description provided for @rfFarBetterTitle3.
  ///
  /// In en, this message translates to:
  /// **'Well above target'**
  String get rfFarBetterTitle3;

  /// No description provided for @rfFarBetterBody3.
  ///
  /// In en, this message translates to:
  /// **'Prediction smashed by {gain}. A session like this is concrete proof that your preparation pays off.'**
  String rfFarBetterBody3(String gain);

  /// No description provided for @rfBetterTitle1.
  ///
  /// In en, this message translates to:
  /// **'Above target'**
  String get rfBetterTitle1;

  /// No description provided for @rfBetterBody1.
  ///
  /// In en, this message translates to:
  /// **'{gain} better than your prediction. You\'re progressing in the right direction, and it shows.'**
  String rfBetterBody1(String gain);

  /// No description provided for @rfBetterTitle2.
  ///
  /// In en, this message translates to:
  /// **'Solid. You\'re taking the lead'**
  String get rfBetterTitle2;

  /// No description provided for @rfBetterBody2.
  ///
  /// In en, this message translates to:
  /// **'You beat what was expected by {gain}. Keep this pace — that\'s exactly how you climb.'**
  String rfBetterBody2(String gain);

  /// No description provided for @rfBetterTitle3.
  ///
  /// In en, this message translates to:
  /// **'Better than expected'**
  String get rfBetterTitle3;

  /// No description provided for @rfBetterBody3.
  ///
  /// In en, this message translates to:
  /// **'+{gain} over the prediction. Small gap, real progress: build on it next session.'**
  String rfBetterBody3(String gain);

  /// No description provided for @rfOnTargetTitle1.
  ///
  /// In en, this message translates to:
  /// **'Right on target'**
  String get rfOnTargetTitle1;

  /// No description provided for @rfOnTargetBody1.
  ///
  /// In en, this message translates to:
  /// **'You hit exactly the {metric} predicted for you. Reaching your target is already a win: your level and your performance are aligned.'**
  String rfOnTargetBody1(String metric);

  /// No description provided for @rfOnTargetTitle2.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get rfOnTargetTitle2;

  /// No description provided for @rfOnTargetBody2.
  ///
  /// In en, this message translates to:
  /// **'You matched the prediction to the letter. That\'s controlled consistency — the foundation of all real progress.'**
  String get rfOnTargetBody2;

  /// No description provided for @rfOnTargetTitle3.
  ///
  /// In en, this message translates to:
  /// **'Bullseye'**
  String get rfOnTargetTitle3;

  /// No description provided for @rfOnTargetBody3.
  ///
  /// In en, this message translates to:
  /// **'You delivered the performance expected for your level. Solid and reliable: now aim one notch higher.'**
  String get rfOnTargetBody3;

  /// No description provided for @rfBelowTitle1.
  ///
  /// In en, this message translates to:
  /// **'Session in the books'**
  String get rfBelowTitle1;

  /// No description provided for @rfBelowBody1.
  ///
  /// In en, this message translates to:
  /// **'A bit below your target today, but you finished it — and that\'s what counts. We know you can do better: the next one will be stronger.'**
  String get rfBelowBody1;

  /// No description provided for @rfBelowTitle2.
  ///
  /// In en, this message translates to:
  /// **'Well done, it\'s logged'**
  String get rfBelowTitle2;

  /// No description provided for @rfBelowBody2.
  ///
  /// In en, this message translates to:
  /// **'Not your best day on {wodName}, but every rep counts toward your progress. You\'ve got the room to climb back above.'**
  String rfBelowBody2(String wodName);

  /// No description provided for @rfBelowTitle3.
  ///
  /// In en, this message translates to:
  /// **'You did the work'**
  String get rfBelowTitle3;

  /// No description provided for @rfBelowBody3.
  ///
  /// In en, this message translates to:
  /// **'Result a little under your prediction, but what matters is that you showed up. We\'re sure you can do better next time.'**
  String get rfBelowBody3;

  /// No description provided for @rfWayBelowTitle1.
  ///
  /// In en, this message translates to:
  /// **'Bad day, it happens'**
  String get rfWayBelowTitle1;

  /// No description provided for @rfWayBelowBody1.
  ///
  /// In en, this message translates to:
  /// **'Far from your usual level today — and that\'s okay. The body has its off days. Rest up, and come back to retry {wodName} fresh: you\'re worth far more than this.'**
  String rfWayBelowBody1(String wodName);

  /// No description provided for @rfWayBelowTitle2.
  ///
  /// In en, this message translates to:
  /// **'It wasn\'t your day'**
  String get rfWayBelowTitle2;

  /// No description provided for @rfWayBelowBody2.
  ///
  /// In en, this message translates to:
  /// **'This performance doesn\'t reflect what you\'re capable of. Fatigue, sleep, a busy day: it all counts. Come back to {wodName} when you\'re at your best.'**
  String rfWayBelowBody2(String wodName);

  /// No description provided for @rfWayBelowTitle3.
  ///
  /// In en, this message translates to:
  /// **'Let\'s file this session away'**
  String get rfWayBelowTitle3;

  /// No description provided for @rfWayBelowBody3.
  ///
  /// In en, this message translates to:
  /// **'Just an off day. Finishing it anyway already takes mental strength. Recover well and retry {wodName} rested — you\'ll do far better.'**
  String rfWayBelowBody3(String wodName);

  /// No description provided for @rfNoPredictionTitle1.
  ///
  /// In en, this message translates to:
  /// **'Result saved'**
  String get rfNoPredictionTitle1;

  /// No description provided for @rfNoPredictionBody1.
  ///
  /// In en, this message translates to:
  /// **'Nice session, it\'s in the books. A few more workouts and we\'ll be able to tell you exactly where you stand — and predict your next times.'**
  String get rfNoPredictionBody1;

  /// No description provided for @rfNoPredictionTitle2.
  ///
  /// In en, this message translates to:
  /// **'Logged, keep going'**
  String get rfNoPredictionTitle2;

  /// No description provided for @rfNoPredictionBody2.
  ///
  /// In en, this message translates to:
  /// **'Every saved result brings your full Index closer. Soon, we\'ll give you a personalized target to beat on every session.'**
  String get rfNoPredictionBody2;

  /// No description provided for @rfMetricTime.
  ///
  /// In en, this message translates to:
  /// **'time'**
  String get rfMetricTime;

  /// No description provided for @rfMetricScore.
  ///
  /// In en, this message translates to:
  /// **'score'**
  String get rfMetricScore;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @leagueScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'League of the month'**
  String get leagueScreenTitle;

  /// No description provided for @leagueUnavailable.
  ///
  /// In en, this message translates to:
  /// **'League unavailable right now.'**
  String get leagueUnavailable;

  /// No description provided for @leagueRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get leagueRetry;

  /// No description provided for @leagueNoSeason.
  ///
  /// In en, this message translates to:
  /// **'No League season in progress.\nCheck back soon: a new season starts every month.'**
  String get leagueNoSeason;

  /// No description provided for @leagueHeaderMen.
  ///
  /// In en, this message translates to:
  /// **'MEN\'S LEAGUE'**
  String get leagueHeaderMen;

  /// No description provided for @leagueHeaderWomen.
  ///
  /// In en, this message translates to:
  /// **'WOMEN\'S LEAGUE'**
  String get leagueHeaderWomen;

  /// No description provided for @leagueLastDay.
  ///
  /// In en, this message translates to:
  /// **'Last day of the season'**
  String get leagueLastDay;

  /// No description provided for @leagueEndsIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Ends in {days} day} other{Ends in {days} days}}'**
  String leagueEndsIn(int days);

  /// No description provided for @leaguePointsReset.
  ///
  /// In en, this message translates to:
  /// **'Points reset to zero every month.'**
  String get leaguePointsReset;

  /// No description provided for @leagueExplainerTitle.
  ///
  /// In en, this message translates to:
  /// **'What is the League of the month?'**
  String get leagueExplainerTitle;

  /// No description provided for @leagueExplainerBody.
  ///
  /// In en, this message translates to:
  /// **'Every month, a new season. You\'re ranked AUTOMATICALLY among athletes of your sex. Do the imposed workout of the week: you score points based on your performance. League points reset to zero every month.'**
  String get leagueExplainerBody;

  /// No description provided for @leagueWeekWod.
  ///
  /// In en, this message translates to:
  /// **'WORKOUT OF THE WEEK'**
  String get leagueWeekWod;

  /// No description provided for @leagueWeekWodHint.
  ///
  /// In en, this message translates to:
  /// **'The imposed workout of the week — give it everything to climb the ranking.'**
  String get leagueWeekWodHint;

  /// No description provided for @leagueDoThisWod.
  ///
  /// In en, this message translates to:
  /// **'Do this workout'**
  String get leagueDoThisWod;

  /// No description provided for @leagueStandingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Ranking unavailable.'**
  String get leagueStandingsUnavailable;

  /// No description provided for @leagueStandingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ranking of the month'**
  String get leagueStandingsTitle;

  /// No description provided for @leagueStandingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody has scored yet this month. Be the first!'**
  String get leagueStandingsEmpty;

  /// No description provided for @leagueMyPosition.
  ///
  /// In en, this message translates to:
  /// **'MY POSITION'**
  String get leagueMyPosition;

  /// No description provided for @leaguePts.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String leaguePts(int points);

  /// No description provided for @leagueDoWodToEnter.
  ///
  /// In en, this message translates to:
  /// **'Do the workout to enter the ranking'**
  String get leagueDoWodToEnter;

  /// No description provided for @leagueThisMonth.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get leagueThisMonth;

  /// No description provided for @leagueRowYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (me)'**
  String leagueRowYou(String name);

  /// No description provided for @notificationsJoinedClub.
  ///
  /// In en, this message translates to:
  /// **'You joined {clubName}!'**
  String notificationsJoinedClub(String clubName);

  /// No description provided for @notificationsClubInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Club invitation'**
  String get notificationsClubInviteTitle;

  /// No description provided for @notificationsClubInviteMembers.
  ///
  /// In en, this message translates to:
  /// **'{clubName} · {count, plural, one{{count} member} other{{count} members}}'**
  String notificationsClubInviteMembers(String clubName, int count);

  /// No description provided for @notificationsJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get notificationsJoin;

  /// No description provided for @notificationsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get notificationsDecline;
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
