// Modèles de données légers (mapping JSON de l'API). L'app ne connaît que l'`api`.

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  const AuthUser({required this.id, required this.email, required this.displayName});

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        email: j['email'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
      );
}

class RadarAttribute {
  final String attribute;
  final int score;
  final bool unlocked;
  final bool isEstimated;
  final bool isStale; // mesure ancienne (>10 sem) → « à rafraîchir »
  const RadarAttribute({
    required this.attribute,
    required this.score,
    required this.unlocked,
    required this.isEstimated,
    this.isStale = false,
  });

  factory RadarAttribute.fromJson(Map<String, dynamic> j) => RadarAttribute(
        attribute: j['attribute'] as String,
        score: (j['score'] as num).toInt(),
        unlocked: j['unlocked'] as bool? ?? false,
        isEstimated: j['isEstimated'] as bool? ?? false,
        isStale: j['isStale'] as bool? ?? false,
      );
}

/// Rival amical : l'athlète juste au-dessus dans la ligue. Ton toujours bienveillant côté UI.
class Rival {
  final String displayName;
  final String rank;
  final int ovr;
  final int position;
  final int gapPoints; // points d'Index pour le dépasser (>= 1)
  const Rival({
    required this.displayName,
    required this.rank,
    required this.ovr,
    required this.position,
    required this.gapPoints,
  });

  factory Rival.fromJson(Map<String, dynamic> j) => Rival(
        displayName: j['displayName'] as String? ?? '—',
        rank: j['rank'] as String? ?? 'rookie',
        ovr: (j['ovr'] as num?)?.toInt() ?? 0,
        position: (j['position'] as num?)?.toInt() ?? 0,
        gapPoints: (j['gapPoints'] as num?)?.toInt() ?? 1,
      );
}

/// Progression vers le rang suivant (goal-gradient). next null = rang max atteint.
class RankProgress {
  final String current;
  final String? next;
  final int? pointsToNext;
  final double progress; // 0..1
  const RankProgress({required this.current, this.next, this.pointsToNext, required this.progress});

  factory RankProgress.fromJson(Map<String, dynamic> j) => RankProgress(
        current: j['current'] as String? ?? 'rookie',
        next: j['next'] as String?,
        pointsToNext: (j['pointsToNext'] as num?)?.toInt(),
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
      );
}

/// Un point de la courbe de progression du Hybrid Index dans le temps (H3).
class IndexPoint {
  final int value;
  final String rank;
  final DateTime at;
  const IndexPoint({required this.value, required this.rank, required this.at});

