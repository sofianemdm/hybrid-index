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
  String get navLeaderboard => 'League';

  @override
  String get settingsEmailLabel => 'Email address';

  @override
  String get settingsInviteFriend => 'Invite a friend';

  @override
  String get offlineBanner => 'Offline — showing last known data';

  @override
  String get outboxQueued =>
      'No network: session queued, it will send automatically. ⏳';

  @override
  String outboxSynced(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n queued sessions synced ✓',
      one: 'Queued session synced ✓',
    );
    return '$_temp0';
  }

  @override
  String outboxPending(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sessions awaiting sync',
      one: '1 session awaiting sync',
    );
    return '$_temp0';
  }

  @override
  String get clubFeedTitle => 'Club feed';

  @override
  String get clubFeedPost => 'Post';

  @override
  String get clubFeedEmpty => 'No posts yet. Start the conversation!';

  @override
  String shareInviteMessage(String link) {
    return 'Join me on Athlete League 💪 One score for your fitness, a radar of your strengths, and a monthly league. $link';
  }

  @override
  String shareWodMessage(String wodName, String link) {
    return 'Come challenge me on $wodName 💪 $link';
  }

  @override
  String shareWodMessageWithBest(String best, String wodName, String link) {
    return 'I scored $best on $wodName — come beat me 💪 $link';
  }

  @override
  String shareProfileMessage(String name, String link) {
    return 'Check out $name\'s profile on Athlete League: $link';
  }

  @override
  String get shareTooltip => 'Share';

  @override
  String get settingsEquipmentLabel =>
      'Equipment — \"Equipped\" also unlocks equipment-free sessions';

  @override
  String get settingsEquipmentNone => 'No equipment';

  @override
  String get settingsEquipmentEquipped => 'Equipped (gym)';

  @override
  String get settingsUpdated => 'Profile updated.';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsByFocus => 'Sessions by focus';

  @override
  String get sessionsWeeklyTitle => 'Session of the week';

  @override
  String get sessionsLeagueBadge => 'LEAGUE';

  @override
  String get sessionsLeagueImposedBody =>
      'This month\'s League required session. Do it to score points in the standings.';

  @override
  String get sessionsLeagueDoIt => 'Do this session';

  @override
  String get sessionsCountsMost => 'Counts a lot';

  @override
  String sessionsAttributeHeader(String attribute) {
    return 'Workouts that count toward your $attribute score';
  }

  @override
  String get leaderboardIntro =>
      'The ranking of every athlete in your league (your sex), sorted by Athlete Index — normalized by sex for fairness. Climb by improving your score.';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonGenericError => 'Something went wrong. Please try again.';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get celebrationContinue => 'Continue';

  @override
  String get celebrationTapToContinue => 'Tap to continue';

  @override
  String get celebrationClose => 'Close';

  @override
  String get bugReportTitle => 'Report a bug';

  @override
  String get bugReportHint =>
      'Describe the issue: what you were doing, what happened, which screen…';

  @override
  String get bugReportSend => 'Send';

  @override
  String get bugReportThanks => 'Thanks! Your report was sent. 🙏';

  @override
  String get bugReportTooShort => 'Add a few words describing the bug.';

  @override
  String get homeBetaBanner => 'Beta version — found a bug? Tap to learn more';

  @override
  String get homeBetaTitle => 'App in beta';

  @override
  String get homeBetaBody =>
      'It\'s evolving fast: you may still hit bugs, inconsistencies or imperfect data. Tell us anything that looks off so we can fix it quickly — every report helps. 🙏';

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
  String get authEmail => 'Email';

  @override
  String get authBirthdate => 'Date of birth';

  @override
  String get authPickDate => 'Pick…';

  @override
  String get authSexLabel => 'Sex (used for fair ranking)';

  @override
  String get authSexMale => 'Male';

  @override
  String get authSexFemale => 'Female';

  @override
  String get authEquipmentLabel =>
      'Equipment (changeable later) — \"Equipped\" also unlocks equipment-free sessions';

  @override
  String get authEquipmentNone => 'No equipment';

  @override
  String get authEquipmentEquipped => 'Equipped (gym)';

  @override
  String get gpTitle => 'Complete my profile';

  @override
  String get gpSubtitle =>
      'A few more details to finish setting up your Google account.';

  @override
  String get gpUsernameMin => 'Pick a username (min 2 characters).';

  @override
  String get gpEquipmentShort => 'Equipment';

  @override
  String get avatarSurpriseMe => 'Surprise me';

  @override
  String get avatarColorLabel => 'Color';

  @override
  String get avatarForgeTitle => 'Forge your athlete';

  @override
  String get avatarValidate => 'Confirm my athlete';

  @override
  String get avatarReadyTitle => 'Your athlete is ready!';

  @override
  String get avatarReadyBody => 'It will carry your colors in the rankings.';

  @override
  String get settingsExportOk => 'Data exported 📥';

  @override
  String get settingsExportUnsupported => 'Export not supported here.';

  @override
  String get prWallTitle => 'My records';

  @override
  String get prWallError => 'Records unavailable.';

  @override
  String get prWallEmpty =>
      'No records yet.\nLog a session: your first record awaits!';

  @override
  String get gainsNoNewRecord =>
      'No new record this time — but every session builds your consistency.';

  @override
  String get radarInsightBalanced =>
      'Complete athlete — your radar is remarkably balanced. You embody the hybrid spirit.';

  @override
  String get radarNotAssessed => 'not assessed';

  @override
  String get radarEstimated => 'estimated';

  @override
  String get authDateOfBirth => 'Date of birth';

  @override
  String get authChoose => 'Choose…';

  @override
  String get authOr => 'or';

  @override
  String get ageRestricted => 'You must be at least 15.';

  @override
  String homeProjection(int grade, int weeks) {
    return 'At this rate: $grade+ in ~$weeks wk.';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get wreSecondsRange => 'Seconds must be between 0 and 59.';

  @override
  String get wreInvalidResult => 'Enter a valid result.';

  @override
  String get wreNeedDistance => 'Enter the distance covered (in meters).';

  @override
  String get wreIndexClimbs => 'Your Athlete Index is climbing.';

  @override
  String get wreShareFeat => 'Share my achievement';

  @override
  String wreBadgeUnlocked(String name) {
    return 'Badge unlocked: $name';
  }

  @override
  String wreBadgesUnlocked(int count) {
    return '$count new badges unlocked!';
  }

  @override
  String get wreSeeMyBadges => 'See my badges';

  @override
  String get wreProgressTitle => 'You\'re progressing 💪';

  @override
  String get wreOutOfBounds => 'Result outside plausible bounds.';

  @override
  String get wreYourTime => 'Your time';

  @override
  String wreYourResult(String unit) {
    return 'Your result ($unit)';
  }

  @override
  String wreBandUp(int percent) {
    return '🚀 You\'re entering the top $percent% of the fittest!';
  }

  @override
  String wreOvertookTitle(String name) {
    return 'You passed $name!';
  }

  @override
  String get wreOvertookSubtitle => 'A new rival in sight';

  @override
  String get wreUnitTime => 'time';

  @override
  String get wreDistanceLabel => 'Distance covered (meters)';

  @override
  String get wreDistanceHint => 'e.g. 5000';

  @override
  String get wreResultHint => 'result';

  @override
  String get wreCategory => 'Category';

  @override
  String get wreScale => 'Scale';

  @override
  String get wrePro => 'Pro';

  @override
  String get wreRx => 'Rx (prescribed)';

  @override
  String get wreOpen => 'Open';

  @override
  String get wreScaled => 'Scaled';

  @override
  String get wreSeparatedPro => 'Pro and Open leaderboards are separate.';

  @override
  String get wreSeparatedRx => 'Rx and Scaled leaderboards are separate.';

  @override
  String get wreSave => 'Save';

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
  String get onbMaxPullups => 'Max strict pull-ups (one set)';

  @override
  String get onbSquat1rm => 'Squat 1RM (max load, 1 rep)';

  @override
  String get onbSquat1rmHint =>
      'Your heaviest back squat for a single rep, in kilograms.';

  @override
  String get onbRevealCta => 'Reveal my Athlete Index';

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
  String get onbNoInfoSkip => 'I don\'t have any of this info';

  @override
  String get onbNoInfoSkipHint =>
      'Continue without an Index — reveal it later by doing a workout.';

  @override
  String get onbRunNeedsBoth =>
      'Distance (0.4–42 km) and time required for the run.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSeeMore => 'See more';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsCustomizeAvatar => 'Customize my avatar';

  @override
  String get legalPrivacyLink => 'Privacy policy';

  @override
  String get legalTermsLink => 'Terms of use';

  @override
  String get authLegalNotice => 'By creating an account, you accept:';

  @override
  String get settingsPrivacy => 'Data & privacy (GDPR)';

  @override
  String get settingsExport => 'Export my data';

  @override
  String get settingsDeleteAccount => 'Delete my account';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get deleteAccountBody =>
      'This action is permanent: all your data will be erased.';

  @override
  String get wodTabTitle => 'Workouts';

  @override
  String get wodTabSubtitle =>
      'Pick a workout, see the records and where you stand.';

  @override
  String get wodTabEmpty =>
      'No reference workout available right now. Browse sessions by focus above, or pull to refresh.';

  @override
  String get wodTabFlagshipSection => '⭐ Flagship workouts';

  @override
  String get wodTabFlagshipCaption =>
      'The 4 big challenges everyone measures themselves against.';

  @override
  String get wodTabNoEquipment => 'No equipment';

  @override
  String get wodTabWithEquipment => 'With equipment';

  @override
  String get wodTabOtherTitle => 'Other';

  @override
  String get wodTabOtherSubtitle =>
      'Real events (HYROX, CrossFit competitions, races) + real pro times';

  @override
  String get wodTabMyHistory => 'My workout history';

  @override
  String get otherWorkoutsTitle => 'Other events';

  @override
  String get otherWorkoutsIntro =>
      'Major real-world events (HYROX, competition workouts, races). Open one to see the details and records — and log your time.';

  @override
  String get otherWorkoutsNoEquipment => 'No equipment';

  @override
  String get otherWorkoutsWithEquipment => 'With equipment';

  @override
  String get otherWorkoutsCommunitySection => 'Community workouts';

  @override
  String get otherWorkoutsCommunityEmpty =>
      'No workouts created by users yet. Create yours via \"Build a workout\".';

  @override
  String get logWodTitle => 'Pick a workout';

  @override
  String get logWodIntro =>
      'Pick a workout to see what it involves, the reference times and the leaderboard — then log your result.';

  @override
  String get logWodNoEquipment => 'No equipment';

  @override
  String get logWodWithEquipment => 'With equipment';

  @override
  String get wodDetailReferenceTimes => 'Reference times';

  @override
  String get wodDetailReferenceTimesCaption =>
      'Beginner · intermediate · champion, by sex';

  @override
  String get wodDetailNoTiers => 'Tiers not available for this workout.';

  @override
  String get wodDetailLeaderboard => 'Leaderboard';

  @override
  String get wodDetailLogTime => 'Log your time';

  @override
  String get wodDetailStartTimer => 'Start your timer here';

  @override
  String get wodDetailEdit => 'Edit workout';

  @override
  String get wodDetailDelete => 'Delete workout';

  @override
  String get wodDetailDeleteTitle => 'Delete this workout?';

  @override
  String get wodDetailDeleteBody =>
      'This action is permanent. If athletes have already logged a result, deletion will be refused.';

  @override
  String get wodDetailDeleteCancel => 'Cancel';

  @override
  String get wodDetailDeleteConfirm => 'Delete';

  @override
  String get wodDetailDeleteDone => 'Workout deleted.';

  @override
  String get wodDetailMen => 'Men';

  @override
  String get wodDetailWomen => 'Women';

  @override
  String get wodDetailTierChampion => '🏆 Champion (elite)';

  @override
  String get wodDetailTierIntermediate => 'Intermediate';

  @override
  String get wodDetailTierBeginner => 'Beginner';

  @override
  String get wodDetailYou => 'You: ';

  @override
  String wodDetailBeatRecord(String best) {
    return 'You already did $best on this workout — beat your record!';
  }

  @override
  String wodDetailPoints(int n) {
    return '$n pts';
  }

  @override
  String wodDetailMinutes(int n) {
    return '$n min';
  }

  @override
  String get wodDetailChallenge => 'The challenge';

  @override
  String wodDetailCap(String cap) {
    return 'Cap $cap';
  }

  @override
  String get movementGuideA11y => 'See the movement explanation:';

  @override
  String get movementGuideUnavailable => 'Image unavailable.';

  @override
  String get movementGuideZoomHint => 'Pinch to zoom';

  @override
  String get wodDetailLoads => 'LOADS';

  @override
  String get wodDetailRx => 'RX: ';

  @override
  String get wodDetailLight => 'Light: ';

  @override
  String get wodDetailScopeAll => '🌍 All';

  @override
  String get wodDetailMyClub => 'My club';

  @override
  String get wodDetailWorldRecord => '🌍 World record';

  @override
  String get wodDetailElite => '⭐ Elite';

  @override
  String get wodDetailMyPerformances => 'My performances';

  @override
  String get wodDetailLeaderboardEmpty => 'Be the first to post a result 💪';

  @override
  String get wodDetailVariantRx => 'Rx';

  @override
  String get wodDetailVariantScaled => 'Scaled';

  @override
  String get wodDetailVariantOpen => 'Open';

  @override
  String get wodFormatRounds => 'rounds';

  @override
  String get wodDetailYouShort => 'You';

  @override
  String wodDetailLeaderboardYou(String name) {
    return '$name (you)';
  }

  @override
  String get wodBuilderTitle => 'Build a workout';

  @override
  String get wodBuilderEditTitle => 'Edit workout';

  @override
  String get wodBuilderSaveChanges => 'Save changes';

  @override
  String get wodBuilderFormat => 'Format';

  @override
  String get wodBuilderRoundsLabel => 'Number of rounds: ';

  @override
  String get wodBuilderRoundsHint => 'e.g. 3';

  @override
  String get wodBuilderRoundsCaption => '(the movements repeat N times)';

  @override
  String get wodBuilderTimeNote =>
      'No time to enter here: the score is the time you take to finish, which you\'ll log when doing the workout.';

  @override
  String get wodBuilderCapLabel => 'Cap (min): ';

  @override
  String get wodBuilderCapHint => 'e.g. 12';

  @override
  String get wodBuilderRequiresEquipment => 'Requires equipment';

  @override
  String get wodBuilderMovements => 'Movements';

  @override
  String get wodBuilderAddMovement => 'Add a movement';

  @override
  String get wodBuilderPublish => 'Publish this workout';

  @override
  String get wodBuilderAddMovementError => 'Add at least one movement.';

  @override
  String get wodBuilderCustomWorkout => 'Custom workout';

  @override
  String get wodBuilderWorkout => 'Workout';

  @override
  String get wodBuilderAssignedName => 'Assigned name';

  @override
  String get wodBuilderEstimateEmpty => 'Add movements to see the estimate.';

  @override
  String get wodBuilderEstimateUnavailable =>
      'Load estimation isn\'t available yet for custom workouts. Add a loaded (weightlifting) movement for a kg estimate.';

  @override
  String get wodBuilderEstimateError => 'Estimate unavailable.';

  @override
  String get wodBuilderEstimate => 'Estimate';

  @override
  String get wodBuilderEstimated => '≈ estimated';

  @override
  String wodBuilderEstimateChampion(String result) {
    return '🏆 Champion: $result';
  }

  @override
  String wodBuilderEstimateIntermediate(String result) {
    return 'Intermediate: $result';
  }

  @override
  String wodBuilderEstimateBeginner(String result) {
    return 'Beginner: $result';
  }

  @override
  String get wodBuilderSearchMovement => 'Search a movement';

  @override
  String get wodFmtForTime => 'For Time';

  @override
  String get wodFmtAmrap => 'AMRAP';

  @override
  String get wodFmtEmom => 'EMOM';

  @override
  String get wodFmtInterval => 'Intervals';

  @override
  String get wodFmtTabata => 'Tabata';

  @override
  String get wodFmtStrength => 'Strength';

  @override
  String get wodUnitHintMeter => 'e.g. 2000';

  @override
  String get wodUnitHintCalorie => 'e.g. 15';

  @override
  String get wodUnitHintSecond => 'e.g. 30';

  @override
  String get wodUnitHintRep => 'e.g. 10';

  @override
  String get wodUnitSuffixMeter => 'm';

  @override
  String get wodUnitSuffixCalorie => 'cal';

  @override
  String get wodUnitSuffixSecond => 'sec';

  @override
  String get wodUnitSuffixRep => 'reps';

  @override
  String get wodUnitSuffixKg => 'kg';

  @override
  String get wodUnitMeters => 'meters';

  @override
  String get wodBuilderCatalogLoading => 'Loading movements…';

  @override
  String get wodBuilderCatalogError => 'Couldn\'t load movements.';

  @override
  String get wodBuilderNameLabel => 'Workout name';

  @override
  String get wodBuilderNameHint => 'Name your workout';

  @override
  String get wodBuilderNameAutoHint => 'Auto-generated — you can edit it.';

  @override
  String get wodBuilderDiscardTitle => 'Discard workout?';

  @override
  String get wodBuilderDiscardBody => 'Your movements won\'t be saved.';

  @override
  String get wodBuilderDiscardStay => 'Keep editing';

  @override
  String get wodBuilderDiscardLeave => 'Discard';

  @override
  String get a11yEstimateLiveRegion => 'Estimate updated';

  @override
  String get communityTitle => 'Community';

  @override
  String get communityEmpty =>
      'Follow athletes to see their activity, or log a workout to start your feed.';

  @override
  String get communityPublish => 'Post';

  @override
  String get communityExploreClubs => 'Explore clubs';

  @override
  String get communityTooltipMessages => 'Messages';

  @override
  String get communityTooltipPublish => 'Post';

  @override
  String get communityTooltipClubs => 'Clubs';

  @override
  String get communityTooltipSearch => 'Search';

  @override
  String get communityPostDelete => 'Delete';

  @override
  String get communityPostReport => 'Report';

  @override
  String get communityPostBlock => 'Block this athlete';

  @override
  String get communityUserBlocked => 'Athlete blocked.';

  @override
  String get communityReportSent => 'Thanks, report sent.';

  @override
  String get communityBlockConfirmTitle => 'Block this athlete?';

  @override
  String get communityBlockConfirmBody =>
      'You will no longer see their activity and they cannot contact you. You can unblock them later in settings.';

  @override
  String get communityBlockConfirmAction => 'Block';

  @override
  String get communityDeleteConfirmTitle => 'Delete this post?';

  @override
  String get communityDeleteConfirmBody =>
      'This post will be permanently removed. This action cannot be undone.';

  @override
  String get communityPostDeleted => 'Post deleted.';

  @override
  String get communityDiscoverTitle => 'Nobody to follow… yet';

  @override
  String get communityDiscoverSubtitle =>
      'Here\'s the top of your league. Follow athletes to fill your feed.';

  @override
  String get communityFollow => 'Follow';

  @override
  String get communityFollowing => 'Following';

  @override
  String get communityKudosTooltip => 'Like';

  @override
  String get communityWorkoutFallback => 'a workout';

  @override
  String get communityScopeAll => 'All';

  @override
  String get communityScopeFollowing => 'Following';

  @override
  String get communityEmptyFollowing =>
      'You\'re not following anyone yet. Switch to \"All\" to discover the community, or follow athletes to fill your feed.';

  @override
  String get commentsTitle => 'Comments';

  @override
  String get commentsEmpty => 'No comments yet. Be the first to react.';

  @override
  String get commentHint => 'Add a comment…';

  @override
  String get commentSend => 'Send';

  @override
  String get commentDelete => 'Delete';

  @override
  String get commentReport => 'Report';

  @override
  String get commentDeleted => 'Comment deleted.';

  @override
  String get commentKudosTooltip => 'Like';

  @override
  String get commentReply => 'Reply';

  @override
  String commentReplyHint(String name) {
    return 'Reply to $name…';
  }

  @override
  String commentRepliesShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: 'reply',
    );
    return 'Show $_temp0';
  }

  @override
  String get commentRepliesHide => 'Hide replies';

  @override
  String a11yCommentKudos(int count) {
    return 'Like, $count';
  }

  @override
  String a11yMention(String name) {
    return 'Mention of $name, open profile';
  }

  @override
  String get profileWallTitle => 'Posts';

  @override
  String get profileWallEmpty => 'This athlete hasn\'t posted anything yet.';

  @override
  String get profileWallEmptyMine =>
      'You haven\'t posted anything yet. Share a result or a message from Community.';

  @override
  String get composerMentionHint => 'Mention someone with @';

  @override
  String get notifPostKudos => 'Your post got a like 👍';

  @override
  String notifPostKudosBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people liked',
      one: '1 person liked',
    );
    return '$_temp0 your post.';
  }

  @override
  String get notifComment => 'New comment';

  @override
  String notifCommentBody(String name) {
    return '$name commented on your post.';
  }

  @override
  String get notifCommentKudos => 'Your comment got a like 👍';

  @override
  String notifCommentKudosBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people liked',
      one: '1 person liked',
    );
    return '$_temp0 your comment.';
  }

  @override
  String get notifReply => 'New reply';

  @override
  String notifReplyBody(String name) {
    return '$name replied to your comment.';
  }

  @override
  String get notifMention => 'You were mentioned';

  @override
  String notifMentionBody(String name) {
    return '$name mentioned you.';
  }

  @override
  String get timeAgoNow => 'just now';

  @override
  String timeAgoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String timeAgoHours(int n) {
    return '$n h ago';
  }

  @override
  String timeAgoDays(int n) {
    return '$n d ago';
  }

  @override
  String communityMsgPr(String wodName) {
    return '🏆 New record — $wodName';
  }

  @override
  String communityMsgWodLogged(String wodName) {
    return 'did $wodName';
  }

  @override
  String communityMsgRankUp(String rank) {
    return 'is promoted to $rank 🎖️';
  }

  @override
  String communityMsgBadge(String name) {
    return 'badge unlocked: $name';
  }

  @override
  String communityMsgMemberJoined(String index) {
    return 'just joined us with a Athlete Index of $index 👋';
  }

  @override
  String communityMsgPostPerf(String wodName) {
    return '💪 shared a perf — $wodName';
  }

  @override
  String get communityMsgDefault => 'new activity';

  @override
  String get exploreTitle => 'Athletes';

  @override
  String get exploreSearchHint => 'Search a username';

  @override
  String get exploreFilterAll => 'All';

  @override
  String get exploreFilterMen => 'Men';

  @override
  String get exploreFilterWomen => 'Women';

  @override
  String get exploreEmpty => 'No athletes.';

  @override
  String get composerTitle => 'Post';

  @override
  String get composerPickPerf => 'Pick a perf to share.';

  @override
  String get composerWriteMessage => 'Write a message.';

  @override
  String get composerModeMessage => '💬 Message';

  @override
  String get composerModePerf => '💪 Share a perf';

  @override
  String get composerCaptionLabel => 'Caption (optional)';

  @override
  String get composerHintPerf => 'A word about this perf…';

  @override
  String get composerHintText => 'What\'s up, athlete?';

  @override
  String get composerPublish => 'Post';

  @override
  String get composerNoResults =>
      'Log a workout first to be able to share a perf.';

  @override
  String get composerPickPerfLabel => 'Pick the perf to share';

  @override
  String chatStartConversation(String name) {
    return 'Start the conversation with $name 👋';
  }

  @override
  String get chatHint => 'Write a message…';

  @override
  String get conversationsTitle => 'Messages';

  @override
  String get conversationsEmpty =>
      'No conversation yet. Open an athlete\'s profile and say hi — everyone is reachable.';

  @override
  String get conversationsYouPrefix => 'You: ';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatLoadOlder => 'Load earlier messages';

  @override
  String get chatStatusSending => 'Sending…';

  @override
  String get chatStatusFailed => 'Failed — tap to retry';

  @override
  String get chatStatusSent => 'Sent';

  @override
  String get chatStatusRead => 'Read';

  @override
  String chatTyping(String name) {
    return '$name is typing…';
  }

  @override
  String get chatNewMessage => 'New message';

  @override
  String newMessageBannerTitle(String name) {
    return 'New message from $name';
  }

  @override
  String get newMessageBannerOpen => 'Open';

  @override
  String get newMessageSenderFallback => 'an athlete';

  @override
  String get chatViewProfile => 'View profile';

  @override
  String get chatBlock => 'Block';

  @override
  String chatBlockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get chatBlockConfirmBody =>
      'You won\'t be able to message each other anymore. You can unblock them later.';

  @override
  String get chatBlockCancel => 'Cancel';

  @override
  String get chatBlockConfirm => 'Block';

  @override
  String chatBlocked(String name) {
    return '$name has been blocked.';
  }

  @override
  String get dmReasonAge =>
      'Private messages are only possible between accounts in the same age range.';

  @override
  String get dmReasonBlocked => 'Can\'t message this user.';

  @override
  String get dmReasonUnavailable => 'This account is no longer available.';

  @override
  String get messagingErrorRateLimited =>
      'You\'re sending too many messages. Try again in a moment.';

  @override
  String get messagingErrorNotAllowed => 'Can\'t message this user.';

  @override
  String get messagingErrorNotFound => 'Conversation not found.';

  @override
  String get messagingErrorTooLong => 'Message too long (2000 characters max).';

  @override
  String get messagingErrorNetwork =>
      'Can\'t connect. Check your connection and try again.';

  @override
  String get messagingErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSettingsTooltip => 'Settings';

  @override
  String get notificationsEmpty =>
      'Nothing new for now. Log a session to get things moving!';

  @override
  String notificationsNewMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '1 new message',
    );
    return '$_temp0';
  }

  @override
  String get notificationsNewMessagesBody => 'Open your conversations.';

  @override
  String get feedWeekAlmostTitle => 'One workout to go';

  @override
  String feedWeekAlmostBody(int count, int goal) {
    return 'One workout and your week is validated ($count/$goal).';
  }

  @override
  String get feedWeekValidatedTitle => 'Week validated';

  @override
  String feedWeekValidatedBody(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'Current streak: $streak weeks. Keep it up!',
      one: 'Current streak: 1 week. Keep it up!',
    );
    return '$_temp0';
  }

  @override
  String feedNextRankTitle(String rank) {
    return 'Rank $rank is close';
  }

  @override
  String feedNextRankBody(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: 'Just $points points to go.',
      one: 'Just 1 point to go.',
    );
    return '$_temp0';
  }

  @override
  String feedRankOvertakenTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count athletes passed you',
      one: 'An athlete passed you',
    );
    return '$_temp0';
  }

  @override
  String get feedRankOvertakenBody => 'Reclaim your spot on the leaderboard.';

  @override
  String feedWodOvertakenTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Beaten on $count workouts',
      one: 'An athlete beat your time',
    );
    return '$_temp0';
  }

  @override
  String get feedWodOvertakenBody => 'Go defend your scores.';

  @override
  String get notificationSettingsTitle => 'Notification settings';

  @override
  String get notificationSettingsComingSoon =>
      'Push notifications are coming soon. Your preferences below will apply as soon as they go live.';

  @override
  String get notificationSettingsSaved => 'Preferences saved.';

  @override
  String get notificationSettingsQuietHours => 'Quiet hours';

  @override
  String get notificationSettingsStart => 'Start';

  @override
  String get notificationSettingsEnd => 'End';

  @override
  String get notificationSettingsDailyCap => 'Maximum per day';

  @override
  String get notificationSettingsTypes => 'Notification types';

  @override
  String get notificationSettingsSave => 'Save';

  @override
  String get clubsTitle => 'Clubs';

  @override
  String get clubsCreateTitle => 'Create a club';

  @override
  String get clubsNameLabel => 'Club name';

  @override
  String get clubsDescriptionLabel => 'Description (optional)';

  @override
  String get clubsCancel => 'Cancel';

  @override
  String get clubsCreate => 'Create';

  @override
  String get clubsSearchHint => 'Search for a club to join';

  @override
  String get clubsInvitations => 'Invitations';

  @override
  String get clubsMine => 'My clubs';

  @override
  String get clubsDiscover => 'All clubs';

  @override
  String get clubsEmpty =>
      'You\'re not in any club. Create your own or join one 👥';

  @override
  String get clubsView => 'View';

  @override
  String clubsMembers(int count) {
    return '$count members';
  }

  @override
  String clubsMembersOwner(int count) {
    return '$count members · creator';
  }

  @override
  String clubsMembersInvite(int count) {
    return '$count members · invites you';
  }

  @override
  String get clubDetailOwnerTitle => 'You\'re the creator';

  @override
  String get clubDetailLeaveTitle => 'Leave the club?';

  @override
  String get clubDetailOwnerMessage =>
      'Transfer the club first, or wait until you\'re alone to leave it.';

  @override
  String get clubDetailLeaveMessage => 'You can join again later.';

  @override
  String get clubDetailCancel => 'Cancel';

  @override
  String get clubDetailLeave => 'Leave';

  @override
  String get clubDetailRankingBySeance => 'Club ranking by session';

  @override
  String get clubDetailJoin => 'Join the club';

  @override
  String get clubDetailProgression => 'Progress';

  @override
  String get clubDetailBySeance => 'By session';

  @override
  String get clubDetailRankingTitle => 'Club ranking (Athlete Index)';

  @override
  String get clubDetailLeaveButton => 'Leave the club';

  @override
  String clubDetailMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String clubDetailRosterMe(String name) {
    return '$name (you)';
  }

  @override
  String get publicProfileFollowing => 'Following';

  @override
  String get publicProfileFollow => 'Follow';

  @override
  String get publicProfileMessage => 'Message';

  @override
  String get publicProfileInviteToClub => 'Invite to my club';

  @override
  String get publicProfileInviteNoClub => 'Create a club first to invite.';

  @override
  String get publicProfileInviteInto => 'Invite into…';

  @override
  String publicProfileInviteSent(String name) {
    return 'Invitation sent to « $name »';
  }

  @override
  String publicProfileLeaguePosition(int position) {
    return '#$position in their league';
  }

  @override
  String publicProfileLeaguePositionMine(int position) {
    return '#$position in your league';
  }

  @override
  String get publicProfileNoIndex => 'No Index yet.';

  @override
  String get publicProfileComparison => 'Comparison';

  @override
  String get publicProfileTheirRadar => 'Their radar';

  @override
  String get publicProfileHistoryTitle => 'Session history';

  @override
  String get publicProfileHistoryEmpty =>
      'This athlete hasn\'t logged any session yet.';

  @override
  String get publicProfileYourRadar => 'Your radar';

  @override
  String publicProfileCompareAhead(int diff, int mine, int other) {
    return 'You\'re ahead by $diff points (you $mine · them $other).';
  }

  @override
  String publicProfileCompareBehind(int diff, int mine, int other) {
    return 'They\'re ahead of you by $diff points (you $mine · them $other).';
  }

  @override
  String get avatarTitle => 'My avatar';

  @override
  String get avatarImageTooLarge => 'Image too large — pick a smaller one.';

  @override
  String get avatarAddPhoto => 'Add a photo';

  @override
  String get avatarChangePhoto => 'Change photo';

  @override
  String get avatarRemove => 'Remove';

  @override
  String get avatarPhotoHidesDrawn =>
      'With a photo, the drawn avatar is hidden.';

  @override
  String get avatarSkin => 'Skin tone';

  @override
  String get avatarHairColor => 'Hair color';

  @override
  String get avatarHaircut => 'Haircut';

  @override
  String get avatarBeard => 'Beard';

  @override
  String get avatarBackground => 'Background';

  @override
  String get avatarSave => 'Save my avatar';

  @override
  String get leagueMen => 'Men';

  @override
  String get leagueWomen => 'Women';

  @override
  String get historyTitle => 'My history';

  @override
  String get historyRun => 'Run';

  @override
  String get historyEmpty => 'No session logged yet.';

  @override
  String get historyDeleteTitle => 'Delete this session?';

  @override
  String historyDeleteBody(String name, String date) {
    return '$name · $date\nYour Index will be recalculated.';
  }

  @override
  String get endgameTitle => 'Grand Slam';

  @override
  String get endgameFlagshipTitle => 'The 4 flagship sessions';

  @override
  String get endgameFlagshipSubtitle =>
      'Tap a session to see what it involves and take it on.';

  @override
  String get endgameTierBronze => '🥉 Bronze';

  @override
  String get endgameTierBronzeDesc => 'Complete the 4 flagship sessions.';

  @override
  String get endgameTierSilver => '🥈 Silver';

  @override
  String endgameTierSilverDesc(int min) {
    return 'All 4 with a score ≥ $min/100 — hard but reachable (~1 year of practice).';
  }

  @override
  String get endgameTierGold => '🥇 Gold';

  @override
  String endgameTierGoldDesc(int min) {
    return 'All 4 with a score ≥ $min/100 — extremely demanding (~5 years).';
  }

  @override
  String get endgameGlobalRank => 'Athlete League rank';

  @override
  String get endgameTop100 => 'Athlete League Top 100 🏆';

  @override
  String get endgameHeroBronze => 'Bronze Grand Slam';

  @override
  String get endgameHeroSilver => 'Silver Grand Slam';

  @override
  String get endgameHeroGold => 'Gold Grand Slam';

  @override
  String get endgameHeroLocked => 'Grand Slam — not unlocked';

  @override
  String endgameFlagshipDone(int completed, int total) {
    return '$completed/$total flagship sessions completed';
  }

  @override
  String challengeBannerLabel(String theme) {
    return 'CHALLENGE OF THE WEEK · $theme';
  }

  @override
  String get challengeEnded => 'Ended';

  @override
  String challengeCountdownDays(int days, int hours) {
    return '${days}d ${hours}h left';
  }

  @override
  String challengeCountdownHours(int hours, int minutes) {
    return '${hours}h ${minutes}min left';
  }

  @override
  String get challengeTitle => 'Challenge of the week';

  @override
  String get challengeDoIt => 'Take the challenge 🔥';

  @override
  String get challengeDetails => 'Tiers, pro references & details';

  @override
  String get challengeLeaderboard => 'Challenge leaderboard';

  @override
  String get challengeHeroTagline =>
      'Everyone is measured on this session this week. Give it everything 💪';

  @override
  String get challengeWhatToDo => 'What to do';

  @override
  String get challengeBeFirst =>
      'Be the first to take the challenge this week 🔥';

  @override
  String challengeYouSuffix(String name) {
    return '$name (you)';
  }

  @override
  String get progressionTitle => 'Progress';

  @override
  String get progressionHistoryButton => 'My session history';

  @override
  String get progressionEndgameButton => 'Endgame — Grand Slam & global rank';

  @override
  String progressionBadges(int unlocked, int total) {
    return 'Badges ($unlocked/$total unlocked)';
  }

  @override
  String get progressionBadgesHint =>
      'For each series, your current tier and the next one to aim for.';

  @override
  String get coachTitle => 'Coach';

  @override
  String get coachWhichAxis => 'Which axis to improve?';

  @override
  String get coachWeakPoint => 'My weak point';

  @override
  String get coachLoadError => 'Couldn\'t load tips right now.';

  @override
  String coachProgressOn(String attribute) {
    return 'Do these sessions to improve on $attribute';
  }

  @override
  String get coachTargetedSessions => 'TARGETED SESSIONS';

  @override
  String get coachNoSessions => 'No session for this axis with your equipment.';

  @override
  String get coachLogSession => 'Do a scored session & log my time';

  @override
  String coachDurationMin(int min) {
    return '$min min';
  }

  @override
  String get coachLibraryTitle => 'Coach library';

  @override
  String get coachLibrarySubtitle =>
      'Ready-to-run guided sessions. Pick one and follow the plan.';

  @override
  String get coachLibraryAll => 'All';

  @override
  String get coachLibraryError =>
      'Couldn\'t load the session library right now.';

  @override
  String get coachLibraryEmpty =>
      'No guided session for this filter with your equipment.';

  @override
  String get coachLibraryEntryTitle => 'Coach library';

  @override
  String get coachLibraryEntrySubtitle =>
      'Guided sessions to follow — separate from the workouts you log.';

  @override
  String get sessionsByFocusCaption =>
      'Workouts to log that measure each axis of your score.';

  @override
  String get sessionsToLog => 'Workouts to log';

  @override
  String get sessionsGuidedLinkTitle => 'Guided coach sessions';

  @override
  String get sessionsGuidedLinkSubtitle =>
      'Ready-to-run training for this axis';

  @override
  String get coachWithEquipment => 'Equipment';

  @override
  String get coachNoEquipment => 'No equipment';

  @override
  String get coachIntensityHigh => 'Intense';

  @override
  String get coachIntensityMedium => 'Moderate';

  @override
  String get coachIntensityLow => 'Light';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeGreetingNoName => 'Hi 👋';

  @override
  String get homeNotifications => 'Notifications';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeProfileUnavailable => 'Profile unavailable.';

  @override
  String get homeNoIndexTitle => 'Your Athlete Index isn\'t revealed yet';

  @override
  String get homeNoIndexBody =>
      'Do a workout and log your result to reveal your Index and unlock your radar.';

  @override
  String get homeNoIndexCta => 'Do a workout';

  @override
  String get homeSectionLeague => 'YOUR LEAGUE';

  @override
  String get homeSectionProgress => 'YOUR PROGRESS';

  @override
  String get homeRadarTitle => 'YOUR RADAR';

  @override
  String get homeRadarHint =>
      'Tap a quality to see the sessions that boost it.';

  @override
  String get homeCoachCta => 'Coach — improve an axis';

  @override
  String get homeHistory => 'My history';

  @override
  String get homeShareCard => 'Share my card';

  @override
  String get homeFreshnessTitleOne => 'One axis to refresh';

  @override
  String get homeFreshnessTitleMany => 'Some axes to refresh';

  @override
  String homeFreshnessBody(String names) {
    return '$names: your measure is a bit old. A re-test could push it up.';
  }

  @override
  String get homeAddSessionTitle => 'Add a session';

  @override
  String get homeAddQuickTitle => 'Quick session';

  @override
  String get homeAddQuickSubtitle => 'A reference session';

  @override
  String get homeBuildSessionTitle => 'Build a session';

  @override
  String get homeBuildSessionSubtitle =>
      'Compose your own session, automatically estimated';

  @override
  String get gradeSummitReached => 'Summit reached — 100';

  @override
  String gradeObjective(Object next) {
    return 'Goal: $next';
  }

  @override
  String get gradeAlmostReal => 'Almost your real Index';

  @override
  String get gradeEstimated => 'Estimated Index';

  @override
  String gradeEstimationLoading(Object coverage) {
    return 'Estimated on $coverage/6 attributes…';
  }

  @override
  String gradeEstimationError(Object coverage) {
    return 'Estimated on $coverage/6 attributes. Complete your radar to reveal your real Index.';
  }

  @override
  String get gradeKeepLogging =>
      'Keep logging sessions to finalize your Index.';

  @override
  String get gradeCompletePrefix => 'Complete ';

  @override
  String get gradeCompleteSessionOne => 'this session';

  @override
  String gradeCompleteSessionMany(Object n) {
    return 'these $n sessions';
  }

  @override
  String get gradeCompleteSuffix => ' to reveal your real Index:';

  @override
  String get gradeCompleteOptional =>
      'Not required: your real Index can also be revealed by logging other sessions of your choice.';

  @override
  String gradeUnlocks(String covers) {
    return 'Unlocks: $covers';
  }

  @override
  String gradeClimbTo(String next) {
    return 'Keep logging your sessions to climb toward $next.';
  }

  @override
  String get gradeWorkPrefix => 'Work on your ';

  @override
  String get gradeWorkMiddle => ' to aim for ';

  @override
  String get gradeWorkSuffix => '.';

  @override
  String get rivalChasing => 'YOU\'RE CHASING';

  @override
  String get rivalGapOne => 'Just 1 point to catch up 👊';

  @override
  String rivalGapMany(Object gap) {
    return '$gap points to catch up 👊';
  }

  @override
  String get rivalLeaderLabel => 'LEADER OF YOUR LEAGUE';

  @override
  String get rivalLeaderTitle => 'You\'re on top 👑';

  @override
  String get rivalLeaderBody => 'Defend your spot — beat your own record.';

  @override
  String get recapWeekLabel => 'YOUR WEEK';

  @override
  String get recapValidated => 'validated ✅';

  @override
  String get recapSessionsSingular => 'session';

  @override
  String get recapSessionsPlural => 'sessions';

  @override
  String get recapIndexPoints => 'Index points';

  @override
  String get recapWeeksSingular => 'week 🔥';

  @override
  String get recapWeeksPlural => 'weeks 🔥';

  @override
  String recapMessageGain(Object delta) {
    return 'Great week — your work pays off, +$delta on your Index.';
  }

  @override
  String get recapMessageKeepGoing => 'Well done, keep up the momentum.';

  @override
  String get recapMessageStart => 'One session is enough to kick off the week.';

  @override
  String streakDetailValidated(Object current) {
    return 'Week validated ✅ — streak of $current';
  }

  @override
  String streakDetailSeries(Object current) {
    return 'Streak of $current weeks';
  }

  @override
  String streakDetailLeft(num left) {
    final intl.NumberFormat leftNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String leftString = leftNumberFormat.format(left);

    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: '$leftString more sessions to validate your week',
      one: '$leftString more session to validate your week',
    );
    return '$_temp0';
  }

  @override
  String get streakSheetTitle => 'Your streak';

  @override
  String streakSheetActive(num current, Object goal) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String currentString = currentNumberFormat.format(current);

    String _temp0 = intl.Intl.pluralLogic(
      current,
      locale: localeName,
      other:
          '$currentString active weeks in a row. A week counts from $goal sessions.',
      one:
          '$currentString active week in a row. A week counts from $goal sessions.',
    );
    return '$_temp0';
  }

  @override
  String streakSheetStart(Object goal) {
    return 'Do $goal sessions this week to start your streak.';
  }

  @override
  String get streakThisWeek => 'This week';

  @override
  String get streakBest => 'Best';

  @override
  String streakBestValue(Object best) {
    return '$best wk';
  }

  @override
  String get streakFreezeTokens => 'Rest tokens';

  @override
  String get streakFreezeHint => 'Protect a missed week.';

  @override
  String get streakNoPressure =>
      'No pressure: missing a week never lowers your Index.';

  @override
  String get socialProofBases =>
      'You\'re laying your foundations — each session brings you closer to the top of the ranking.';

  @override
  String get socialProofElite =>
      '🔥 You\'re in the elite — right at the top of the best performers.';

  @override
  String get socialProofTopPrefix => 'You\'re among the ';

  @override
  String get socialProofTopSuffix => ' fittest humans';

  @override
  String get socialProofAppPrefix => 'Top ';

  @override
  String get socialProofAppSuffix => ' of HYBRID athletes';

  @override
  String socialProofA11yHumanityApp(Object humanity, Object app) {
    return 'Social proof. $humanity $app';
  }

  @override
  String socialProofA11yHumanity(Object humanity) {
    return 'Social proof. $humanity';
  }

  @override
  String recapA11y(int sessions, int delta, int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions sessions',
      one: '$sessions session',
    );
    String _temp1 = intl.Intl.pluralLogic(
      delta,
      locale: localeName,
      other: 'plus $delta Index',
      one: 'plus $delta Index',
      zero: 'no Index gain',
    );
    String _temp2 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak weeks streak',
      one: '$streak week streak',
    );
    return 'Your week: $_temp0, $_temp1, $_temp2.';
  }

  @override
  String gradeA11y(Object title, int coverage, int sessions) {
    String _temp0 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other:
          'Complete $sessions recommended sessions to reveal your real Index.',
      one: 'Complete $sessions recommended session to reveal your real Index.',
      zero: 'Keep logging sessions.',
    );
    return '$title, based on $coverage/6 attributes. $_temp0';
  }

  @override
  String gradeSessionA11y(Object name, Object covers) {
    return 'Recommended session: $name. Unlocks $covers. Tap to open the details.';
  }

  @override
  String get revealYourIndex => 'YOUR ATHLETE INDEX';

  @override
  String get revealDoProfilExpress => 'Do the Express Profile';

  @override
  String get revealEstimateTitle => 'This is an estimate';

  @override
  String revealEstimateBody(int coverage) {
    return 'Your starting Index is based on $coverage/6 attributes. Log a few more sessions to unlock all 6 and reveal your true Athlete Index.';
  }

  @override
  String get revealRadar => 'YOUR RADAR';

  @override
  String get revealDiscoverProfile => 'Discover my profile';

  @override
  String get revealShareCard => 'Share my card';

  @override
  String get revealComputing => 'Computing your Index…';

  @override
  String get shareCardTitle => 'My card';

  @override
  String get shareCardShareText =>
      'My Athlete Index 💪 What\'s yours? #AthleteIndex';

  @override
  String get shareCardDownloaded => 'Card downloaded 📥';

  @override
  String get shareCardDownloadUnsupported => 'Download not supported here.';

  @override
  String get shareCardNoIndex => 'No Index to share.';

  @override
  String get shareCardTagline => 'Show your level — challenge your friends 🔥';

  @override
  String get shareCardShareCta => 'Share my card';

  @override
  String get shareCardDownload => 'Download';

  @override
  String get shareCardOvr => 'LEVEL';

  @override
  String get shareCardLeague => 'LEAGUE';

  @override
  String shareCardTopPct(Object pct) {
    return '★ TOP $pct %';
  }

  @override
  String get shareCardAthlete => 'Athlete';

  @override
  String shareCardA11y(Object name, Object ovr, Object archetype) {
    return '$name\'s card, Athlete Index $ovr, archetype $archetype';
  }

  @override
  String get shareCardOvrEstimated => 'ESTIMATED LEVEL';

  @override
  String get shareCardEstimatedBadge => 'ESTIMATED';

  @override
  String get shareCardUnderConstruction => 'IN PROGRESS';

  @override
  String get archetypeInProgress => 'PROFILE IN PROGRESS';

  @override
  String shareCardRevealCta(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sessions',
      one: '1 session',
    );
    return '$_temp0 left to reveal your real card';
  }

  @override
  String get shareCardRevealConfirm => 'Log real sessions to lock in your card';

  @override
  String get shareCardRevealedTitle => 'Your card is revealed!';

  @override
  String get shareCardRevealedSubtitle =>
      'Your real Athlete Index is unlocked.';

  @override
  String shareCardA11yUnderConstruction(
      String name, int ovr, int n, int coverage) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sessions left to reveal your real card.',
      one: '1 session left to reveal your real card.',
      zero: 'Log real sessions to lock it in.',
    );
    return '$name\'s card in progress. Estimated level $ovr. $_temp0 $coverage of 6 attributes measured.';
  }

  @override
  String get leaderboardTitle => 'League';

  @override
  String get leaderboardWeeklyProgress => 'Weekly progress (by effort)';

  @override
  String get leaderboardMen => 'Men';

  @override
  String get leaderboardWomen => 'Women';

  @override
  String get leaderboardUnavailable => 'Leaderboard unavailable right now.';

  @override
  String get leaderboardRetry => 'Retry';

  @override
  String get leaderboardEmpty => 'No athletes yet.';

  @override
  String leaderboardYou(String name) {
    return '$name  (you)';
  }

  @override
  String get progressBoardTitle => 'Weekly progress';

  @override
  String progressBoardClubTitle(String clubName) {
    return 'Progress · $clubName';
  }

  @override
  String get progressBoardHeader =>
      '🔥 Here we reward the effort of the week — not talent. Every session, every record, every active day moves you up.';

  @override
  String get progressBoardEmpty =>
      'Nobody has moved yet this week. Log a session and take the lead 💪';

  @override
  String progressBoardMyPosition(Object position, Object ep) {
    return 'Your spot this week: #$position · $ep effort pts';
  }

  @override
  String progressBoardPts(Object ep) {
    return '$ep pts';
  }

  @override
  String get archetypeHybrid => 'HYBRID ATHLETE';

  @override
  String get archetypeAllRound => 'ALL-ROUND';

  @override
  String get archetypeEngine => 'ENGINE';

  @override
  String get archetypeStrength => 'STRENGTH';

  @override
  String get archetypePower => 'EXPLOSIVE';

  @override
  String get archetypeSpeed => 'SPEED';

  @override
  String get archetypeMuscularEndurance => 'RELENTLESS';

  @override
  String get rfFarBetterTitle1 => 'Outstanding performance';

  @override
  String rfFarBetterBody1(String gain) {
    return 'You beat your prediction by $gain. This isn\'t luck: it\'s your work paying off. Note what you did well today.';
  }

  @override
  String get rfFarBetterTitle2 => 'You blew past the ceiling';

  @override
  String rfFarBetterBody2(String gain) {
    return '$gain above what we expected from you. Your real level just pulled ahead of the model. Keep doing exactly this.';
  }

  @override
  String get rfFarBetterTitle3 => 'Well above target';

  @override
  String rfFarBetterBody3(String gain) {
    return 'Prediction smashed by $gain. A session like this is concrete proof that your preparation pays off.';
  }

  @override
  String get rfBetterTitle1 => 'Above target';

  @override
  String rfBetterBody1(String gain) {
    return '$gain better than your prediction. You\'re progressing in the right direction, and it shows.';
  }

  @override
  String get rfBetterTitle2 => 'Solid. You\'re taking the lead';

  @override
  String rfBetterBody2(String gain) {
    return 'You beat what was expected by $gain. Keep this pace — that\'s exactly how you climb.';
  }

  @override
  String get rfBetterTitle3 => 'Better than expected';

  @override
  String rfBetterBody3(String gain) {
    return '+$gain over the prediction. Small gap, real progress: build on it next session.';
  }

  @override
  String get rfOnTargetTitle1 => 'Right on target';

  @override
  String rfOnTargetBody1(String metric) {
    return 'You hit exactly the $metric predicted for you. Reaching your target is already a win: your level and your performance are aligned.';
  }

  @override
  String get rfOnTargetTitle2 => 'Goal reached';

  @override
  String get rfOnTargetBody2 =>
      'You matched the prediction to the letter. That\'s controlled consistency — the foundation of all real progress.';

  @override
  String get rfOnTargetTitle3 => 'Bullseye';

  @override
  String get rfOnTargetBody3 =>
      'You delivered the performance expected for your level. Solid and reliable: now aim one notch higher.';

  @override
  String get rfBelowTitle1 => 'Session in the books';

  @override
  String get rfBelowBody1 =>
      'A bit below your target today, but you finished it — and that\'s what counts. We know you can do better: the next one will be stronger.';

  @override
  String get rfBelowTitle2 => 'Well done, it\'s logged';

  @override
  String rfBelowBody2(String wodName) {
    return 'Not your best day on $wodName, but every rep counts toward your progress. You\'ve got the room to climb back above.';
  }

  @override
  String get rfBelowTitle3 => 'You did the work';

  @override
  String get rfBelowBody3 =>
      'Result a little under your prediction, but what matters is that you showed up. We\'re sure you can do better next time.';

  @override
  String get rfWayBelowTitle1 => 'Bad day, it happens';

  @override
  String rfWayBelowBody1(String wodName) {
    return 'Far from your usual level today — and that\'s okay. The body has its off days. Rest up, and come back to retry $wodName fresh: you\'re worth far more than this.';
  }

  @override
  String get rfWayBelowTitle2 => 'It wasn\'t your day';

  @override
  String rfWayBelowBody2(String wodName) {
    return 'This performance doesn\'t reflect what you\'re capable of. Fatigue, sleep, a busy day: it all counts. Come back to $wodName when you\'re at your best.';
  }

  @override
  String get rfWayBelowTitle3 => 'Let\'s file this session away';

  @override
  String rfWayBelowBody3(String wodName) {
    return 'Just an off day. Finishing it anyway already takes mental strength. Recover well and retry $wodName rested — you\'ll do far better.';
  }

  @override
  String get rfNoPredictionTitle1 => 'Result saved';

  @override
  String get rfNoPredictionBody1 =>
      'Nice session, it\'s in the books. Every saved result grows your Athlete Index — keep it up.';

  @override
  String get rfNoPredictionTitle2 => 'Logged, keep going';

  @override
  String get rfNoPredictionBody2 =>
      'Every saved result brings your full Index closer and fills out your attribute radar.';

  @override
  String get rfMetricTime => 'time';

  @override
  String get rfMetricScore => 'score';

  @override
  String get commonOk => 'OK';

  @override
  String get leagueScreenTitle => 'League of the month';

  @override
  String get leagueRivalTitle => 'Your rival in the league';

  @override
  String get leagueUnavailable => 'League unavailable right now.';

  @override
  String get leagueRetry => 'Retry';

  @override
  String get leagueNoSeason =>
      'No League season in progress.\nCheck back soon: a new season starts every month.';

  @override
  String get leagueHeaderMen => 'MEN\'S LEAGUE';

  @override
  String get leagueHeaderWomen => 'WOMEN\'S LEAGUE';

  @override
  String get leagueLastDay => 'Last day of the season';

  @override
  String leagueEndsIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Ends in $days days',
      one: 'Ends in $days day',
    );
    return '$_temp0';
  }

  @override
  String get leaguePointsReset => 'Points reset to zero every month.';

  @override
  String get leagueExplainerTitle => 'What is the League of the month?';

  @override
  String get leagueExplainerBody =>
      'Every month, a new season. You\'re ranked AUTOMATICALLY among athletes of your sex. Do the imposed workout of the week: you score points based on your performance. League points reset to zero every month.';

  @override
  String get leagueWeekWod => 'WORKOUT OF THE WEEK';

  @override
  String get leagueWeekWodHint =>
      'The imposed workout of the week — give it everything to climb the ranking.';

  @override
  String get leagueDoThisWod => 'Do this workout';

  @override
  String get leagueStandingsUnavailable => 'Ranking unavailable.';

  @override
  String get leagueStandingsTitle => 'Ranking of the month';

  @override
  String get leagueStandingsEmpty =>
      'Nobody has scored yet this month. Be the first!';

  @override
  String get leagueMyPosition => 'MY POSITION';

  @override
  String leaguePts(int points) {
    return '$points pts';
  }

  @override
  String get leagueDoWodToEnter => 'Do the workout to enter the ranking';

  @override
  String get leagueThisMonth => 'this month';

  @override
  String leagueRowYou(String name) {
    return '$name (me)';
  }

  @override
  String get leagueSegmentMen => 'Men';

  @override
  String get leagueSegmentWomen => 'Women';

  @override
  String get leagueHowItWorksTitle => 'How does it work?';

  @override
  String get leagueHowItWorksBest =>
      'Only your BEST attempt of the week counts — you can retry as many times as you want, only the best one is kept.';

  @override
  String get leagueHowItWorksReset =>
      'Points reset to zero at the start of every month. Everyone restarts equal.';

  @override
  String get leagueHowItWorksIndex =>
      'Your performances on the League workouts also count toward your Athlete Index. Only the League POINTS reset to zero every month.';

  @override
  String leagueWodCountdownDaysHours(int days, int hours) {
    return '${days}d ${hours}h left to do it';
  }

  @override
  String leagueWodCountdownHours(int hours) {
    return '${hours}h left to do it';
  }

  @override
  String get leagueWodCountdownLastHour => 'Last hour to do it!';

  @override
  String get leagueWodCountdownExpired => 'Workout of the week over';

  @override
  String leagueRevealTitle(String month) {
    return 'Season $month — results';
  }

  @override
  String get leagueRevealPodium => 'PODIUM';

  @override
  String leagueRevealYouFinished(String rank) {
    return 'You finished $rank';
  }

  @override
  String leagueRevealRankOrdinal(String ordinal) {
    return '$ordinal';
  }

  @override
  String get leagueRevealNotRanked => 'You weren\'t ranked this season.';

  @override
  String get leagueRevealNewSeason => 'A new season has begun — go for it!';

  @override
  String get leagueRevealClose => 'Let\'s go';

  @override
  String get leagueRevealMovedUp => 'You climbed the ranking';

  @override
  String get leagueRevealMovedDown => 'You slipped down the ranking';

  @override
  String get leagueRevealStable => 'You held your position';

  @override
  String notificationsJoinedClub(String clubName) {
    return 'You joined $clubName!';
  }

  @override
  String get notificationsClubInviteTitle => 'Club invitation';

  @override
  String notificationsClubInviteMembers(String clubName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$clubName · $_temp0';
  }

  @override
  String get notificationsJoin => 'Join';

  @override
  String get notificationsDecline => 'Decline';

  @override
  String get a11ySend => 'Send message';

  @override
  String get a11yRetryMessage => 'Resend message';

  @override
  String a11yUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String get a11yDecrease => 'Decrease';

  @override
  String get a11yIncrease => 'Increase';

  @override
  String a11yDailyCapValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications per day',
      one: '$count notification per day',
    );
    return '$_temp0';
  }

  @override
  String a11yLeagueMyPosition(int position, int points) {
    return 'You are $position with $points points';
  }

  @override
  String a11yLeagueRow(int position, String name, int points) {
    return 'Position $position, $name, $points points';
  }

  @override
  String a11yPodiumPlace(String ordinal, String name, int points) {
    return '$ordinal place: $name, $points points';
  }

  @override
  String a11yRemoveMovementNamed(String name) {
    return 'Remove $name';
  }

  @override
  String a11yAmountField(String movement, String unit) {
    return 'Amount for $movement in $unit';
  }

  @override
  String a11yLoadField(String movement) {
    return 'Load in kilograms for $movement';
  }

  @override
  String get a11yEstimateBadge => 'Estimated values, indicative';

  @override
  String a11yFlagshipDone(String name, int score) {
    return '$name, done, score $score out of 100';
  }

  @override
  String a11yFlagshipTodo(String name) {
    return '$name, to do';
  }

  @override
  String get a11yUnlocked => 'unlocked';

  @override
  String get a11yLocked => 'locked';

  @override
  String a11yBadge(String name) {
    return 'Badge $name';
  }

  @override
  String get a11yHomeViewProgression => 'View your progress';

  @override
  String get a11yHomeEditAvatar => 'Edit your avatar';

  @override
  String get a11yHomeBetaInfo => 'Beta version info';

  @override
  String a11yRivalChasing(String name, int ovr, int gap) {
    String _temp0 = intl.Intl.pluralLogic(
      gap,
      locale: localeName,
      other: '$gap points above you',
      one: '1 point above you',
    );
    return 'Your rival $name, Index $ovr, $_temp0. Tap to view the leaderboard.';
  }

  @override
  String get a11yRivalLeader =>
      'You\'re leading your league. Tap to view the leaderboard.';

  @override
  String a11yCoachFilter(String name) {
    return 'Filter: $name';
  }

  @override
  String a11yCoachSession(String name, int duration, String intensity) {
    return 'Session $name, $duration minutes, intensity $intensity';
  }

  @override
  String a11ySessionWod(String name) {
    return 'Challenge $name';
  }

  @override
  String get guidedTimerStart => 'Start';

  @override
  String get guidedTimerPause => 'Pause';

  @override
  String get guidedTimerResume => 'Resume';

  @override
  String get guidedTimerReset => 'Reset';

  @override
  String get guidedTimerFinish => 'Finish';

  @override
  String get guidedTimerDone => 'Done!';

  @override
  String get guidedTimerClose => 'Close timer';

  @override
  String get guidedTimerCountdownLabel => 'COUNTDOWN';

  @override
  String get guidedTimerStopwatchLabel => 'STOPWATCH';

  @override
  String a11yGuidedTimerValue(String value) {
    return 'Timer: $value';
  }

  @override
  String get coachSessionGuidedMode => 'Guided mode';

  @override
  String get guidedPhaseWork => 'Work';

  @override
  String get guidedPhaseRest => 'Rest';

  @override
  String get guidedPhasePrepare => 'Get ready';

  @override
  String get guidedStateRunning => 'In progress';

  @override
  String get guidedStatePaused => 'Paused';

  @override
  String guidedRoundOf(int current, int total) {
    return 'Round $current / $total';
  }

  @override
  String guidedMinuteOf(int current, int total) {
    return 'Minute $current / $total';
  }

  @override
  String guidedSetOf(int current, int total) {
    return 'Set $current / $total';
  }

  @override
  String guidedRoundsDone(int count) {
    return 'Rounds: $count';
  }

  @override
  String get guidedAddRound => 'Round +1';

  @override
  String get guidedSetDone => 'Set done';

  @override
  String get guidedSkip => 'Skip';

  @override
  String get guidedStart => 'Start';

  @override
  String get guidedPause => 'Pause';

  @override
  String get guidedResume => 'Resume';

  @override
  String get guidedFinish => 'Finish';

  @override
  String get guidedGo => 'Go!';

  @override
  String get guidedCountdownGo => 'GO';

  @override
  String get guidedDone => 'Workout complete';

  @override
  String get guidedSaveResult => 'Save my time';

  @override
  String guidedTotalTime(String time) {
    return 'Total time $time';
  }

  @override
  String get guidedStreakCredited => 'Streak credited 🔥';

  @override
  String get guidedValidating => 'Saving…';

  @override
  String get guidedCreditFailed => 'Couldn\'t save — retry';

  @override
  String get guidedRetry => 'Retry';

  @override
  String get guidedQuitTitle => 'Quit the workout?';

  @override
  String get guidedQuitBody => 'Your progress for this workout will be lost.';

  @override
  String get guidedQuitConfirm => 'Quit';

  @override
  String get guidedQuitCancel => 'Keep going';

  @override
  String get guidedSoundOn => 'Mute sound';

  @override
  String get guidedSoundOff => 'Unmute sound';

  @override
  String get guidedClose => 'Close';

  @override
  String get a11yGuidedPhaseWork => 'Work';

  @override
  String get a11yGuidedPhaseRest => 'Rest';

  @override
  String get a11yGuidedPhasePrepare => 'Get ready';

  @override
  String a11yGuidedRound(int n) {
    return 'Round $n';
  }

  @override
  String a11yGuidedMinute(int n) {
    return 'Minute $n';
  }

  @override
  String a11yGuidedSet(int n) {
    return 'Set $n';
  }

  @override
  String a11yGuidedCountdown(int n) {
    return '$n';
  }

  @override
  String a11yGuidedTimeValue(String value) {
    return 'Timer: $value';
  }

  @override
  String get coachSessionMarkDone => 'Mark as done';

  @override
  String get coachSessionDoneTitle => 'Session complete';

  @override
  String get coachSessionDoneSubtitle => 'Nice work. Keep your streak alive.';

  @override
  String coachSessionDoneToast(String name) {
    return 'Session “$name” marked as done.';
  }

  @override
  String coachSessionStreakCredited(String name) {
    return 'Session “$name” done — streak credited.';
  }

  @override
  String get coachSessionSyncFailed =>
      'Session saved locally. Couldn’t sync: your streak wasn’t updated. Try again when you’re back online.';

  @override
  String a11yHomePlayerCard(String name, int ovr, String rank) {
    return '$name, Index $ovr, rank $rank. Tap to view your progress.';
  }

  @override
  String get a11yHomeCoachCta => 'Get a training session from the coach';

  @override
  String a11yLeaderboardRow(int position, String name, int ovr) {
    return 'Rank $position, $name, Index $ovr';
  }

  @override
  String a11yLeaderboardRowMe(int position, String name, int ovr) {
    return 'Rank $position, you, $name, Index $ovr';
  }

  @override
  String a11yLeaderboardTab(String name) {
    return '$name league';
  }

  @override
  String a11yRevealResult(int ovr, String rank) {
    return 'Your Index is $ovr, rank $rank';
  }

  @override
  String get a11yRevealComputing => 'Calculating your Index';

  @override
  String a11yOnbStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get a11yOnbContinue => 'Continue to the next step';

  @override
  String get a11yOnbReveal => 'Reveal my Index';

  @override
  String a11yOnbEffortToggle(String name, String state) {
    String _temp0 = intl.Intl.selectLogic(
      state,
      {
        'on': 'enabled',
        'off': 'disabled',
        'other': '',
      },
    );
    return '$name, $_temp0';
  }
}
