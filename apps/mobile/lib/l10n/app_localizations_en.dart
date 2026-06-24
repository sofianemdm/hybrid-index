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
  String homeProjection(int grade, int weeks) {
    return 'At this rate: $grade+ in ~$weeks wk.';
  }

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
  String get onbMaxPullups => 'Max strict pull-ups (one set)';

  @override
  String get onbSquat1rm => 'Squat 1RM (max load, 1 rep)';

  @override
  String get onbSquat1rmHint =>
      'Your heaviest back squat for a single rep, in kilograms.';

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

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

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
      'Major real-world events (HYROX, competition WODs, races). Open one to see the details and records — and log your time.';

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
  String get wodDetailDoThisWorkout => 'Do this workout';

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
  String wodDetailLeaderboardYou(String name) {
    return '$name (you)';
  }

  @override
  String get wodBuilderTitle => 'Build a workout';

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
  String get communityReportSent => 'Thanks, report sent.';

  @override
  String get communityWorkoutFallback => 'a workout';

  @override
  String communityMsgPr(String wodName) {
    return '🏆 New PR — $wodName';
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
    return 'just joined us with a HYBRID INDEX of $index 👋';
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
      'No conversation yet. Message an athlete you follow (and who follows you) or a member of your club.';

  @override
  String get conversationsYouPrefix => 'You: ';

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
  String get notificationSettingsTitle => 'Notification settings';

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
  String get clubDetailRankingTitle => 'Club ranking (Hybrid Index)';

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
  String get endgameGlobalRank => 'Global rank';

  @override
  String get endgameTop100 => 'Global Top 100 🌍';

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
  String get homeNotifications => 'Notifications';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeProfileUnavailable => 'Profile unavailable.';

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
  String get homeAddQuickTitle => 'Add a session quickly';

  @override
  String get homeAddQuickSubtitle => 'Pick a reference session';

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
  String get revealYourIndex => 'YOUR HYBRID INDEX';

  @override
  String get revealDoProfilExpress => 'Do the Express Profile';

  @override
  String get revealEstimateTitle => 'This is an estimate';

  @override
  String revealEstimateBody(int coverage) {
    return 'Your starting Index is based on $coverage/6 attributes. Log a few more sessions to unlock all 6 and reveal your true HYBRID INDEX.';
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
      'My HYBRID INDEX 💪 What\'s yours? #HybridIndex';

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
  String get leaderboardTitle => 'Leaderboard';

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
}