  factory IndexPoint.fromJson(Map<String, dynamic> j) => IndexPoint(
        value: (j['value'] as num).toInt(),
        rank: j['rank'] as String? ?? 'rookie',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class IndexSummary {
  final int value;
  final double? rating; // OVR à 1 décimale (ex. 74.3) pour la barre de progression au point près
  final double percentile;
  final String rank;
  final bool isProvisional;
  final bool isEstimated;
  final int radarCoverage;
  final RankProgress? rankProgress;
  const IndexSummary({
    required this.value,
    this.rating,
    required this.percentile,
    required this.rank,
    required this.isProvisional,
    required this.isEstimated,
    required this.radarCoverage,
    this.rankProgress,
  });

  factory IndexSummary.fromJson(Map<String, dynamic> j) => IndexSummary(
        value: (j['value'] as num).toInt(),
        rating: (j['rating'] as num?)?.toDouble(),
        percentile: (j['percentile'] as num).toDouble(),
        rank: j['rank'] as String,
        isProvisional: j['isProvisional'] as bool? ?? false,
        isEstimated: j['isEstimated'] as bool? ?? false,
        radarCoverage: (j['radarCoverage'] as num?)?.toInt() ?? 0,
        rankProgress: j['rankProgress'] == null
            ? null
            : RankProgress.fromJson(j['rankProgress'] as Map<String, dynamic>),
      );
}

/// Preuve sociale à deux populations (cf. backend SocialProof).
class SocialProof {
  /// « Humanité » : toujours présent, toujours valorisant. topPercent null = bande « en construction ».
  final int? humanityTopPercent;
  final String populationBand;
  /// « App » : visible seulement si top 30% ET ligue ≥ 200.
  final bool appVisible;
  final int? appTopPercent;
  const SocialProof({
    this.humanityTopPercent,
    required this.populationBand,
    required this.appVisible,
    this.appTopPercent,
  });

  factory SocialProof.fromJson(Map<String, dynamic> j) {
    final pop = (j['population'] as Map<String, dynamic>?) ?? const {};
    final app = (j['app'] as Map<String, dynamic>?) ?? const {};
    return SocialProof(
      humanityTopPercent: (pop['topPercent'] as num?)?.toInt(),
      populationBand: pop['band'] as String? ?? 'pop_building',
      appVisible: app['visible'] as bool? ?? false,
      appTopPercent: (app['topPercent'] as num?)?.toInt(),
    );
  }
}

/// Gain de compétence sur un attribut au dernier log.
class AttributeGain {
  final String attribute;
  final int delta;
  const AttributeGain({required this.attribute, required this.delta});

  factory AttributeGain.fromJson(Map<String, dynamic> j) => AttributeGain(
        attribute: j['attribute'] as String,
        delta: (j['delta'] as num).toInt(),
      );
}

class Profile {
  final IndexSummary index;
  final List<RadarAttribute> radar;
  final SocialProof? socialProof;
  /// Attributs ayant progressé au dernier log (no-drop ⇒ delta > 0). Vide sur un simple GET.
  final List<AttributeGain> gains;
  /// Attribut le plus faible débloqué (point faible à cibler).
  final String? weakest;
  final int? leaguePosition; // place dans la ligue (sexe), 1 = premier
  final int? leagueTotal;
  final Rival? rival; // athlète juste au-dessus (null si leader)
  /// Renseigné quand le dernier recalcul a fait MONTER de bande population (déclenche la célébration).
  final List<String>? bandCelebration; // [from, to] où from peut être '' (null)
  const Profile({
    required this.index,
    required this.radar,
    this.socialProof,
    this.gains = const [],
    this.weakest,
    this.leaguePosition,
    this.leagueTotal,
    this.rival,
    this.bandCelebration,
  });

  factory Profile.fromJson(Map<String, dynamic> j) {
    final celeb = j['bandCelebration'] as Map<String, dynamic>?;
    return Profile(
      rival: j['rival'] == null ? null : Rival.fromJson(j['rival'] as Map<String, dynamic>),
      gains: (j['gains'] as List<dynamic>?)
              ?.map((e) => AttributeGain.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      weakest: j['weakest'] as String?,
      leaguePosition: (j['leaguePosition'] as num?)?.toInt(),
      leagueTotal: (j['leagueTotal'] as num?)?.toInt(),
      index: IndexSummary.fromJson(j['index'] as Map<String, dynamic>),
      radar: (j['radar'] as List<dynamic>)
          .map((e) => RadarAttribute.fromJson(e as Map<String, dynamic>))
          .toList(),
      socialProof: j['socialProof'] == null
          ? null
          : SocialProof.fromJson(j['socialProof'] as Map<String, dynamic>),
      bandCelebration: celeb == null
          ? null
          : [celeb['from'] as String? ?? '', celeb['to'] as String? ?? ''],
    );
  }
}

/// Messagerie privée (Phase C5).
class DmEligibility {
  final bool allowed;
  final String? reason;
  const DmEligibility({required this.allowed, this.reason});

  factory DmEligibility.fromJson(Map<String, dynamic> j) =>
      DmEligibility(allowed: j['allowed'] as bool? ?? false, reason: j['reason'] as String?);

  String get message {
    switch (reason) {
      case 'age':
        return 'Messages limités aux comptes de la même tranche d\'âge.';
      case 'blocked':
        return 'Échange impossible avec cet utilisateur.';
      case 'not_connected':
        return 'Suivez-vous mutuellement ou partagez un club pour discuter.';
      default:
        return 'Message privé indisponible.';
    }
  }
}

class DmMessage {
  final String id;
  final String senderId;
  final String body;
  final String createdAt;
  final bool isMine;
  const DmMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  factory DmMessage.fromJson(Map<String, dynamic> j) => DmMessage(
        id: j['id'] as String,
        senderId: j['senderId'] as String? ?? '',
        body: j['body'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
        isMine: j['isMine'] as bool? ?? false,
      );
}

class ConversationSummary {
  final String id;
  final String otherUserId;
  final String otherName;
  final String otherRank;
  final int? otherIndex; // OVR /100 de l'interlocuteur (grade affiché)
  final String? lastBody;
  final bool lastIsMine;
  final int unread;
  const ConversationSummary({
    required this.id,
    required this.otherUserId,
    required this.otherName,
    required this.otherRank,
    this.otherIndex,
    this.lastBody,
    required this.lastIsMine,
    required this.unread,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> j) {
    final other = (j['other'] as Map?)?.cast<String, dynamic>() ?? {};
    final last = (j['lastMessage'] as Map?)?.cast<String, dynamic>();
    return ConversationSummary(
      id: j['id'] as String,
      otherUserId: other['userId'] as String? ?? '',
      otherName: other['displayName'] as String? ?? '—',
      otherRank: other['rank'] as String? ?? 'rookie',
      otherIndex: (other['index'] as num?)?.toInt(),
      lastBody: last?['body'] as String?,
      lastIsMine: last?['isMine'] as bool? ?? false,
      unread: (j['unread'] as num?)?.toInt() ?? 0,
    );
  }
}

class Conversation {
  final String id;
  final String otherUserId;
  final String otherName;
  final String otherRank;
  final List<DmMessage> messages;
  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherName,
    required this.otherRank,
    required this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final other = (j['other'] as Map?)?.cast<String, dynamic>() ?? {};
    return Conversation(
      id: j['id'] as String,
      otherUserId: other['userId'] as String? ?? '',
      otherName: other['displayName'] as String? ?? '—',
      otherRank: other['rank'] as String? ?? 'rookie',
      messages: ((j['messages'] as List?) ?? []).map((e) => DmMessage.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Un de mes résultats de séance (pour partager une perf dans un post).
class MyResult {
  final String id;
  final String wodId;
  final String wodName;
  final String scoreType;
  final num rawResult;
  final int? subScore;
  final String performedAt;
  const MyResult({
    required this.id,
    required this.wodId,
    required this.wodName,
    required this.scoreType,
    required this.rawResult,
    this.subScore,
    required this.performedAt,
  });

  factory MyResult.fromJson(Map<String, dynamic> j) => MyResult(
        id: j['id'] as String,
        wodId: j['wodId'] as String,
        wodName: j['wodName'] as String? ?? 'Séance',
        scoreType: j['scoreType'] as String? ?? 'time',
        rawResult: (j['rawResult'] as num?) ?? 0,
        subScore: (j['subScore'] as num?)?.toInt(),
        performedAt: j['performedAt'] as String? ?? '',
      );
}

/// Clubs (Phase C) — groupe + filtre des classements (pas une nouvelle ligue).
class ClubSummary {
  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final String? role;
  const ClubSummary({required this.id, required this.name, this.description, required this.memberCount, this.role});

  factory ClubSummary.fromJson(Map<String, dynamic> j) => ClubSummary(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Club',
        description: j['description'] as String?,
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
        role: j['role'] as String?,
      );
}

class ClubRosterEntry {
  final int position;
  final String userId;
  final String displayName;
  final String rank;
  final int index;
  final String role;
  final bool isMe;
  const ClubRosterEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.rank,
    required this.index,
    required this.role,
    required this.isMe,
  });

  factory ClubRosterEntry.fromJson(Map<String, dynamic> j) => ClubRosterEntry(
        position: (j['position'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '—',
        rank: j['rank'] as String? ?? 'rookie',
        index: (j['index'] as num?)?.toInt() ?? 0,
        role: j['role'] as String? ?? 'member',
        isMe: j['isMe'] as bool? ?? false,
      );
}

class ClubDetail {
  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final bool isMember;
  final bool isOwner;
  final List<ClubRosterEntry> roster;
  const ClubDetail({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    required this.isMember,
    required this.isOwner,
    required this.roster,
  });

  factory ClubDetail.fromJson(Map<String, dynamic> j) => ClubDetail(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Club',
        description: j['description'] as String?,
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
        isMember: j['isMember'] as bool? ?? false,
        isOwner: j['isOwner'] as bool? ?? false,
        roster: (j['roster'] as List<dynamic>? ?? [])
            .map((e) => ClubRosterEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ClubInvite {
  final String inviteId;
  final String clubId;
  final String clubName;
  final int memberCount;
  const ClubInvite({required this.inviteId, required this.clubId, required this.clubName, required this.memberCount});

  factory ClubInvite.fromJson(Map<String, dynamic> j) => ClubInvite(
        inviteId: j['inviteId'] as String,
        clubId: j['clubId'] as String,
        clubName: j['clubName'] as String? ?? 'Club',
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
      );
}

/// Classement de PROGRESSION hebdomadaire (par effort) — distinct du classement Index.
class ProgressEntry {
  final int position;
  final String userId;
  final String displayName;
  final String rank;
  final int ep;
  final bool isMe;
  const ProgressEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.rank,
    required this.ep,
    required this.isMe,
  });

  factory ProgressEntry.fromJson(Map<String, dynamic> j) => ProgressEntry(
        position: (j['position'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '—',
        rank: j['rank'] as String? ?? 'rookie',
        ep: (j['ep'] as num).toInt(),
        isMe: j['isMe'] as bool? ?? false,
      );
}

class ProgressBoard {
  final String weekKey;
  final int total;
  final int? myPosition;
  final int? myEp;
  final List<ProgressEntry> entries;
  const ProgressBoard({required this.weekKey, required this.total, this.myPosition, this.myEp, required this.entries});

  factory ProgressBoard.fromJson(Map<String, dynamic> j) {
    final me = j['me'] as Map<String, dynamic>?;
    return ProgressBoard(
      weekKey: j['weekKey'] as String? ?? '',
      total: (j['total'] as num?)?.toInt() ?? 0,
      myPosition: (me?['position'] as num?)?.toInt(),
      myEp: (me?['ep'] as num?)?.toInt(),
      entries: (j['entries'] as List<dynamic>? ?? [])
          .map((e) => ProgressEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LeaderboardEntry {
  final int position;
  final String userId;
  final String displayName;
  final int value;
  final String rank;
  final bool isMe;
  const LeaderboardEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.value,
    required this.rank,
    required this.isMe,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        position: (j['position'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '—',
        value: (j['value'] as num).toInt(),
        rank: j['rank'] as String? ?? 'rookie',
        isMe: j['isMe'] as bool? ?? false,
      );
}

class Leaderboard {
  final String sex;
  final int total;
  final List<LeaderboardEntry> entries;
  final int? myPosition;
  const Leaderboard({required this.sex, required this.total, required this.entries, this.myPosition});

  factory Leaderboard.fromJson(Map<String, dynamic> j) => Leaderboard(
        sex: j['sex'] as String,
        total: (j['total'] as num).toInt(),
        entries: (j['entries'] as List<dynamic>)
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        myPosition: j['me'] == null ? null : ((j['me'] as Map<String, dynamic>)['position'] as num).toInt(),
      );
}

class CoachSession {
  final String id;
  final String name;
  final String primaryAttribute;
  final bool requiresEquipment;
  final int durationMin;
  final String intensity;
  final String description;
  const CoachSession({
    required this.id,
    required this.name,
    required this.primaryAttribute,
    required this.requiresEquipment,
    required this.durationMin,
    required this.intensity,
    required this.description,
  });

  factory CoachSession.fromJson(Map<String, dynamic> j) => CoachSession(
        id: j['id'] as String,
        name: j['name'] as String,
        primaryAttribute: j['primaryAttribute'] as String,
        requiresEquipment: j['requiresEquipment'] as bool? ?? false,
        durationMin: (j['durationMin'] as num).toInt(),
        intensity: j['intensity'] as String,
        description: j['description'] as String,
      );
}

class CoachResult {
  final String targetAttribute;
  final int current;
  final int projected;
  final int delta;
  final int targetScore;
  final List<CoachSession> sessions;
  const CoachResult({
    required this.targetAttribute,
    required this.current,
    required this.projected,
    required this.delta,
    required this.targetScore,
    required this.sessions,
  });

  factory CoachResult.fromJson(Map<String, dynamic> j) {
    final p = j['projection'] as Map<String, dynamic>;
    return CoachResult(
      targetAttribute: j['targetAttribute'] as String,
      current: (p['current'] as num).toInt(),
      projected: (p['projected'] as num).toInt(),
      delta: (p['delta'] as num).toInt(),
      targetScore: (p['targetScore'] as num).toInt(),
      sessions: (j['sessions'] as List<dynamic>)
          .map((e) => CoachSession.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PublicProfile {
  final String userId;
  final String displayName;
  final String sex;
  final String goal;
  final String rank;
  final IndexSummary? index;
  final List<RadarAttribute> radar;
  final int? position;
  final bool isFollowing;
  final bool isMe;
  final bool isConfirmed;
  final AvatarConfig? avatar; // avatar évolutif visible sur le profil public (IC-03)
  final List<String> activeCosmetics; // cosmétiques débloqués (auras/couronne)
  const PublicProfile({
    required this.userId,
    required this.displayName,
    required this.sex,
    required this.goal,
    required this.rank,
    required this.index,
    required this.radar,
    required this.position,
    required this.isFollowing,
    required this.isMe,
    this.isConfirmed = false,
    this.avatar,
    this.activeCosmetics = const [],
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '—',
        sex: j['sex'] as String,
        goal: j['goal'] as String,
        rank: j['rank'] as String,
        index: j['index'] == null ? null : IndexSummary.fromJson(j['index'] as Map<String, dynamic>),
        radar: (j['radar'] as List<dynamic>? ?? [])
            .map((e) => RadarAttribute.fromJson(e as Map<String, dynamic>))
            .toList(),
        position: (j['position'] as num?)?.toInt(),
        isFollowing: j['isFollowing'] as bool? ?? false,
        isMe: j['isMe'] as bool? ?? false,
        isConfirmed: j['isConfirmed'] as bool? ?? false,
        avatar: j['avatar'] == null ? null : AvatarConfig.fromJson(j['avatar'] as Map<String, dynamic>),
        activeCosmetics: ((j['activeCosmetics'] as List?) ?? const []).map((e) => e as String).toList(),
      );
}

class StreakState {
  final int current;
  final int best;
  final int weeklyGoal;
  final int freezeTokens;
  final int thisWeekCount;
  final bool weekValidated;
  const StreakState({
    required this.current,
    required this.best,
    required this.weeklyGoal,
    required this.freezeTokens,
    required this.thisWeekCount,
    required this.weekValidated,
  });

  factory StreakState.fromJson(Map<String, dynamic> j) => StreakState(
        current: (j['current'] as num).toInt(),
        best: (j['best'] as num).toInt(),
        weeklyGoal: (j['weeklyGoal'] as num).toInt(),
        freezeTokens: (j['freezeTokens'] as num).toInt(),
        thisWeekCount: (j['thisWeekCount'] as num).toInt(),
        weekValidated: j['weekValidated'] as bool? ?? false,
      );
}

/// Récap de la semaine en cours (séances, gain d'Index, série).
class WeeklyRecap {
  final int sessions;
  final int? indexNow;
  final int deltaIndex;
  final int streakCurrent;
  final bool weekValidated;
  const WeeklyRecap({
    required this.sessions,
    required this.indexNow,
    required this.deltaIndex,
    required this.streakCurrent,
    required this.weekValidated,
  });

  factory WeeklyRecap.fromJson(Map<String, dynamic> j) => WeeklyRecap(
        sessions: (j['sessions'] as num?)?.toInt() ?? 0,
        indexNow: (j['indexNow'] as num?)?.toInt(),
        deltaIndex: (j['deltaIndex'] as num?)?.toInt() ?? 0,
        streakCurrent: (j['streakCurrent'] as num?)?.toInt() ?? 0,
        weekValidated: j['weekValidated'] as bool? ?? false,
      );

  /// Y a-t-il quelque chose à montrer (évite une carte vide en début de semaine) ?
  bool get hasContent => sessions > 0 || deltaIndex > 0;
}

class BadgeModel {
  final String id;
  final String category;
  final String name;
  final String description;
  final String rarity;
  final bool unlocked;
  const BadgeModel({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.rarity,
    required this.unlocked,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> j) => BadgeModel(
        id: j['id'] as String,
        category: j['category'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        rarity: j['rarity'] as String,
        unlocked: j['unlocked'] as bool? ?? false,
      );

  /// Série progressive à laquelle ce badge appartient (sinon null = badge isolé).
  /// L'app n'affiche, par série, que le palier atteint + le palier suivant.
  String? get series {
    if (id.startsWith('index-')) return 'index';
    if (id.startsWith('rank-')) return 'rank';
    if (id.startsWith('top-')) return 'league';
    if (id.startsWith('humanity-')) return 'humanity';
    return null;
  }

  /// Rang du palier dans sa série (croissant = plus difficile).
  int get seriesOrder {
    if (id.startsWith('index-')) return int.tryParse(id.substring(6)) ?? 0;
    if (id.startsWith('rank-')) {
      const order = {'rookie': 0, 'bronze': 1, 'silver': 2, 'gold': 3, 'platinum': 4, 'diamond': 5, 'elite': 6};
      return order[id.substring(5)] ?? 0;
    }
    // league (top-50→25→5→1) & humanity (25→…→1) : plus le % est petit, plus c'est élevé.
    if (id.startsWith('top-')) return 100 - (int.tryParse(id.substring(4)) ?? 100);
    if (id.startsWith('humanity-')) return 100 - (int.tryParse(id.substring(9)) ?? 100);
    return 0;
  }
}

class AvatarConfig {
  final int skinTone;
  final int hairStyle;
  final int hairColor;
  final int? beardStyle;
  final int accessory;
  final int background;

  /// Photo de profil (data URL base64). Si présente, elle remplace l'avatar dessiné.
  final String? photoData;
  final String? diceStyle; // DiceBear : style (null = avatar dessiné)
  final String? diceSeed; // DiceBear : seed
  const AvatarConfig({
    required this.skinTone,
    required this.hairStyle,
    required this.hairColor,
    this.beardStyle,
    this.accessory = 0,
    this.background = 0,
    this.photoData,
    this.diceStyle,
    this.diceSeed,
  });

  factory AvatarConfig.fromJson(Map<String, dynamic> j) => AvatarConfig(
        skinTone: (j['skinTone'] as num).toInt(),
        hairStyle: (j['hairStyle'] as num).toInt(),
        hairColor: (j['hairColor'] as num).toInt(),
        beardStyle: (j['beardStyle'] as num?)?.toInt(),
        accessory: (j['accessory'] as num?)?.toInt() ?? 0,
        background: (j['background'] as num?)?.toInt() ?? 0,
        photoData: j['photoData'] as String?,
        diceStyle: j['diceStyle'] as String?,
        diceSeed: j['diceSeed'] as String?,
      );

  AvatarConfig copyWith({
    int? skinTone,
    int? hairStyle,
    int? hairColor,
    int? beardStyle,
    bool clearBeard = false,
    int? accessory,
    int? background,
    String? photoData,
    bool clearPhoto = false,
    String? diceStyle,
    String? diceSeed,
  }) =>
      AvatarConfig(
        skinTone: skinTone ?? this.skinTone,
        hairStyle: hairStyle ?? this.hairStyle,
        hairColor: hairColor ?? this.hairColor,
        beardStyle: clearBeard ? null : (beardStyle ?? this.beardStyle),
        accessory: accessory ?? this.accessory,
        background: background ?? this.background,
        photoData: clearPhoto ? null : (photoData ?? this.photoData),
        diceStyle: diceStyle ?? this.diceStyle,
        diceSeed: diceSeed ?? this.diceSeed,
      );

  Map<String, dynamic> toJson() => {
        'skinTone': skinTone,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'beardStyle': beardStyle,
        'accessory': accessory,
        'background': background,
        'photoData': photoData,
        'diceStyle': diceStyle,
        'diceSeed': diceSeed,
      };
}

class FeedItem {
  final String key;
  final String title;
  final String body;
  final String priority;
  const FeedItem({required this.key, required this.title, required this.body, required this.priority});

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
        key: j['key'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        priority: j['priority'] as String? ?? 'medium',
      );
}

class WodResultItem {
  final String id;
  final String wodId;
  final double rawResult;
  final int? subScore;
  final DateTime performedAt;
  const WodResultItem({
    required this.id,
    required this.wodId,
    required this.rawResult,
    required this.subScore,
    required this.performedAt,
  });

  factory WodResultItem.fromJson(Map<String, dynamic> j) => WodResultItem(
        id: j['id'] as String,
        wodId: j['wodId'] as String,
        rawResult: (j['rawResult'] as num).toDouble(),
        subScore: (j['subScore'] as num?)?.toInt(),
        performedAt: DateTime.parse(j['performedAt'] as String),
      );
}

class SlamFlagship {
  final String wodId;
  final String name;
  final bool done;
  final int? score; // /100
  const SlamFlagship({required this.wodId, required this.name, required this.done, this.score});

  factory SlamFlagship.fromJson(Map<String, dynamic> j) => SlamFlagship(
        wodId: j['wodId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        score: (j['score'] as num?)?.toInt(),
      );
}

class EndgameInfo {
  final String tier; // none | bronze | silver | gold
  final int completed;
  final int total;
  final int minScore;
  final int silverMin;
  final int goldMin;
  final List<SlamFlagship> flagship;
  final int? globalRank;
  final int globalTotal;
  final bool isTop100;
  final bool ambassador;
  const EndgameInfo({
    required this.tier,
    required this.completed,
    required this.total,
    required this.minScore,
    required this.silverMin,
    required this.goldMin,
    required this.flagship,
    required this.globalRank,
    required this.globalTotal,
    required this.isTop100,
    required this.ambassador,
  });

  factory EndgameInfo.fromJson(Map<String, dynamic> j) {
    final gs = j['grandSlam'] as Map<String, dynamic>;
    final thr = (gs['thresholds'] as Map?)?.cast<String, dynamic>() ?? {};
    return EndgameInfo(
      tier: gs['tier'] as String? ?? 'none',
      completed: (gs['completed'] as num?)?.toInt() ?? 0,
      total: (gs['total'] as num?)?.toInt() ?? 4,
      minScore: (gs['minScore'] as num?)?.toInt() ?? 0,
      silverMin: (thr['silver'] as num?)?.toInt() ?? 75,
      goldMin: (thr['gold'] as num?)?.toInt() ?? 90,
      flagship: ((gs['flagship'] as List?) ?? [])
          .map((e) => SlamFlagship.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      globalRank: (j['globalRank'] as num?)?.toInt(),
      globalTotal: (j['globalTotal'] as num?)?.toInt() ?? 0,
      isTop100: j['isTop100'] as bool? ?? false,
      ambassador: j['ambassador'] as bool? ?? false,
    );
  }
}

class FeedActivity {
  final String id;
  final String type;

  /// 'event' (activité auto : PR, séance…) ou 'post' (message authored par un athlète).
  final String source;
  final String actorUserId;
  final String actorName;
  final String actorRank;
  final int? actorIndex; // OVR /100 de l'acteur (grade affiché)
  final bool isMe;
  final Map<String, dynamic> payload;
  final Map<String, int> reactions;
  final List<String> myReactions;
  const FeedActivity({
    required this.id,
    required this.type,
    required this.source,
    required this.actorUserId,
    required this.actorName,
    required this.actorRank,
    this.actorIndex,
    required this.isMe,
    required this.payload,
    required this.reactions,
    required this.myReactions,
  });

  bool get isPost => source == 'post';

  factory FeedActivity.fromJson(Map<String, dynamic> j) {
    final actor = j['actor'] as Map<String, dynamic>;
    final reactions = <String, int>{};
    (j['reactions'] as Map?)?.forEach((k, v) => reactions[k.toString()] = (v as num).toInt());
    return FeedActivity(
      id: j['id'] as String,
      type: j['type'] as String,
      source: j['source'] as String? ?? 'event',
      actorUserId: actor['userId'] as String,
      actorName: actor['displayName'] as String? ?? '—',
      actorRank: actor['rank'] as String? ?? 'rookie',
      actorIndex: (actor['index'] as num?)?.toInt(),
      isMe: actor['isMe'] as bool? ?? false,
      payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? {},
      reactions: reactions,
      myReactions: ((j['myReactions'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class AthleteSummary {
  final String userId;
  final String displayName;
  final String sex;
  final String goal;
  final String rank;
  final int? index;
  const AthleteSummary({
    required this.userId,
    required this.displayName,
    required this.sex,
    required this.goal,
    required this.rank,
    required this.index,
  });
  factory AthleteSummary.fromJson(Map<String, dynamic> j) => AthleteSummary(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '—',
        sex: j['sex'] as String? ?? 'male',
        goal: j['goal'] as String? ?? 'all_round',
        rank: j['rank'] as String? ?? 'rookie',
        index: (j['index'] as num?)?.toInt(),
      );
}

class MovementSummary {
  final String id;
  final String name;
  final String category;
  final String unit;
  final bool requiresEquipment;
  const MovementSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.requiresEquipment,
  });
  factory MovementSummary.fromJson(Map<String, dynamic> j) => MovementSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        unit: j['unit'] as String,
        requiresEquipment: j['requiresEquipment'] as bool? ?? false,
      );
}

class EstimateRef {
  final String level;
  final num rawResult;
  const EstimateRef({required this.level, required this.rawResult});
  factory EstimateRef.fromJson(Map<String, dynamic> j) =>
      EstimateRef(level: j['level'] as String, rawResult: j['rawResult'] as num);
}

class EstimateResult {
  final int? subScore;
  final List<EstimateRef> references;
  final String confidence;
  final List<String> attributesAffected;
  const EstimateResult({
    required this.subScore,
    required this.references,
    required this.confidence,
    required this.attributesAffected,
  });
  factory EstimateResult.fromJson(Map<String, dynamic> j) => EstimateResult(
        subScore: (j['subScore'] as num?)?.toInt(),
        references: ((j['references'] as List?) ?? []).map((e) => EstimateRef.fromJson(e as Map<String, dynamic>)).toList(),
        confidence: j['confidence'] as String? ?? 'estimated',
        attributesAffected: ((j['attributesAffected'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
  EstimateRef? ref(String level) {
    for (final r in references) {
      if (r.level == level) return r;
    }
    return null;
  }
}

class WodCatalogEntry {
  final String id;
  final String name;
  final String scoreType;
  final bool requiresEquipment;
  final bool isCustom;
  final bool isFlagship;
  final bool isOther;
  const WodCatalogEntry({
    required this.id,
    required this.name,
    required this.scoreType,
    required this.requiresEquipment,
    required this.isCustom,
    this.isFlagship = false,
    this.isOther = false,
  });

  factory WodCatalogEntry.fromJson(Map<String, dynamic> j) => WodCatalogEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        scoreType: j['scoreType'] as String,
        requiresEquipment: j['requiresEquipment'] as bool? ?? false,
        isCustom: j['isCustom'] as bool? ?? false,
        isFlagship: j['isFlagship'] as bool? ?? false,
        isOther: j['isOther'] as bool? ?? false,
      );
}

class WodTriple {
  final num champion;
  final num intermediate;
  final num occasional;
  const WodTriple({required this.champion, required this.intermediate, required this.occasional});
  factory WodTriple.fromJson(Map<String, dynamic> j) =>
      WodTriple(champion: j['champion'] as num, intermediate: j['intermediate'] as num, occasional: j['occasional'] as num);
}

/// Une ligne de l'énoncé : un mouvement avec son schéma de reps/distance.
class WodBlock {
  final String reps;
  final String movement;
  final String? detail;
  const WodBlock({required this.reps, required this.movement, this.detail});

  factory WodBlock.fromJson(Map<String, dynamic> j) => WodBlock(
        reps: j['reps'] as String? ?? '',
        movement: j['movement'] as String? ?? '',
        detail: j['detail'] as String?,
      );
}

/// Charge d'un mouvement : RX (standard) + version allégée, par sexe.
class WodWeight {
  final String movement;
  final num rxMale;
  final num rxFemale;
  final num scaledMale;
  final num scaledFemale;
  final String unit;
  final String? note;
  const WodWeight({
    required this.movement,
    required this.rxMale,
    required this.rxFemale,
    required this.scaledMale,
    required this.scaledFemale,
    required this.unit,
    this.note,
  });

  num rx(String sex) => sex == 'female' ? rxFemale : rxMale;
  num scaled(String sex) => sex == 'female' ? scaledFemale : scaledMale;

  factory WodWeight.fromJson(Map<String, dynamic> j) => WodWeight(
        movement: j['movement'] as String? ?? '',
        rxMale: (j['rxMale'] as num?) ?? 0,
        rxFemale: (j['rxFemale'] as num?) ?? 0,
        scaledMale: (j['scaledMale'] as num?) ?? 0,
        scaledFemale: (j['scaledFemale'] as num?) ?? 0,
        unit: j['unit'] as String? ?? 'kg',
        note: j['note'] as String?,
      );
}

/// Prescription concrète d'une séance : « ce que c'est » + « ce que tu dois faire ».
class WodPrescription {
  final String? summary;
  final String format;
  final int? timeCapSec;
  final List<WodBlock> blocks;
  final List<WodWeight> weights;
  final String scoringNote;
  const WodPrescription({
    this.summary,
    required this.format,
    this.timeCapSec,
    required this.blocks,
    required this.weights,
    required this.scoringNote,
  });

  factory WodPrescription.fromJson(Map<String, dynamic> j) => WodPrescription(
        summary: j['summary'] as String?,
        format: j['format'] as String? ?? '',
        timeCapSec: (j['timeCapSec'] as num?)?.toInt(),
        blocks: ((j['blocks'] as List?) ?? [])
            .map((e) => WodBlock.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        weights: ((j['weights'] as List?) ?? [])
            .map((e) => WodWeight.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        scoringNote: j['scoringNote'] as String? ?? '',
      );
}

/// Une de mes prestations passées sur une séance (historique de la fiche WOD).
class WodHistoryEntry {
  final num rawResult;
  final int? subScore;
  final bool rxCompliant;
  final String performedAt;
  const WodHistoryEntry({
    required this.rawResult,
    this.subScore,
    required this.rxCompliant,
    required this.performedAt,
  });

  factory WodHistoryEntry.fromJson(Map<String, dynamic> j) => WodHistoryEntry(
        rawResult: (j['rawResult'] as num?) ?? 0,
        subScore: (j['subScore'] as num?)?.toInt(),
        rxCompliant: j['rxCompliant'] as bool? ?? true,
        performedAt: j['performedAt'] as String? ?? '',
      );
}

/// Défi de la semaine : un WOD imposé qui change chaque semaine.
class WeeklyChallenge {
  final String weekKey;
  final String theme;
  final String wodId;
  final String wodName;
  final String scoreType;
  final bool isFlagship;
  final String endsAt;
  final WodPrescription? prescription;
  const WeeklyChallenge({
    required this.weekKey,
    required this.theme,
    required this.wodId,
    required this.wodName,
    required this.scoreType,
    required this.isFlagship,
    required this.endsAt,
    this.prescription,
  });

  factory WeeklyChallenge.fromJson(Map<String, dynamic> j) => WeeklyChallenge(
        weekKey: j['weekKey'] as String? ?? '',
        theme: j['theme'] as String? ?? '',
        wodId: j['wodId'] as String? ?? '',
        wodName: j['wodName'] as String? ?? 'Séance',
        scoreType: j['scoreType'] as String? ?? 'time',
        isFlagship: j['isFlagship'] as bool? ?? false,
        endsAt: j['endsAt'] as String? ?? '',
        prescription: j['prescription'] == null
            ? null
            : WodPrescription.fromJson((j['prescription'] as Map).cast<String, dynamic>()),
      );
}

/// Épreuve réelle « Autre » (HYROX, WOD de compét, course) + vrais temps pros sourcés.
class OtherRef {
  final String athlete;
  final String sex;
  final String note;
  final String source;
  const OtherRef({required this.athlete, required this.sex, required this.note, required this.source});

  factory OtherRef.fromJson(Map<String, dynamic> j) => OtherRef(
        athlete: j['athlete'] as String? ?? '',
        sex: j['sex'] as String? ?? 'male',
        note: j['note'] as String? ?? '',
        source: j['source'] as String? ?? '',
      );
}

class OtherWorkout {
  final String id;
  final String name;
  final String category; // hyrox | crossfit | course
  final String format;
  final String description;
  final List<OtherRef> records;
  const OtherWorkout({
    required this.id,
    required this.name,
    required this.category,
    required this.format,
    required this.description,
    required this.records,
  });

  factory OtherWorkout.fromJson(Map<String, dynamic> j) => OtherWorkout(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? 'crossfit',
        format: j['format'] as String? ?? '',
        description: j['description'] as String? ?? '',
        records: ((j['records'] as List?) ?? [])
            .map((e) => OtherRef.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Cible « Référence Pro » (donnée publique) à viser sur une séance.
class WodReference {
  final String tier; // 'record' | 'elite'
  final String sex;
  final String? athlete;
  final num result;
  final String note;
  final String? source;
  const WodReference({
    required this.tier,
    required this.sex,
    this.athlete,
    required this.result,
    required this.note,
    this.source,
  });

  factory WodReference.fromJson(Map<String, dynamic> j) => WodReference(
        tier: j['tier'] as String? ?? 'elite',
        sex: j['sex'] as String? ?? 'male',
        athlete: j['athlete'] as String?,
        result: (j['result'] as num?) ?? 0,
        note: j['note'] as String? ?? '',
        source: j['source'] as String?,
      );
}

class WodDetail {
  final String id;
  final String name;
  final String scoreType;
  final bool requiresEquipment;
  final List<String> targetAttributes;
  final WodTriple? male;
  final WodTriple? female;
  final num? myBestRaw;
  final int? myBestSubScore;

  /// Énoncé concret de la séance (mouvements + poids). Null pour les WODs custom.
  final WodPrescription? prescription;

  /// Mes prestations passées sur cette séance (récent → ancien).
  final List<WodHistoryEntry> myHistory;

  /// Cibles « Référence Pro » (données publiques) à viser.
  final List<WodReference> references;
  const WodDetail({
    required this.id,
    required this.name,
    required this.scoreType,
    required this.requiresEquipment,
    required this.targetAttributes,
    required this.male,
    required this.female,
    required this.myBestRaw,
    required this.myBestSubScore,
    this.prescription,
    this.myHistory = const [],
    this.references = const [],
  });

  WodTriple? levels(String sex) => sex == 'female' ? female : male;

  factory WodDetail.fromJson(Map<String, dynamic> j) {
    final levels = j['levels'] as Map<String, dynamic>?;
    final best = j['myBest'] as Map<String, dynamic>?;
    return WodDetail(
      id: j['id'] as String,
      name: j['name'] as String,
      scoreType: j['scoreType'] as String,
      requiresEquipment: j['requiresEquipment'] as bool? ?? false,
      targetAttributes: ((j['targetAttributes'] as List?) ?? []).map((e) => e.toString()).toList(),
      male: levels == null ? null : WodTriple.fromJson(levels['male'] as Map<String, dynamic>),
      female: levels == null ? null : WodTriple.fromJson(levels['female'] as Map<String, dynamic>),
      myBestRaw: best?['rawResult'] as num?,
      myBestSubScore: (best?['subScore'] as num?)?.toInt(),
      prescription: j['prescription'] == null
          ? null
          : WodPrescription.fromJson((j['prescription'] as Map).cast<String, dynamic>()),
      myHistory: ((j['myHistory'] as List?) ?? [])
          .map((e) => WodHistoryEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      references: ((j['references'] as List?) ?? [])
          .map((e) => WodReference.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class WodLeaderboardEntry {
  final int position;
  final String userId;
  final String displayName;
  final String rank;
  final int? index; // OVR /100 global de l'athlète (grade affiché)
  final num rawResult;
  final int? subScore;
  final bool isMe;
  const WodLeaderboardEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.rank,
    this.index,
    required this.rawResult,
    required this.subScore,
    required this.isMe,
  });

  factory WodLeaderboardEntry.fromJson(Map<String, dynamic> j) => WodLeaderboardEntry(
        position: (j['position'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '—',
        rank: j['rank'] as String? ?? 'rookie',
        index: (j['index'] as num?)?.toInt(),
        rawResult: j['rawResult'] as num,
        subScore: (j['subScore'] as num?)?.toInt(),
        isMe: j['isMe'] as bool? ?? false,
      );
}

/// Classement d'un WOD : top N + « ma position » (même hors top 100, UX-05/06).
class WodLeaderboard {
  final List<WodLeaderboardEntry> entries;
  final ({int position, num rawResult, int? subScore})? me;
  const WodLeaderboard({required this.entries, this.me});

  factory WodLeaderboard.fromJson(Map<String, dynamic> j) {
    final m = j['me'] as Map<String, dynamic>?;
    return WodLeaderboard(
      entries: ((j['entries'] as List?) ?? []).map((e) => WodLeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList(),
      me: m == null
          ? null
          : (position: (m['position'] as num).toInt(), rawResult: m['rawResult'] as num, subScore: (m['subScore'] as num?)?.toInt()),
    );
  }

  /// Vrai si je suis déjà visible dans le top affiché (inutile d'épingler).
  bool get meInEntries => entries.any((e) => e.isMe);
}

/// WOD du catalogue (sous-ensemble utile au log).
class WodCatalogItem {
  final String id;
  final String name;
  final String scoreType; // time | reps | load | distance
  final bool requiresEquipment;
  const WodCatalogItem({
    required this.id,
    required this.name,
    required this.scoreType,
    required this.requiresEquipment,
  });
}

/// Plan pour compléter l'Index : séances minimales couvrant les attributs non débloqués.
class CompletionPlan {
  final List<String> missing; // attributs encore non mesurés
  final List<CompletionSession> sessions;
  const CompletionPlan({required this.missing, required this.sessions});

  factory CompletionPlan.fromJson(Map<String, dynamic> j) => CompletionPlan(
        missing: (j['missing'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        sessions: (j['sessions'] as List<dynamic>? ?? [])
            .map((e) => CompletionSession.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CompletionSession {
  final String wodId;
  final String name;
  final bool requiresEquipment;
  final List<String> covers; // attributs manquants couverts par cette séance
  const CompletionSession({required this.wodId, required this.name, required this.requiresEquipment, required this.covers});

  factory CompletionSession.fromJson(Map<String, dynamic> j) => CompletionSession(
        wodId: j['wodId'] as String,
        name: j['name'] as String,
        requiresEquipment: j['requiresEquipment'] as bool? ?? false,
        covers: (j['covers'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      );
}

// ----------------------------- Mode Ligue (saison mensuelle opt-in, séparée de l'Index) -----------------------------

class LeagueWeekInfo {
  final int weekIndex;
  final String weekKey;
  final String wodId;
  final String wodName;
  final DateTime opensAt;
  final DateTime closesAt;
  const LeagueWeekInfo({
    required this.weekIndex,
    required this.weekKey,
    required this.wodId,
    required this.wodName,
    required this.opensAt,
    required this.closesAt,
  });

  factory LeagueWeekInfo.fromJson(Map<String, dynamic> j) => LeagueWeekInfo(
        weekIndex: (j['weekIndex'] as num).toInt(),
        weekKey: j['weekKey'] as String,
        wodId: j['wodId'] as String,
        wodName: j['wodName'] as String? ?? j['wodId'] as String,
        opensAt: DateTime.parse(j['opensAt'] as String),
        closesAt: DateTime.parse(j['closesAt'] as String),
      );
}

class LeagueSeason {
  final String monthKey;
  final String status;
  final int divisionTier;
  final DateTime opensAt;
  final DateTime closesAt;
  final LeagueWeekInfo? currentWeek;
  final bool enrolled;
  const LeagueSeason({
    required this.monthKey,
    required this.status,
    required this.divisionTier,
    required this.opensAt,
    required this.closesAt,
    this.currentWeek,
    required this.enrolled,
  });

  factory LeagueSeason.fromJson(Map<String, dynamic> j) => LeagueSeason(
        monthKey: j['monthKey'] as String,
        status: j['status'] as String? ?? 'active',
        divisionTier: (j['divisionTier'] as num?)?.toInt() ?? 1,
        opensAt: DateTime.parse(j['opensAt'] as String),
        closesAt: DateTime.parse(j['closesAt'] as String),
        currentWeek: j['currentWeek'] == null
            ? null
            : LeagueWeekInfo.fromJson(Map<String, dynamic>.from(j['currentWeek'] as Map)),
        enrolled: j['enrolled'] as bool? ?? false,
      );
}

class LeagueStandingEntry {
  final int position;
  final String userId;
  final String displayName;
  final int points;
  final bool isMe;
  const LeagueStandingEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.points,
    required this.isMe,
  });

  factory LeagueStandingEntry.fromJson(Map<String, dynamic> j) => LeagueStandingEntry(
        position: (j['position'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '—',
        points: (j['points'] as num).toInt(),
        isMe: j['isMe'] as bool? ?? false,
      );
}

class LeagueStandings {
  final String? monthKey;
  final String sex;
  final int total;
  final List<LeagueStandingEntry> entries;
  final int? myPosition;
  final int? myPoints;
  const LeagueStandings({
    this.monthKey,
    required this.sex,
    required this.total,
    required this.entries,
    this.myPosition,
    this.myPoints,
  });

  factory LeagueStandings.fromJson(Map<String, dynamic> j) {
    final me = j['me'] as Map<String, dynamic>?;
    return LeagueStandings(
      monthKey: j['monthKey'] as String?,
      sex: j['sex'] as String? ?? 'male',
      total: (j['total'] as num?)?.toInt() ?? 0,
      entries: (j['entries'] as List<dynamic>? ?? const [])
          .map((e) => LeagueStandingEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      myPosition: me == null ? null : (me['position'] as num?)?.toInt(),
      myPoints: me == null ? null : (me['points'] as num?)?.toInt(),
    );
  }
}

class LeagueMe {
  final bool enrolled;
  final String? monthKey;
  final int points;
  final int? position;
  final int weeksPlayed;
  const LeagueMe({
    required this.enrolled,
    this.monthKey,
    required this.points,
    this.position,
    required this.weeksPlayed,
  });

  factory LeagueMe.fromJson(Map<String, dynamic> j) => LeagueMe(
        enrolled: j['enrolled'] as bool? ?? false,
        monthKey: j['monthKey'] as String?,
        points: (j['points'] as num?)?.toInt() ?? 0,
        position: (j['position'] as num?)?.toInt(),
        weeksPlayed: (j['weeksPlayed'] as num?)?.toInt() ?? 0,
      );
}

class PrItem {
  final String wodId;
  final String wodName;
  final String scoreType;
  final num rawResult;
  final int subScore; // /100
  final DateTime performedAt;
  const PrItem({
    required this.wodId,
    required this.wodName,
    required this.scoreType,
    required this.rawResult,
    required this.subScore,
    required this.performedAt,
  });

  factory PrItem.fromJson(Map<String, dynamic> j) => PrItem(
        wodId: j['wodId'] as String,
        wodName: j['wodName'] as String? ?? j['wodId'] as String,
        scoreType: j['scoreType'] as String? ?? 'time',
        rawResult: j['rawResult'] as num,
        subScore: (j['subScore'] as num?)?.toInt() ?? 0,
        performedAt: DateTime.parse(j['performedAt'] as String),
      );
}
