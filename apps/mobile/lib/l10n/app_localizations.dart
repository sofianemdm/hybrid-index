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

  /// No description provided for @wodTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get wodTabTitle;

  /// No description provided for @wodTabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a workout (also called a \"WOD\"), see the records and where you stand.'**
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
  /// **'just joined us with a HYBRID INDEX of {index} 👋'**
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
  /// **'No conversation yet. Message an athlete you follow (and who follows you) or a member of your club.'**
  String get conversationsEmpty;

  /// No description provided for @conversationsYouPrefix.
  ///
  /// In en, this message translates to:
  /// **'You: '**
  String get conversationsYouPrefix;

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

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettingsTitle;

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
  /// **'Club ranking (Hybrid Index)'**
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

  /// No description provided for @scoreV2Title.
  ///
  /// In en, this message translates to:
  /// **'New: your Index out of 100 🎯'**
  String get scoreV2Title;

  /// No description provided for @scoreV2Body.
  ///
  /// In en, this message translates to:
  /// **'The HYBRID INDEX is now shown out of 100, like a game rating. Your level hasn\'t changed — only the way it\'s displayed evolves, to be more readable.'**
  String get scoreV2Body;

  /// No description provided for @scoreV2YourIndex.
  ///
  /// In en, this message translates to:
  /// **'Your HYBRID INDEX'**
  String get scoreV2YourIndex;

  /// No description provided for @scoreV2Benchmarks.
  ///
  /// In en, this message translates to:
  /// **'Benchmarks: beginner ~45 · good level ~80 · pro ~92+'**
  String get scoreV2Benchmarks;

  /// No description provided for @scoreV2Got.
  ///
  /// In en, this message translates to:
  /// **'Got it 💪'**
  String get scoreV2Got;

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
  /// **'YOUR HYBRID INDEX'**
  String get revealYourIndex;

  /// No description provided for @revealProvisional.
  ///
  /// In en, this message translates to:
  /// **'Provisional Index — refine it by logging more sessions.'**
  String get revealProvisional;

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
  /// **'My HYBRID INDEX 💪 What\'s yours? #HybridIndex'**
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
  /// **'OVR'**
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
  /// **'Leaderboard'**
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
