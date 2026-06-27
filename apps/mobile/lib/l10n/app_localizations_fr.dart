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
  String get navLeaderboard => 'Ligue';

  @override
  String get settingsEquipmentLabel =>
      'Matériel — « Équipé » donne aussi accès au sans-matériel';

  @override
  String get settingsEquipmentNone => 'Sans matériel';

  @override
  String get settingsEquipmentEquipped => 'Équipé (salle de sport)';

  @override
  String get settingsUpdated => 'Profil mis à jour.';

  @override
  String get sessionsTitle => 'Séances';

  @override
  String get sessionsByFocus => 'Séances par axe';

  @override
  String get sessionsWeeklyTitle => 'La séance de la semaine';

  @override
  String get sessionsCountsMost => 'Compte fort';

  @override
  String sessionsAttributeHeader(String attribute) {
    return 'Les épreuves qui comptent pour ton score $attribute';
  }

  @override
  String get leaderboardIntro =>
      'Le classement de tous les athlètes de ta ligue (ton sexe), trié par Athlete Index — normalisé par sexe pour rester équitable. Grimpe en améliorant ton score.';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonGotIt => 'Compris';

  @override
  String get bugReportTitle => 'Signaler un bug';

  @override
  String get bugReportHint =>
      'Décris le problème : ce que tu faisais, ce qui s\'est passé, l\'écran concerné…';

  @override
  String get bugReportSend => 'Envoyer';

  @override
  String get bugReportThanks => 'Merci ! Ton signalement a bien été envoyé. 🙏';

  @override
  String get bugReportTooShort => 'Ajoute quelques mots pour décrire le bug.';

  @override
  String get wodPredictionTitle => 'D\'après ton niveau, tu ferais';

  @override
  String get wodPredictionChallenge =>
      'À toi de jouer : donne tout et bats cette estimation 🔥';

  @override
  String get homeBetaBanner =>
      'Version bêta — un bug ? Touche pour en savoir plus';

  @override
  String get homeBetaTitle => 'Application en version bêta';

  @override
  String get homeBetaBody =>
      'Elle évolue vite : il peut encore y avoir des bugs, des incohérences ou des données imparfaites. Signale-nous tout ce qui cloche pour qu\'on le corrige au plus vite — chaque retour compte. 🙏';

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
  String homeProjection(int grade, int weeks) {
    return 'À ce rythme : $grade+ dans ~$weeks sem.';
  }

  @override
  String get commonContinue => 'Continuer';

  @override
  String get wreSecondsRange => 'Les secondes doivent être entre 0 et 59.';

  @override
  String get wreInvalidResult => 'Saisis un résultat valide.';

  @override
  String get wreNeedDistance => 'Saisis la distance parcourue (en mètres).';

  @override
  String get wreIndexClimbs => 'Ton Athlete Index grimpe.';

  @override
  String get wreShareFeat => 'Partager mon exploit';

  @override
  String get wreProgressTitle => 'Tu progresses 💪';

  @override
  String get wreOutOfBounds => 'Résultat hors des bornes plausibles.';

  @override
  String get wreYourTime => 'Ton temps';

  @override
  String wreYourResult(String unit) {
    return 'Ton résultat ($unit)';
  }

  @override
  String get wreUnitTime => 'temps';

  @override
  String get wreDistanceLabel => 'Distance parcourue (mètres)';

  @override
  String get wreDistanceHint => 'ex. 5000';

  @override
  String get wreResultHint => 'résultat';

  @override
  String get wreCategory => 'Catégorie';

  @override
  String get wreScale => 'Échelle';

  @override
  String get wrePro => 'Pro';

  @override
  String get wreRx => 'Rx (prescrit)';

  @override
  String get wreOpen => 'Open';

  @override
  String get wreScaled => 'Scaled (adapté)';

  @override
  String get wreSeparatedPro => 'Les classements Pro et Open sont séparés.';

  @override
  String get wreSeparatedRx => 'Les classements Rx et Scaled sont séparés.';

  @override
  String get wreSave => 'Enregistrer';

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
  String get onbMaxPullups => 'Max tractions strictes (une série)';

  @override
  String get onbSquat1rm => 'Squat 1RM (charge max, 1 rép)';

  @override
  String get onbSquat1rmHint =>
      'Ta charge la plus lourde en squat sur une seule répétition, en kilos.';

  @override
  String get onbRevealCta => 'Révéler mon Athlete Index';

  @override
  String get onbRunTitle => 'Course (saisis ta distance)';

  @override
  String get onbRunHint =>
      'Ex. 3 km en 15:00. On calcule ton allure et on l’ajuste à toutes les distances.';

  @override
  String get onbEstimatedIndexHere => 'Ton Index estimé s’affichera ici.';

  @override
  String get onbEstimatedIndexLabel => 'INDEX ESTIMÉ';

  @override
  String get onbNeedEffort => 'Ajoute une course, des pompes ou des squats.';

  @override
  String get onbRunNeedsBoth =>
      'Distance (0,4–42 km) et temps requis pour la course.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get settingsCustomizeAvatar => 'Personnaliser mon avatar';

  @override
  String get settingsPrivacy => 'Données & confidentialité (RGPD)';

  @override
  String get settingsExport => 'Exporter mes données';

  @override
  String get settingsDeleteAccount => 'Supprimer mon compte';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get deleteAccountTitle => 'Supprimer le compte ?';

  @override
  String get deleteAccountBody =>
      'Cette action est définitive : toutes tes données seront effacées.';

  @override
  String get wodTabTitle => 'Séances';

  @override
  String get wodTabSubtitle =>
      'Choisis une séance, vois les records et où tu te situes.';

  @override
  String get wodTabFlagshipSection => '⭐ Séances phares';

  @override
  String get wodTabFlagshipCaption =>
      'Les 4 grands défis où tout le monde se mesure.';

  @override
  String get wodTabNoEquipment => 'Sans matériel';

  @override
  String get wodTabWithEquipment => 'Avec matériel';

  @override
  String get wodTabOtherTitle => 'Autre';

  @override
  String get wodTabOtherSubtitle =>
      'Épreuves réelles (HYROX, compétitions CrossFit, courses), avec les vrais temps des pros.';

  @override
  String get wodTabMyHistory => 'Mon historique de séance';

  @override
  String get otherWorkoutsTitle => 'Autres épreuves';

  @override
  String get otherWorkoutsIntro =>
      'De grandes épreuves réelles (HYROX, séances de compétition, courses). Ouvre-en une pour voir les détails et les records — et enregistre ton temps.';

  @override
  String get otherWorkoutsNoEquipment => 'Sans matériel';

  @override
  String get otherWorkoutsWithEquipment => 'Avec matériel';

  @override
  String get otherWorkoutsCommunitySection => 'Séances de la communauté';

  @override
  String get otherWorkoutsCommunityEmpty =>
      'Aucune séance créée par les utilisateurs pour l\'instant. Crée la tienne via « Construire une séance ».';

  @override
  String get logWodTitle => 'Choisir une séance';

  @override
  String get logWodIntro =>
      'Choisis une séance pour voir en quoi elle consiste, les temps de référence et le classement — puis enregistre ton résultat.';

  @override
  String get logWodNoEquipment => 'Sans matériel';

  @override
  String get logWodWithEquipment => 'Avec matériel';

  @override
  String get wodDetailReferenceTimes => 'Temps de référence';

  @override
  String get wodDetailReferenceTimesCaption =>
      'Débutant · intermédiaire · champion, selon le sexe';

  @override
  String get wodDetailNoTiers => 'Paliers non disponibles pour cette séance.';

  @override
  String get wodDetailLeaderboard => 'Classement';

  @override
  String get wodDetailDoThisWorkout => 'Faire cette séance';

  @override
  String get wodDetailMen => 'Hommes';

  @override
  String get wodDetailWomen => 'Femmes';

  @override
  String get wodDetailTierChampion => '🏆 Champion (élite)';

  @override
  String get wodDetailTierIntermediate => 'Intermédiaire';

  @override
  String get wodDetailTierBeginner => 'Débutant';

  @override
  String get wodDetailYou => 'Toi : ';

  @override
  String wodDetailPoints(int n) {
    return '$n pts';
  }

  @override
  String wodDetailMinutes(int n) {
    return '$n min';
  }

  @override
  String get wodDetailChallenge => 'Le défi';

  @override
  String wodDetailCap(String cap) {
    return 'Cap $cap';
  }

  @override
  String get wodDetailLoads => 'CHARGES';

  @override
  String get wodDetailRx => 'RX : ';

  @override
  String get wodDetailLight => 'Léger : ';

  @override
  String get wodDetailScopeAll => '🌍 Tous';

  @override
  String get wodDetailMyClub => 'Mon club';

  @override
  String get wodDetailWorldRecord => '🌍 World record';

  @override
  String get wodDetailElite => '⭐ Élite';

  @override
  String get wodDetailMyPerformances => 'Mes prestations';

  @override
  String get wodDetailLeaderboardEmpty =>
      'Sois le premier à poster un résultat 💪';

  @override
  String get wodDetailVariantRx => 'Rx';

  @override
  String get wodDetailVariantScaled => 'Allégé';

  @override
  String get wodDetailYouShort => 'Toi';

  @override
  String wodDetailLeaderboardYou(String name) {
    return '$name (toi)';
  }

  @override
  String get wodBuilderTitle => 'Construire une séance';

  @override
  String get wodBuilderFormat => 'Format';

  @override
  String get wodBuilderRoundsLabel => 'Nombre de tours : ';

  @override
  String get wodBuilderRoundsHint => 'ex. 3';

  @override
  String get wodBuilderRoundsCaption => '(les mouvements se répètent N fois)';

  @override
  String get wodBuilderTimeNote =>
      'Pas de temps à saisir ici : le score est le chrono que tu mettras à finir, tu l\'enregistreras en faisant la séance.';

  @override
  String get wodBuilderCapLabel => 'Plafond (min) : ';

  @override
  String get wodBuilderCapHint => 'ex. 12';

  @override
  String get wodBuilderRequiresEquipment => 'Nécessite du matériel';

  @override
  String get wodBuilderMovements => 'Mouvements';

  @override
  String get wodBuilderAddMovement => 'Ajouter un mouvement';

  @override
  String get wodBuilderPublish => 'Publier cette séance';

  @override
  String get wodBuilderAddMovementError => 'Ajoute au moins un mouvement.';

  @override
  String get wodBuilderCustomWorkout => 'Séance personnalisée';

  @override
  String get wodBuilderWorkout => 'Séance';

  @override
  String get wodBuilderAssignedName => 'Nom attribué';

  @override
  String get wodBuilderEstimateEmpty =>
      'Ajoute des mouvements pour voir l\'estimation.';

  @override
  String get wodBuilderEstimate => 'Estimation';

  @override
  String get wodBuilderEstimated => '≈ estimé';

  @override
  String wodBuilderEstimateChampion(String result) {
    return '🏆 Champion : $result';
  }

  @override
  String wodBuilderEstimateIntermediate(String result) {
    return 'Intermédiaire : $result';
  }

  @override
  String wodBuilderEstimateBeginner(String result) {
    return 'Débutant : $result';
  }

  @override
  String get wodBuilderSearchMovement => 'Rechercher un mouvement';

  @override
  String get communityTitle => 'Communauté';

  @override
  String get communityEmpty =>
      'Suis des athlètes pour voir leur activité, ou logue une séance pour démarrer ton fil.';

  @override
  String get communityPublish => 'Publier';

  @override
  String get communityExploreClubs => 'Explorer les clubs';

  @override
  String get communityTooltipMessages => 'Messages';

  @override
  String get communityTooltipPublish => 'Publier';

  @override
  String get communityTooltipClubs => 'Clubs';

  @override
  String get communityTooltipSearch => 'Rechercher';

  @override
  String get communityPostDelete => 'Supprimer';

  @override
  String get communityPostReport => 'Signaler';

  @override
  String get communityReportSent => 'Merci, signalement envoyé.';

  @override
  String get communityWorkoutFallback => 'une séance';

  @override
  String communityMsgPr(String wodName) {
    return '🏆 Nouveau PR — $wodName';
  }

  @override
  String communityMsgWodLogged(String wodName) {
    return 'a fait $wodName';
  }

  @override
  String communityMsgRankUp(String rank) {
    return 'monte au rang $rank 🎖️';
  }

  @override
  String communityMsgBadge(String name) {
    return 'badge débloqué : $name';
  }

  @override
  String communityMsgMemberJoined(String index) {
    return 'vient de nous rejoindre avec un Athlete Index de $index 👋';
  }

  @override
  String communityMsgPostPerf(String wodName) {
    return '💪 a partagé sa perf — $wodName';
  }

  @override
  String get communityMsgDefault => 'nouvelle activité';

  @override
  String get exploreTitle => 'Athlètes';

  @override
  String get exploreSearchHint => 'Rechercher un pseudo';

  @override
  String get exploreFilterAll => 'Tous';

  @override
  String get exploreFilterMen => 'Hommes';

  @override
  String get exploreFilterWomen => 'Femmes';

  @override
  String get exploreEmpty => 'Aucun athlète.';

  @override
  String get composerTitle => 'Publier';

  @override
  String get composerPickPerf => 'Choisis une perf à partager.';

  @override
  String get composerWriteMessage => 'Écris un message.';

  @override
  String get composerModeMessage => '💬 Message';

  @override
  String get composerModePerf => '💪 Partager une perf';

  @override
  String get composerCaptionLabel => 'Légende (option)';

  @override
  String get composerHintPerf => 'Un mot sur cette perf…';

  @override
  String get composerHintText => 'Quoi de neuf, athlète ?';

  @override
  String get composerPublish => 'Publier';

  @override
  String get composerNoResults =>
      'Logue d\'abord une séance pour pouvoir partager une perf.';

  @override
  String get composerPickPerfLabel => 'Choisis la perf à partager';

  @override
  String chatStartConversation(String name) {
    return 'Démarre la conversation avec $name 👋';
  }

  @override
  String get chatHint => 'Écris un message…';

  @override
  String get conversationsTitle => 'Messages';

  @override
  String get conversationsEmpty =>
      'Aucune conversation. Écris à un athlète que tu suis (et qui te suit) ou à un membre de ton club.';

  @override
  String get conversationsYouPrefix => 'Toi : ';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSettingsTooltip => 'Réglages';

  @override
  String get notificationsEmpty =>
      'Rien de neuf pour l’instant. Logue une séance pour faire bouger les choses !';

  @override
  String notificationsNewMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux messages',
      one: '1 nouveau message',
    );
    return '$_temp0';
  }

  @override
  String get notificationsNewMessagesBody => 'Ouvre tes conversations.';

  @override
  String get notificationSettingsTitle => 'Réglages des notifications';

  @override
  String get notificationSettingsComingSoon =>
      'Les notifications push arrivent bientôt. Tes préférences ci-dessous seront prises en compte dès leur activation.';

  @override
  String get notificationSettingsSaved => 'Préférences enregistrées.';

  @override
  String get notificationSettingsQuietHours => 'Heures de silence';

  @override
  String get notificationSettingsStart => 'Début';

  @override
  String get notificationSettingsEnd => 'Fin';

  @override
  String get notificationSettingsDailyCap => 'Maximum par jour';

  @override
  String get notificationSettingsTypes => 'Types de notifications';

  @override
  String get notificationSettingsSave => 'Enregistrer';

  @override
  String get clubsTitle => 'Clubs';

  @override
  String get clubsCreateTitle => 'Créer un club';

  @override
  String get clubsNameLabel => 'Nom du club';

  @override
  String get clubsDescriptionLabel => 'Description (option)';

  @override
  String get clubsCancel => 'Annuler';

  @override
  String get clubsCreate => 'Créer';

  @override
  String get clubsSearchHint => 'Rechercher un club à rejoindre';

  @override
  String get clubsInvitations => 'Invitations';

  @override
  String get clubsMine => 'Mes clubs';

  @override
  String get clubsDiscover => 'Tous les clubs';

  @override
  String get clubsEmpty =>
      'Tu n\'es dans aucun club. Crée le tien ou rejoins-en un 👥';

  @override
  String get clubsView => 'Voir';

  @override
  String clubsMembers(int count) {
    return '$count membres';
  }

  @override
  String clubsMembersOwner(int count) {
    return '$count membres · créateur';
  }

  @override
  String clubsMembersInvite(int count) {
    return '$count membres · t\'invite';
  }

  @override
  String get clubDetailOwnerTitle => 'Tu es le créateur';

  @override
  String get clubDetailLeaveTitle => 'Quitter le club ?';

  @override
  String get clubDetailOwnerMessage =>
      'Transfère d\'abord le club ou attends qu\'il ne reste que toi pour le quitter.';

  @override
  String get clubDetailLeaveMessage =>
      'Tu pourras le rejoindre à nouveau plus tard.';

  @override
  String get clubDetailCancel => 'Annuler';

  @override
  String get clubDetailLeave => 'Quitter';

  @override
  String get clubDetailRankingBySeance => 'Classement du club par séance';

  @override
  String get clubDetailJoin => 'Rejoindre le club';

  @override
  String get clubDetailProgression => 'Progression';

  @override
  String get clubDetailBySeance => 'Par séance';

  @override
  String get clubDetailRankingTitle => 'Classement du club (Athlete Index)';

  @override
  String get clubDetailLeaveButton => 'Quitter le club';

  @override
  String clubDetailMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$_temp0';
  }

  @override
  String clubDetailRosterMe(String name) {
    return '$name (toi)';
  }

  @override
  String get publicProfileFollowing => 'Suivi';

  @override
  String get publicProfileFollow => 'Suivre';

  @override
  String get publicProfileMessage => 'Message';

  @override
  String get publicProfileInviteToClub => 'Inviter dans mon club';

  @override
  String get publicProfileInviteNoClub => 'Crée d\'abord un club pour inviter.';

  @override
  String get publicProfileInviteInto => 'Inviter dans…';

  @override
  String publicProfileInviteSent(String name) {
    return 'Invitation envoyée à « $name »';
  }

  @override
  String publicProfileLeaguePosition(int position) {
    return '#$position de sa ligue';
  }

  @override
  String publicProfileLeaguePositionMine(int position) {
    return '#$position de ta ligue';
  }

  @override
  String get publicProfileNoIndex => 'Pas encore d’Index.';

  @override
  String get publicProfileComparison => 'Comparaison';

  @override
  String get publicProfileTheirRadar => 'Son radar';

  @override
  String get publicProfileYourRadar => 'Ton radar';

  @override
  String publicProfileCompareAhead(int diff, int mine, int other) {
    return '$diff points d\'avance pour toi (toi $mine · $other).';
  }

  @override
  String publicProfileCompareBehind(int diff, int mine, int other) {
    return '$diff points à reprendre (toi $mine · $other).';
  }

  @override
  String get avatarTitle => 'Mon avatar';

  @override
  String get avatarImageTooLarge =>
      'Image trop lourde — choisis-en une plus petite.';

  @override
  String get avatarAddPhoto => 'Mettre une photo';

  @override
  String get avatarChangePhoto => 'Changer la photo';

  @override
  String get avatarRemove => 'Retirer';

  @override
  String get avatarPhotoHidesDrawn =>
      'Avec une photo, l\'avatar dessiné est masqué.';

  @override
  String get avatarSkin => 'Teint';

  @override
  String get avatarHairColor => 'Couleur des cheveux';

  @override
  String get avatarHaircut => 'Coupe';

  @override
  String get avatarBeard => 'Barbe';

  @override
  String get avatarBackground => 'Fond';

  @override
  String get avatarSave => 'Enregistrer mon avatar';

  @override
  String get leagueMen => 'Hommes';

  @override
  String get leagueWomen => 'Femmes';

  @override
  String get historyTitle => 'Mon historique';

  @override
  String get historyRun => 'Course';

  @override
  String get historyEmpty => 'Aucune séance loggée pour l\'instant.';

  @override
  String get historyDeleteTitle => 'Supprimer cette séance ?';

  @override
  String historyDeleteBody(String name, String date) {
    return '$name · $date\nTon Index sera recalculé.';
  }

  @override
  String get endgameTitle => 'Grand Chelem';

  @override
  String get endgameFlagshipTitle => 'Les 4 séances phares';

  @override
  String get endgameFlagshipSubtitle =>
      'Touche une séance pour voir en quoi elle consiste et la faire.';

  @override
  String get endgameTierBronze => '🥉 Bronze';

  @override
  String get endgameTierBronzeDesc => 'Terminer les 4 séances phares.';

  @override
  String get endgameTierSilver => '🥈 Argent';

  @override
  String endgameTierSilverDesc(int min) {
    return 'Les 4 avec une note ≥ $min/100 — difficile mais atteignable (~1 an de pratique).';
  }

  @override
  String get endgameTierGold => '🥇 Or';

  @override
  String endgameTierGoldDesc(int min) {
    return 'Les 4 avec une note ≥ $min/100 — ultra exigeant (~5 ans).';
  }

  @override
  String get endgameGlobalRank => 'Rang mondial';

  @override
  String get endgameTop100 => 'Top 100 mondial 🌍';

  @override
  String get endgameHeroBronze => 'Grand Chelem Bronze';

  @override
  String get endgameHeroSilver => 'Grand Chelem Argent';

  @override
  String get endgameHeroGold => 'Grand Chelem Or';

  @override
  String get endgameHeroLocked => 'Grand Chelem — non débloqué';

  @override
  String endgameFlagshipDone(int completed, int total) {
    return '$completed/$total séances phares terminées';
  }

  @override
  String challengeBannerLabel(String theme) {
    return 'DÉFI DE LA SEMAINE · $theme';
  }

  @override
  String get challengeEnded => 'Terminé';

  @override
  String challengeCountdownDays(int days, int hours) {
    return 'Plus que $days j $hours h';
  }

  @override
  String challengeCountdownHours(int hours, int minutes) {
    return 'Plus que $hours h $minutes min';
  }

  @override
  String get challengeTitle => 'Défi de la semaine';

  @override
  String get challengeDoIt => 'Faire le défi 🔥';

  @override
  String get challengeDetails => 'Paliers, références pro & détails';

  @override
  String get challengeLeaderboard => 'Classement du défi';

  @override
  String get challengeHeroTagline =>
      'Tout le monde se mesure sur cette séance cette semaine. Donne tout 💪';

  @override
  String get challengeWhatToDo => 'Ce qu\'il faut faire';

  @override
  String get challengeBeFirst =>
      'Sois le premier à relever le défi cette semaine 🔥';

  @override
  String challengeYouSuffix(String name) {
    return '$name (toi)';
  }

  @override
  String get progressionTitle => 'Progression';

  @override
  String get progressionHistoryButton => 'Mon historique de séance';

  @override
  String get progressionEndgameButton =>
      'Endgame — Grand Chelem & rang mondial';

  @override
  String progressionBadges(int unlocked, int total) {
    return 'Badges ($unlocked/$total débloqués)';
  }

  @override
  String get progressionBadgesHint =>
      'Pour chaque série, ton palier actuel et le prochain à viser.';

  @override
  String get coachTitle => 'Coach';

  @override
  String get coachWhichAxis => 'Sur quel axe progresser ?';

  @override
  String get coachWeakPoint => 'Mon point faible';

  @override
  String get coachLoadError =>
      'Impossible de charger les conseils pour le moment.';

  @override
  String coachProgressOn(String attribute) {
    return 'Fais ces séances pour progresser sur $attribute';
  }

  @override
  String get coachTargetedSessions => 'SÉANCES CIBLÉES';

  @override
  String get coachNoSessions => 'Aucune séance pour cet axe avec ton matériel.';

  @override
  String get coachLogSession =>
      'Faire une séance notée & enregistrer mon temps';

  @override
  String coachDurationMin(int min) {
    return '$min min';
  }

  @override
  String get coachWithEquipment => 'Matériel';

  @override
  String get coachNoEquipment => 'Sans matériel';

  @override
  String get coachIntensityHigh => 'Intense';

  @override
  String get coachIntensityMedium => 'Modéré';

  @override
  String get coachIntensityLow => 'Léger';

  @override
  String homeGreeting(String name) {
    return 'Salut, $name';
  }

  @override
  String get homeNotifications => 'Notifications';

  @override
  String get homeSettings => 'Paramètres';

  @override
  String get homeProfileUnavailable => 'Profil indisponible.';

  @override
  String get homeRadarTitle => 'TON RADAR';

  @override
  String get homeRadarHint =>
      'Touche une qualité pour voir les séances qui la boostent.';

  @override
  String get homeCoachCta => 'Coach — progresser sur un axe';

  @override
  String get homeHistory => 'Mon historique';

  @override
  String get homeShareCard => 'Partager ma carte';

  @override
  String get homeFreshnessTitleOne => 'Un axe à rafraîchir';

  @override
  String get homeFreshnessTitleMany => 'Des axes à rafraîchir';

  @override
  String homeFreshnessBody(String names) {
    return '$names : ta mesure date un peu. Un re-test peut la faire grimper.';
  }

  @override
  String get homeAddSessionTitle => 'Ajouter une séance';

  @override
  String get homeAddQuickTitle => 'Ajouter une séance rapidement';

  @override
  String get homeAddQuickSubtitle => 'Choisis une séance de référence';

  @override
  String get homeBuildSessionTitle => 'Construire une séance';

  @override
  String get homeBuildSessionSubtitle =>
      'Compose ta propre séance, estimée automatiquement';

  @override
  String get gradeSummitReached => 'Sommet atteint — 100';

  @override
  String gradeObjective(Object next) {
    return 'Objectif : $next';
  }

  @override
  String get gradeAlmostReal => 'Presque ton vrai Index';

  @override
  String get gradeEstimated => 'Index estimé';

  @override
  String gradeEstimationLoading(Object coverage) {
    return 'Estimation sur $coverage/6 attributs…';
  }

  @override
  String gradeEstimationError(Object coverage) {
    return 'Estimation sur $coverage/6 attributs. Complète ton radar pour révéler ton vrai Index.';
  }

  @override
  String get gradeKeepLogging =>
      'Continue à logger des séances pour finaliser ton Index.';

  @override
  String get gradeCompletePrefix => 'Complète ';

  @override
  String get gradeCompleteSessionOne => 'cette séance';

  @override
  String gradeCompleteSessionMany(Object n) {
    return 'ces $n séances';
  }

  @override
  String get gradeCompleteSuffix => ' pour révéler ton vrai Index :';

  @override
  String gradeUnlocks(String covers) {
    return 'Débloque : $covers';
  }

  @override
  String gradeClimbTo(String next) {
    return 'Continue à logger tes séances pour grimper vers $next.';
  }

  @override
  String get gradeWorkPrefix => 'Travaille ta ';

  @override
  String get gradeWorkMiddle => ' pour viser ';

  @override
  String get gradeWorkSuffix => '.';

  @override
  String get rivalChasing => 'TU POURSUIS';

  @override
  String get rivalGapOne => 'Plus qu\'1 point pour le rattraper 👊';

  @override
  String rivalGapMany(Object gap) {
    return 'Plus que $gap points pour le rattraper 👊';
  }

  @override
  String get rivalLeaderLabel => 'LEADER DE TA LIGUE';

  @override
  String get rivalLeaderTitle => 'Tu es en tête 👑';

  @override
  String get rivalLeaderBody => 'Défends ta place — bats ton propre record.';

  @override
  String get recapWeekLabel => 'TA SEMAINE';

  @override
  String get recapValidated => 'validée ✅';

  @override
  String get recapSessionsSingular => 'séance';

  @override
  String get recapSessionsPlural => 'séances';

  @override
  String get recapIndexPoints => 'points d\'Index';

  @override
  String get recapWeeksSingular => 'semaine 🔥';

  @override
  String get recapWeeksPlural => 'semaines 🔥';

  @override
  String recapMessageGain(Object delta) {
    return 'Belle semaine — ton travail paye, +$delta sur ton Index.';
  }

  @override
  String get recapMessageKeepGoing => 'Bien joué, continue sur ta lancée.';

  @override
  String get recapMessageStart => 'Une séance suffit pour lancer la semaine.';

  @override
  String streakDetailValidated(Object current) {
    return 'Semaine validée ✅ — série de $current';
  }

  @override
  String streakDetailSeries(Object current) {
    return 'Série de $current semaines';
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
      other: 'Encore $leftString séances pour valider ta semaine',
      one: 'Encore $leftString séance pour valider ta semaine',
    );
    return '$_temp0';
  }

  @override
  String get streakSheetTitle => 'Ta série';

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
          '$currentString semaines actives d\'affilée. Une semaine compte dès $goal séances.',
      one:
          '$currentString semaine active d\'affilée. Une semaine compte dès $goal séances.',
    );
    return '$_temp0';
  }

  @override
  String streakSheetStart(Object goal) {
    return 'Fais $goal séances cette semaine pour démarrer ta série.';
  }

  @override
  String get streakThisWeek => 'Cette semaine';

  @override
  String get streakBest => 'Record';

  @override
  String streakBestValue(Object best) {
    return '$best sem.';
  }

  @override
  String get streakFreezeTokens => 'Jetons de repos';

  @override
  String get streakFreezeHint => 'Protègent une semaine ratée.';

  @override
  String get streakNoPressure =>
      'Pas de pression : rater une semaine ne fait jamais baisser ton Index.';

  @override
  String get socialProofBases =>
      'Tu poses tes bases — chaque séance te rapproche du haut du classement.';

  @override
  String get socialProofElite =>
      '🔥 Tu es dans l\'élite — tout en haut des plus performants.';

  @override
  String get socialProofTopPrefix => 'Tu fais partie des ';

  @override
  String get socialProofTopSuffix => ' des humains les plus en forme';

  @override
  String get socialProofAppPrefix => 'Top ';

  @override
  String get socialProofAppSuffix => ' des athlètes HYBRID';

  @override
  String get revealYourIndex => 'TON ATHLETE INDEX';

  @override
  String get revealDoProfilExpress => 'Faire le Profil Express';

  @override
  String get revealEstimateTitle => 'Ceci est une estimation';

  @override
  String revealEstimateBody(int coverage) {
    return 'Ton Index de départ s\'appuie sur $coverage/6 attributs. Logge quelques séances de plus pour débloquer les 6 et révéler ton vrai Athlete Index.';
  }

  @override
  String get revealRadar => 'TON RADAR';

  @override
  String get revealDiscoverProfile => 'Découvrir mon profil';

  @override
  String get revealShareCard => 'Partager ma carte';

  @override
  String get revealComputing => 'Calcul de ton Index…';

  @override
  String get shareCardTitle => 'Ma carte';

  @override
  String get shareCardShareText =>
      'Mon Athlete Index 💪 Et toi, c\'est combien ? #AthleteIndex';

  @override
  String get shareCardDownloaded => 'Carte téléchargée 📥';

  @override
  String get shareCardDownloadUnsupported => 'Téléchargement non supporté ici.';

  @override
  String get shareCardNoIndex => 'Aucun Index à partager.';

  @override
  String get shareCardTagline => 'Montre ton niveau — défie tes amis 🔥';

  @override
  String get shareCardShareCta => 'Partager ma carte';

  @override
  String get shareCardDownload => 'Télécharger';

  @override
  String get shareCardOvr => 'NIVEAU';

  @override
  String get shareCardLeague => 'LIGUE';

  @override
  String shareCardTopPct(Object pct) {
    return '★ TOP $pct %';
  }

  @override
  String get shareCardAthlete => 'Athlète';

  @override
  String get leaderboardTitle => 'Ligue';

  @override
  String get leaderboardWeeklyProgress =>
      'Progression de la semaine (par effort)';

  @override
  String get leaderboardMen => 'Hommes';

  @override
  String get leaderboardWomen => 'Femmes';

  @override
  String get leaderboardUnavailable =>
      'Classement indisponible pour le moment.';

  @override
  String get leaderboardRetry => 'Réessayer';

  @override
  String get leaderboardEmpty => 'Aucun athlète pour l\'instant.';

  @override
  String leaderboardYou(String name) {
    return '$name  (toi)';
  }

  @override
  String get progressBoardTitle => 'Progression de la semaine';

  @override
  String progressBoardClubTitle(String clubName) {
    return 'Progression · $clubName';
  }

  @override
  String get progressBoardHeader =>
      '🔥 Ici on récompense l\'effort de la semaine — pas le talent. Chaque séance, chaque record, chaque jour actif te fait monter.';

  @override
  String get progressBoardEmpty =>
      'Personne n\'a encore bougé cette semaine. Logue une séance et prends la tête 💪';

  @override
  String progressBoardMyPosition(Object position, Object ep) {
    return 'Ta place cette semaine : #$position · $ep pts d\'effort';
  }

  @override
  String progressBoardPts(Object ep) {
    return '$ep pts';
  }
}
