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
  String get sessionsLeagueBadge => 'LIGUE';

  @override
  String get sessionsLeagueImposedBody =>
      'La séance imposée de la Ligue du mois. Fais-la pour marquer des points au classement.';

  @override
  String get sessionsLeagueDoIt => 'Faire cette séance';

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
  String get commonGenericError => 'Une erreur est survenue. Réessaie.';

  @override
  String get commonGotIt => 'Compris';

  @override
  String get celebrationContinue => 'Continuer';

  @override
  String get celebrationTapToContinue => 'Touche pour continuer';

  @override
  String get celebrationClose => 'Fermer';

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
  String get wodPredictionConfidenceHigh => 'Estimation fiable';

  @override
  String get wodPredictionConfidenceMedium => 'Estimation approximative';

  @override
  String get wodPredictionConfidenceLow =>
      'Estimation large — fais quelques séances de plus pour l\'affiner';

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
  String wreBadgeUnlocked(String name) {
    return 'Badge débloqué : $name';
  }

  @override
  String wreBadgesUnlocked(int count) {
    return '$count nouveaux badges débloqués !';
  }

  @override
  String get wreSeeMyBadges => 'Voir mes badges';

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
  String wreBandUp(int percent) {
    return '🚀 Tu entres dans le top $percent% des plus en forme !';
  }

  @override
  String wreOvertookTitle(String name) {
    return 'Tu as doublé $name !';
  }

  @override
  String get wreOvertookSubtitle => 'Nouveau rival en vue';

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
  String get commonSeeMore => 'Voir plus';

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
  String get wodTabEmpty =>
      'Aucune séance de référence disponible pour l\'instant. Explore les séances par axe ci-dessus, ou tire pour rafraîchir.';

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
  String get wodDetailGuidedMode => 'Mode guidé';

  @override
  String get wodDetailEdit => 'Modifier la séance';

  @override
  String get wodDetailDelete => 'Supprimer la séance';

  @override
  String get wodDetailDeleteTitle => 'Supprimer cette séance ?';

  @override
  String get wodDetailDeleteBody =>
      'Cette action est définitive. Si des athlètes ont déjà enregistré un résultat, la suppression sera refusée.';

  @override
  String get wodDetailDeleteCancel => 'Annuler';

  @override
  String get wodDetailDeleteConfirm => 'Supprimer';

  @override
  String get wodDetailDeleteDone => 'Séance supprimée.';

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
  String wodDetailLevelEstimate(String estimate) {
    return 'estimation niveau : $estimate';
  }

  @override
  String get wodDetailAboveLevel => 'tu dépasses ton niveau estimé 🔥';

  @override
  String get wodDetailBelowLevel => 'tu peux encore progresser';

  @override
  String wodDetailBeatRecord(String best) {
    return 'Tu as déjà fait $best sur cette séance — bats ton record !';
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
  String get wodDetailVariantOpen => 'Open';

  @override
  String get wodFormatRounds => 'tours';

  @override
  String get wodDetailYouShort => 'Toi';

  @override
  String wodDetailLeaderboardYou(String name) {
    return '$name (toi)';
  }

  @override
  String get wodBuilderTitle => 'Construire une séance';

  @override
  String get wodBuilderEditTitle => 'Modifier la séance';

  @override
  String get wodBuilderSaveChanges => 'Enregistrer les modifications';

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
  String get wodBuilderEstimateUnavailable =>
      'L\'estimation de charge n\'est pas encore disponible pour les séances personnalisées. Ajoute un mouvement chargé (haltérophilie) pour une estimation en kg.';

  @override
  String get wodBuilderEstimateError => 'Estimation indisponible.';

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
  String get wodFmtForTime => 'For Time';

  @override
  String get wodFmtAmrap => 'AMRAP';

  @override
  String get wodFmtEmom => 'EMOM';

  @override
  String get wodFmtInterval => 'Intervalles';

  @override
  String get wodFmtTabata => 'Tabata';

  @override
  String get wodFmtStrength => 'Force';

  @override
  String get wodUnitHintMeter => 'ex. 2000';

  @override
  String get wodUnitHintCalorie => 'ex. 15';

  @override
  String get wodUnitHintSecond => 'ex. 30';

  @override
  String get wodUnitHintRep => 'ex. 10';

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
  String get wodUnitMeters => 'mètres';

  @override
  String get wodBuilderCatalogLoading => 'Chargement des mouvements…';

  @override
  String get wodBuilderCatalogError => 'Impossible de charger les mouvements.';

  @override
  String get wodBuilderNameLabel => 'Nom de la séance';

  @override
  String get wodBuilderNameHint => 'Nomme ta séance';

  @override
  String get wodBuilderNameAutoHint =>
      'Généré automatiquement — tu peux le modifier.';

  @override
  String get wodBuilderDiscardTitle => 'Abandonner la séance ?';

  @override
  String get wodBuilderDiscardBody =>
      'Tes mouvements ne seront pas enregistrés.';

  @override
  String get wodBuilderDiscardStay => 'Continuer l\'édition';

  @override
  String get wodBuilderDiscardLeave => 'Abandonner';

  @override
  String get a11yEstimateLiveRegion => 'Estimation mise à jour';

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
  String get communityPostBlock => 'Bloquer cet athlète';

  @override
  String get communityUserBlocked => 'Athlète bloqué.';

  @override
  String get communityReportSent => 'Merci, signalement envoyé.';

  @override
  String get communityBlockConfirmTitle => 'Bloquer cet athlète ?';

  @override
  String get communityBlockConfirmBody =>
      'Vous ne verrez plus son activité et il ne pourra plus vous contacter. Vous pourrez le débloquer plus tard dans les réglages.';

  @override
  String get communityBlockConfirmAction => 'Bloquer';

  @override
  String get communityDeleteConfirmTitle => 'Supprimer cette publication ?';

  @override
  String get communityDeleteConfirmBody =>
      'Cette publication sera définitivement supprimée. Action irréversible.';

  @override
  String get communityPostDeleted => 'Publication supprimée.';

  @override
  String get communityDiscoverTitle => 'Personne à suivre… pour l\'instant';

  @override
  String get communityDiscoverSubtitle =>
      'Voici le haut de ta ligue. Suis des athlètes pour remplir ton fil.';

  @override
  String get communityFollow => 'Suivre';

  @override
  String get communityFollowing => 'Suivi';

  @override
  String get communityKudosTooltip => 'Bravo';

  @override
  String get communityWorkoutFallback => 'une séance';

  @override
  String get communityScopeAll => 'Tout';

  @override
  String get communityScopeFollowing => 'Suivis';

  @override
  String get communityEmptyFollowing =>
      'Tu ne suis personne pour l\'instant. Bascule sur « Tout » pour découvrir la communauté, ou suis des athlètes pour remplir ton fil.';

  @override
  String get commentsTitle => 'Commentaires';

  @override
  String get commentsEmpty =>
      'Aucun commentaire pour l\'instant. Sois le premier à réagir.';

  @override
  String get commentHint => 'Ajoute un commentaire…';

  @override
  String get commentSend => 'Envoyer';

  @override
  String get commentDelete => 'Supprimer';

  @override
  String get commentReport => 'Signaler';

  @override
  String get commentDeleted => 'Commentaire supprimé.';

  @override
  String get commentKudosTooltip => 'Bravo';

  @override
  String get commentReply => 'Répondre';

  @override
  String commentReplyHint(String name) {
    return 'Répondre à $name…';
  }

  @override
  String commentRepliesShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les $count réponses',
      one: 'la réponse',
    );
    return 'Voir $_temp0';
  }

  @override
  String get commentRepliesHide => 'Masquer les réponses';

  @override
  String a11yCommentKudos(int count) {
    return 'Bravo, $count applaudissements';
  }

  @override
  String a11yMention(String name) {
    return 'Mention de $name, ouvrir le profil';
  }

  @override
  String get profileWallTitle => 'Publications';

  @override
  String get profileWallEmpty => 'Cet athlète n\'a encore rien publié.';

  @override
  String get profileWallEmptyMine =>
      'Tu n\'as encore rien publié. Partage une perf ou un message depuis la Communauté.';

  @override
  String get composerMentionHint => 'Mentionne quelqu\'un avec @';

  @override
  String get notifPostKudos => 'On a applaudi ta publication 👏';

  @override
  String notifPostKudosBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes ont applaudi',
      one: '1 personne a applaudi',
    );
    return '$_temp0 ta publication.';
  }

  @override
  String get notifComment => 'Nouveau commentaire';

  @override
  String notifCommentBody(String name) {
    return '$name a commenté ta publication.';
  }

  @override
  String get notifCommentKudos => 'On a applaudi ton commentaire 👏';

  @override
  String notifCommentKudosBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes ont applaudi',
      one: '1 personne a applaudi',
    );
    return '$_temp0 ton commentaire.';
  }

  @override
  String get notifReply => 'Nouvelle réponse';

  @override
  String notifReplyBody(String name) {
    return '$name a répondu à ton commentaire.';
  }

  @override
  String get notifMention => 'On t\'a mentionné';

  @override
  String notifMentionBody(String name) {
    return '$name t\'a mentionné.';
  }

  @override
  String get timeAgoNow => 'à l\'instant';

  @override
  String timeAgoMinutes(int n) {
    return 'il y a $n min';
  }

  @override
  String timeAgoHours(int n) {
    return 'il y a $n h';
  }

  @override
  String timeAgoDays(int n) {
    return 'il y a $n j';
  }

  @override
  String communityMsgPr(String wodName) {
    return '🏆 Nouveau record — $wodName';
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
      'Aucune conversation pour l\'instant. Ouvre le profil d\'un athlète et écris-lui : tout le monde est joignable.';

  @override
  String get conversationsYouPrefix => 'Toi : ';

  @override
  String get chatToday => 'Aujourd\'hui';

  @override
  String get chatYesterday => 'Hier';

  @override
  String get chatLoadOlder => 'Charger les messages précédents';

  @override
  String get chatStatusSending => 'Envoi…';

  @override
  String get chatStatusFailed => 'Échec — appuie pour réessayer';

  @override
  String get chatStatusSent => 'Envoyé';

  @override
  String get chatStatusRead => 'Lu';

  @override
  String chatTyping(String name) {
    return '$name est en train d\'écrire…';
  }

  @override
  String get chatViewProfile => 'Voir le profil';

  @override
  String get chatBlock => 'Bloquer';

  @override
  String chatBlockConfirmTitle(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get chatBlockConfirmBody =>
      'Vous ne pourrez plus vous écrire. Tu pourras le débloquer plus tard.';

  @override
  String get chatBlockCancel => 'Annuler';

  @override
  String get chatBlockConfirm => 'Bloquer';

  @override
  String chatBlocked(String name) {
    return '$name a été bloqué.';
  }

  @override
  String get dmReasonAge =>
      'Les messages privés ne sont possibles qu\'entre comptes de la même tranche d\'âge.';

  @override
  String get dmReasonBlocked => 'Échange impossible avec cet utilisateur.';

  @override
  String get dmReasonUnavailable => 'Ce compte n\'est plus disponible.';

  @override
  String get messagingErrorRateLimited =>
      'Tu envoies trop de messages. Réessaie dans un instant.';

  @override
  String get messagingErrorNotAllowed =>
      'Message impossible avec cet utilisateur.';

  @override
  String get messagingErrorNotFound => 'Conversation introuvable.';

  @override
  String get messagingErrorTooLong =>
      'Message trop long (2000 caractères max).';

  @override
  String get messagingErrorNetwork =>
      'Connexion impossible. Vérifie ta connexion et réessaie.';

  @override
  String get messagingErrorGeneric => 'Une erreur est survenue. Réessaie.';

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
  String get feedWeekAlmostTitle => 'Plus qu\'un WOD';

  @override
  String feedWeekAlmostBody(int count, int goal) {
    return 'Un entraînement et ta semaine est validée ($count/$goal).';
  }

  @override
  String get feedWeekValidatedTitle => 'Semaine validée';

  @override
  String feedWeekValidatedBody(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'Série en cours : $streak semaines. Continue !',
      one: 'Série en cours : 1 semaine. Continue !',
    );
    return '$_temp0';
  }

  @override
  String feedNextRankTitle(String rank) {
    return 'Le rang $rank est proche';
  }

  @override
  String feedNextRankBody(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: 'Encore $points points. Un bon WOD et tu y es.',
      one: 'Encore 1 point. Un bon WOD et tu y es.',
    );
    return '$_temp0';
  }

  @override
  String feedRankOvertakenTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count athlètes t\'ont dépassé',
      one: 'Un athlète t\'a dépassé',
    );
    return '$_temp0';
  }

  @override
  String get feedRankOvertakenBody => 'Reprends ta place au classement.';

  @override
  String feedWodOvertakenTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Battu sur $count WODs',
      one: 'Un athlète a battu ton temps',
    );
    return '$_temp0';
  }

  @override
  String get feedWodOvertakenBody => 'Va défendre tes scores.';

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
  String get coachLibraryTitle => 'Bibliothèque du coach';

  @override
  String get coachLibrarySubtitle =>
      'Des séances guidées, clés en main. Choisis-en une et suis le déroulé.';

  @override
  String get coachLibraryAll => 'Tout';

  @override
  String get coachLibraryError =>
      'Impossible de charger la bibliothèque de séances pour le moment.';

  @override
  String get coachLibraryEmpty =>
      'Aucune séance guidée pour ce filtre avec ton matériel.';

  @override
  String get coachLibraryEntryTitle => 'Bibliothèque du coach';

  @override
  String get coachLibraryEntrySubtitle =>
      'Des séances guidées à suivre — distinctes des épreuves que tu logues.';

  @override
  String get sessionsByFocusCaption =>
      'Les épreuves à loguer qui mesurent chaque axe de ton score.';

  @override
  String get sessionsToLog => 'Épreuves à loguer';

  @override
  String get sessionsGuidedLinkTitle => 'Séances guidées du coach';

  @override
  String get sessionsGuidedLinkSubtitle =>
      'Des entraînements clés en main pour cet axe';

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
  String get homeGreetingNoName => 'Salut 👋';

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
  String socialProofA11yHumanityApp(Object humanity, Object app) {
    return 'Preuve sociale. $humanity $app';
  }

  @override
  String socialProofA11yHumanity(Object humanity) {
    return 'Preuve sociale. $humanity';
  }

  @override
  String recapA11y(int sessions, int delta, int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions séances',
      one: '$sessions séance',
    );
    String _temp1 = intl.Intl.pluralLogic(
      delta,
      locale: localeName,
      other: 'plus $delta d\'Index',
      one: 'plus $delta d\'Index',
      zero: 'aucun gain d\'Index',
    );
    String _temp2 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak semaines de série',
      one: '$streak semaine de série',
    );
    return 'Ta semaine : $_temp0, $_temp1, $_temp2.';
  }

  @override
  String gradeA11y(Object title, int coverage, int sessions) {
    String _temp0 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other:
          'Complète $sessions séances recommandées pour révéler ton vrai Index.',
      one: 'Complète $sessions séance recommandée pour révéler ton vrai Index.',
      zero: 'Continue à logger des séances.',
    );
    return '$title, basé sur $coverage/6 attributs. $_temp0';
  }

  @override
  String gradeSessionA11y(Object name, Object covers) {
    return 'Séance recommandée : $name. Débloque $covers. Toucher pour ouvrir la fiche.';
  }

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
  String shareCardA11y(Object name, Object ovr, Object archetype) {
    return 'Carte de $name, Athlete Index $ovr, archétype $archetype';
  }

  @override
  String get shareCardOvrEstimated => 'NIVEAU ESTIMÉ';

  @override
  String get shareCardEstimatedBadge => 'ESTIMÉ';

  @override
  String get shareCardUnderConstruction => 'EN CONSTRUCTION';

  @override
  String get archetypeInProgress => 'PROFIL EN COURS';

  @override
  String shareCardRevealCta(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n séances',
      one: '1 séance',
    );
    return 'Plus que $_temp0 pour révéler ta vraie carte';
  }

  @override
  String get shareCardRevealConfirm =>
      'Confirme tes scores en séance pour figer ta carte';

  @override
  String get shareCardRevealedTitle => 'Ta carte est révélée !';

  @override
  String get shareCardRevealedSubtitle =>
      'Ton vrai Athlete Index est débloqué.';

  @override
  String shareCardA11yUnderConstruction(
      String name, int ovr, int n, int coverage) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n séances restantes pour révéler ta vraie carte.',
      one: '1 séance restante pour révéler ta vraie carte.',
      zero: 'Confirme tes scores pour la figer.',
    );
    return 'Carte de $name en construction. Niveau estimé $ovr. $_temp0 $coverage attributs sur 6 mesurés.';
  }

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

  @override
  String get archetypeHybrid => 'ATHLÈTE HYBRIDE';

  @override
  String get archetypeAllRound => 'TOUT-TERRAIN';

  @override
  String get archetypeEngine => 'MOTEUR';

  @override
  String get archetypeStrength => 'LA FORCE';

  @override
  String get archetypePower => 'EXPLOSIF';

  @override
  String get archetypeSpeed => 'VÉLOCITÉ';

  @override
  String get archetypeMuscularEndurance => 'INFATIGABLE';

  @override
  String get rfFarBetterTitle1 => 'Performance d\'exception';

  @override
  String rfFarBetterBody1(String gain) {
    return 'Tu as battu ta prédiction de $gain. Ce n\'est pas la chance : c\'est ton travail qui parle. Note ce que tu as fait de bien aujourd\'hui.';
  }

  @override
  String get rfFarBetterTitle2 => 'Tu as explosé le plafond';

  @override
  String rfFarBetterBody2(String gain) {
    return '$gain au-dessus de ce qu\'on attendait de toi. Ton niveau réel vient de prendre de l\'avance sur le modèle. Continue exactement comme ça.';
  }

  @override
  String get rfFarBetterTitle3 => 'Bien au-dessus de la cible';

  @override
  String rfFarBetterBody3(String gain) {
    return 'Prédiction pulvérisée de $gain. Ce genre de séance, c\'est la preuve concrète que ta préparation paie.';
  }

  @override
  String get rfBetterTitle1 => 'Au-dessus de la cible';

  @override
  String rfBetterBody1(String gain) {
    return '$gain de mieux que ta prédiction. Tu progresses dans la bonne direction, et ça se voit.';
  }

  @override
  String get rfBetterTitle2 => 'Solide. Tu prends le dessus';

  @override
  String rfBetterBody2(String gain) {
    return 'Tu as dépassé ce qui était attendu de $gain. Garde ce rythme, c\'est exactement comme ça qu\'on monte.';
  }

  @override
  String get rfBetterTitle3 => 'Mieux que prévu';

  @override
  String rfBetterBody3(String gain) {
    return '+$gain sur la prédiction. Petit écart, vraie progression : capitalise dessus à ta prochaine séance.';
  }

  @override
  String get rfOnTargetTitle1 => 'Pile dans la cible';

  @override
  String rfOnTargetBody1(String metric) {
    return 'Tu as fait exactement le $metric prévu pour toi. Atteindre sa cible, c\'est déjà une réussite : ton niveau et ta perf sont alignés.';
  }

  @override
  String get rfOnTargetTitle2 => 'Objectif atteint';

  @override
  String get rfOnTargetBody2 =>
      'Tu as tenu la prédiction au plus juste. C\'est de la régularité maîtrisée — la base de toute vraie progression.';

  @override
  String get rfOnTargetTitle3 => 'Dans le mille';

  @override
  String get rfOnTargetBody3 =>
      'Tu as réalisé la perf attendue pour ton niveau. Solide et fiable : maintenant, vise un cran au-dessus.';

  @override
  String get rfBelowTitle1 => 'Séance dans la boîte';

  @override
  String get rfBelowBody1 =>
      'Un peu en dessous de ta cible aujourd\'hui, mais tu l\'as terminée — et c\'est ça qui compte. On sait que tu peux faire mieux : la prochaine sera meilleure.';

  @override
  String get rfBelowTitle2 => 'Bravo, c\'est noté';

  @override
  String rfBelowBody2(String wodName) {
    return 'Pas ton meilleur jour sur $wodName, mais chaque répétition compte dans ta progression. Tu as la marge pour repasser au-dessus.';
  }

  @override
  String get rfBelowTitle3 => 'Tu as fait le travail';

  @override
  String get rfBelowBody3 =>
      'Résultat un peu sous ta prédiction, mais l\'important c\'est que tu sois venu(e). On est sûrs que tu peux faire mieux la prochaine fois.';

  @override
  String get rfWayBelowTitle1 => 'Mauvais jour, ça arrive';

  @override
  String rfWayBelowBody1(String wodName) {
    return 'Loin de ton niveau habituel aujourd\'hui — et ce n\'est pas grave. Le corps a ses jours sans. Repose-toi, et reviens retenter $wodName en forme : tu vaux bien mieux que ça.';
  }

  @override
  String get rfWayBelowTitle2 => 'Ce n\'était pas ton jour';

  @override
  String rfWayBelowBody2(String wodName) {
    return 'Cette perf ne reflète pas ce dont tu es capable. Fatigue, sommeil, journée chargée : ça compte. Reviens sur $wodName quand tu seras au top.';
  }

  @override
  String get rfWayBelowTitle3 => 'On range cette séance';

  @override
  String rfWayBelowBody3(String wodName) {
    return 'Jour sans, tout simplement. L\'avoir terminée malgré tout, c\'est déjà du mental. Récupère bien et retente $wodName reposé(e) — tu feras nettement mieux.';
  }

  @override
  String get rfNoPredictionTitle1 => 'Résultat enregistré';

  @override
  String get rfNoPredictionBody1 =>
      'Belle séance, c\'est dans la boîte. Encore quelques entraînements et on pourra te dire exactement où tu te situes — et te prédire tes prochains chronos.';

  @override
  String get rfNoPredictionTitle2 => 'C\'est noté, continue';

  @override
  String get rfNoPredictionBody2 =>
      'Chaque résultat enregistré rapproche ton Index complet. Bientôt, on te donnera une cible personnalisée à battre sur chaque séance.';

  @override
  String get rfMetricTime => 'temps';

  @override
  String get rfMetricScore => 'score';

  @override
  String get commonOk => 'OK';

  @override
  String get leagueScreenTitle => 'Ligue du mois';

  @override
  String get leagueRivalTitle => 'Ton rival dans la ligue';

  @override
  String get leagueUnavailable => 'Ligue indisponible pour le moment.';

  @override
  String get leagueRetry => 'Réessayer';

  @override
  String get leagueNoSeason =>
      'Aucune saison de Ligue en cours.\nReviens bientôt : une nouvelle saison démarre chaque mois.';

  @override
  String get leagueHeaderMen => 'LIGUE HOMME';

  @override
  String get leagueHeaderWomen => 'LIGUE FEMME';

  @override
  String get leagueLastDay => 'Dernier jour de la saison';

  @override
  String leagueEndsIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Se termine dans $days jours',
      one: 'Se termine dans $days jour',
    );
    return '$_temp0';
  }

  @override
  String get leaguePointsReset => 'Les points repartent à zéro chaque mois.';

  @override
  String get leagueExplainerTitle => 'La Ligue du mois, c\'est quoi ?';

  @override
  String get leagueExplainerBody =>
      'Chaque mois, une nouvelle saison. Tu es classé AUTOMATIQUEMENT parmi les athlètes de ton sexe. Fais la séance imposée de la semaine : tu marques des points selon ta performance. Les points de Ligue repartent à zéro chaque mois.';

  @override
  String get leagueWeekWod => 'SÉANCE DE LA SEMAINE';

  @override
  String get leagueWeekWodHint =>
      'La séance imposée de la semaine — donne tout pour grimper au classement.';

  @override
  String get leagueDoThisWod => 'Faire cette séance';

  @override
  String get leagueStandingsUnavailable => 'Classement indisponible.';

  @override
  String get leagueStandingsTitle => 'Classement du mois';

  @override
  String get leagueStandingsEmpty =>
      'Personne n\'a encore marqué ce mois-ci. Sois le premier !';

  @override
  String get leagueMyPosition => 'MA POSITION';

  @override
  String leaguePts(int points) {
    return '$points pts';
  }

  @override
  String get leagueDoWodToEnter => 'Fais la séance pour entrer au classement';

  @override
  String get leagueThisMonth => 'ce mois-ci';

  @override
  String leagueRowYou(String name) {
    return '$name (moi)';
  }

  @override
  String get leagueSegmentMen => 'Hommes';

  @override
  String get leagueSegmentWomen => 'Femmes';

  @override
  String get leagueHowItWorksTitle => 'Comment ça marche ?';

  @override
  String get leagueHowItWorksBest =>
      'Seul ton MEILLEUR essai de la semaine compte — tu peux retenter autant de fois que tu veux, on ne garde que le meilleur.';

  @override
  String get leagueHowItWorksReset =>
      'Les points repartent à zéro au début de chaque mois. Tout le monde recommence à égalité.';

  @override
  String get leagueHowItWorksIndex =>
      'Ton Index ne bouge jamais ici : la Ligue est une compétition mensuelle séparée.';

  @override
  String leagueRevealTitle(String month) {
    return 'Saison $month — résultats';
  }

  @override
  String get leagueRevealPodium => 'PODIUM';

  @override
  String leagueRevealYouFinished(String rank) {
    return 'Tu finis $rank';
  }

  @override
  String leagueRevealRankOrdinal(String ordinal) {
    return '$ordinal';
  }

  @override
  String get leagueRevealNotRanked => 'Tu n\'étais pas classé cette saison.';

  @override
  String get leagueRevealNewSeason =>
      'Une nouvelle saison commence — à toi de jouer !';

  @override
  String get leagueRevealClose => 'C\'est parti';

  @override
  String get leagueRevealMovedUp => 'Tu as gagné des places';

  @override
  String get leagueRevealMovedDown => 'Tu as perdu des places';

  @override
  String get leagueRevealStable => 'Tu es resté stable';

  @override
  String notificationsJoinedClub(String clubName) {
    return 'Tu as rejoint $clubName !';
  }

  @override
  String get notificationsClubInviteTitle => 'Invitation à un club';

  @override
  String notificationsClubInviteMembers(String clubName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$clubName · $_temp0';
  }

  @override
  String get notificationsJoin => 'Rejoindre';

  @override
  String get notificationsDecline => 'Refuser';

  @override
  String get a11ySend => 'Envoyer le message';

  @override
  String get a11yRetryMessage => 'Renvoyer le message';

  @override
  String a11yUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '$count message non lu',
    );
    return '$_temp0';
  }

  @override
  String get a11yDecrease => 'Diminuer';

  @override
  String get a11yIncrease => 'Augmenter';

  @override
  String a11yDailyCapValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications par jour',
      one: '$count notification par jour',
    );
    return '$_temp0';
  }

  @override
  String a11yLeagueMyPosition(int position, int points) {
    return 'Tu es ${position}e avec $points points';
  }

  @override
  String a11yLeagueRow(int position, String name, int points) {
    return '${position}e place, $name, $points points';
  }

  @override
  String a11yPodiumPlace(String ordinal, String name, int points) {
    return '$ordinal place : $name, $points points';
  }

  @override
  String a11yRemoveMovementNamed(String name) {
    return 'Retirer $name';
  }

  @override
  String a11yAmountField(String movement, String unit) {
    return 'Quantité pour $movement en $unit';
  }

  @override
  String a11yLoadField(String movement) {
    return 'Charge en kilos pour $movement';
  }

  @override
  String get a11yEstimateBadge => 'Valeurs estimées, indicatives';

  @override
  String a11yFlagshipDone(String name, int score) {
    return '$name, faite, score $score sur 100';
  }

  @override
  String a11yFlagshipTodo(String name) {
    return '$name, à faire';
  }

  @override
  String get a11yUnlocked => 'débloqué';

  @override
  String get a11yLocked => 'verrouillé';

  @override
  String a11yBadge(String name) {
    return 'Badge $name';
  }

  @override
  String get a11yHomeViewProgression => 'Voir ta progression';

  @override
  String get a11yHomeEditAvatar => 'Modifier ton avatar';

  @override
  String get a11yHomeBetaInfo => 'Infos version bêta';

  @override
  String a11yRivalChasing(String name, int ovr, int gap) {
    String _temp0 = intl.Intl.pluralLogic(
      gap,
      locale: localeName,
      other: '$gap points au-dessus de toi',
      one: '1 point au-dessus de toi',
    );
    return 'Ton rival $name, Index $ovr, $_temp0. Touche pour voir le classement.';
  }

  @override
  String get a11yRivalLeader =>
      'Tu es en tête de ta ligue. Touche pour voir le classement.';

  @override
  String a11yCoachFilter(String name) {
    return 'Filtrer : $name';
  }

  @override
  String a11yCoachSession(String name, int duration, String intensity) {
    return 'Séance $name, $duration minutes, intensité $intensity';
  }

  @override
  String a11ySessionWod(String name) {
    return 'Épreuve $name';
  }

  @override
  String get guidedTimerStart => 'Démarrer';

  @override
  String get guidedTimerPause => 'Pause';

  @override
  String get guidedTimerResume => 'Reprendre';

  @override
  String get guidedTimerReset => 'Réinitialiser';

  @override
  String get guidedTimerFinish => 'Terminer';

  @override
  String get guidedTimerDone => 'Terminé !';

  @override
  String get guidedTimerClose => 'Fermer le chrono';

  @override
  String get guidedTimerCountdownLabel => 'COMPTE À REBOURS';

  @override
  String get guidedTimerStopwatchLabel => 'CHRONO LIBRE';

  @override
  String a11yGuidedTimerValue(String value) {
    return 'Chrono : $value';
  }

  @override
  String get coachSessionGuidedMode => 'Mode guidé';

  @override
  String get guidedPhaseWork => 'Travail';

  @override
  String get guidedPhaseRest => 'Repos';

  @override
  String get guidedPhasePrepare => 'Prépare-toi';

  @override
  String get guidedStateRunning => 'En cours';

  @override
  String get guidedStatePaused => 'En pause';

  @override
  String guidedRoundOf(int current, int total) {
    return 'Tour $current / $total';
  }

  @override
  String guidedMinuteOf(int current, int total) {
    return 'Minute $current / $total';
  }

  @override
  String guidedSetOf(int current, int total) {
    return 'Série $current / $total';
  }

  @override
  String guidedRoundsDone(int count) {
    return 'Tours : $count';
  }

  @override
  String get guidedAddRound => 'Tour +1';

  @override
  String get guidedSetDone => 'Série faite';

  @override
  String get guidedSkip => 'Passer';

  @override
  String get guidedStart => 'Démarrer';

  @override
  String get guidedPause => 'Pause';

  @override
  String get guidedResume => 'Reprendre';

  @override
  String get guidedFinish => 'Terminer';

  @override
  String get guidedGo => 'C\'est parti !';

  @override
  String get guidedCountdownGo => 'GO';

  @override
  String get guidedDone => 'Séance terminée';

  @override
  String get guidedSaveResult => 'Enregistrer mon temps';

  @override
  String guidedTotalTime(String time) {
    return 'Temps total $time';
  }

  @override
  String get guidedStreakCredited => 'Série créditée 🔥';

  @override
  String get guidedValidating => 'Validation…';

  @override
  String get guidedCreditFailed => 'Impossible d\'enregistrer — réessayer';

  @override
  String get guidedRetry => 'Réessayer';

  @override
  String get guidedQuitTitle => 'Quitter la séance ?';

  @override
  String get guidedQuitBody => 'Ta progression de cette séance sera perdue.';

  @override
  String get guidedQuitConfirm => 'Quitter';

  @override
  String get guidedQuitCancel => 'Continuer';

  @override
  String get guidedSoundOn => 'Couper le son';

  @override
  String get guidedSoundOff => 'Activer le son';

  @override
  String get guidedClose => 'Fermer';

  @override
  String get a11yGuidedPhaseWork => 'Travail';

  @override
  String get a11yGuidedPhaseRest => 'Repos';

  @override
  String get a11yGuidedPhasePrepare => 'Prépare-toi';

  @override
  String a11yGuidedRound(int n) {
    return 'Tour $n';
  }

  @override
  String a11yGuidedMinute(int n) {
    return 'Minute $n';
  }

  @override
  String a11yGuidedSet(int n) {
    return 'Série $n';
  }

  @override
  String a11yGuidedCountdown(int n) {
    return '$n';
  }

  @override
  String a11yGuidedTimeValue(String value) {
    return 'Chrono : $value';
  }

  @override
  String get coachSessionMarkDone => 'Marquer comme faite';

  @override
  String get coachSessionDoneTitle => 'Séance validée';

  @override
  String get coachSessionDoneSubtitle => 'Beau travail. Garde ta série en vie.';

  @override
  String coachSessionDoneToast(String name) {
    return 'Séance « $name » marquée comme faite.';
  }

  @override
  String coachSessionStreakCredited(String name) {
    return 'Séance « $name » faite — série créditée.';
  }

  @override
  String get coachSessionSyncFailed =>
      'Séance enregistrée localement. Synchro impossible : ta série n\'a pas pu être mise à jour. Réessaie quand le réseau revient.';

  @override
  String a11yHomePlayerCard(String name, int ovr, String rank) {
    return '$name, Index $ovr, rang $rank. Touchez pour voir votre progression.';
  }

  @override
  String get a11yHomeCoachCta => 'Obtenir une séance d\'entraînement du coach';

  @override
  String a11yLeaderboardRow(int position, String name, int ovr) {
    return 'Rang $position, $name, Index $ovr';
  }

  @override
  String a11yLeaderboardRowMe(int position, String name, int ovr) {
    return 'Rang $position, vous, $name, Index $ovr';
  }

  @override
  String a11yLeaderboardTab(String name) {
    return 'Ligue $name';
  }

  @override
  String a11yRevealResult(int ovr, String rank) {
    return 'Votre Index est $ovr, rang $rank';
  }

  @override
  String get a11yRevealComputing => 'Calcul de votre Index';

  @override
  String a11yOnbStep(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get a11yOnbContinue => 'Continuer vers l\'étape suivante';

  @override
  String get a11yOnbReveal => 'Révéler mon Index';

  @override
  String a11yOnbEffortToggle(String name, String state) {
    String _temp0 = intl.Intl.selectLogic(
      state,
      {
        'on': 'activé',
        'off': 'désactivé',
        'other': '',
      },
    );
    return '$name, $_temp0';
  }

  @override
  String get movementGuideButton => 'Comment faire les mouvements';

  @override
  String get movementGuideTitle => 'Comment faire les mouvements';

  @override
  String get movementGuideIntro =>
      'Petit rappel sur chaque mouvement : comment le faire, à quoi faire attention, et une version plus facile si besoin.';

  @override
  String get movementGuideHowTo => 'Comment faire';

  @override
  String get movementGuideKeyPoints => 'Points clés';

  @override
  String get movementGuideMistakes => 'Erreurs fréquentes';

  @override
  String get movementGuideEasyVersion => 'Version facile';

  @override
  String get movementGuideEmpty =>
      'Aucune fiche disponible pour les mouvements de cette séance pour l\'instant.';

  @override
  String get movementGuideEmptyGlossary =>
      'Le guide des mouvements arrive bientôt.';

  @override
  String a11yMovementCard(String name) {
    return 'Mouvement : $name. Comment faire, points clés, erreurs fréquentes et une version facile.';
  }
}
