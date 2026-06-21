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
  const RadarAttribute({
    required this.attribute,
    required this.score,
    required this.unlocked,
    required this.isEstimated,
  });

  factory RadarAttribute.fromJson(Map<String, dynamic> j) => RadarAttribute(
        attribute: j['attribute'] as String,
        score: (j['score'] as num).toInt(),
        unlocked: j['unlocked'] as bool? ?? false,
        isEstimated: j['isEstimated'] as bool? ?? false,
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
  final double percentile;
  final String rank;
  final bool isProvisional;
  final bool isEstimated;
  final int radarCoverage;
  final RankProgress? rankProgress;
  const IndexSummary({
    required this.value,
    required this.percentile,
    required this.rank,
    required this.isProvisional,
    required this.isEstimated,
    required this.radarCoverage,
    this.rankProgress,
  });

  factory IndexSummary.fromJson(Map<String, dynamic> j) => IndexSummary(
        value: (j['value'] as num).toInt(),
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
  /// Renseigné quand le dernier recalcul a fait MONTER de bande population (déclenche la célébration).
  final List<String>? bandCelebration; // [from, to] où from peut être '' (null)
  const Profile({
    required this.index,
    required this.radar,
    this.socialProof,
    this.gains = const [],
    this.weakest,
    this.bandCelebration,
  });

  factory Profile.fromJson(Map<String, dynamic> j) {
    final celeb = j['bandCelebration'] as Map<String, dynamic>?;
    return Profile(
      gains: (j['gains'] as List<dynamic>?)
              ?.map((e) => AttributeGain.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      weakest: j['weakest'] as String?,
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
  final String? lastBody;
  final bool lastIsMine;
  final int unread;
  const ConversationSummary({
    required this.id,
    required this.otherUserId,
    required this.otherName,
    required this.otherRank,
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
}

class AvatarConfig {
  final int skinTone;
  final int hairStyle;
  final int hairColor;
  final int? beardStyle;
  const AvatarConfig({
    required this.skinTone,
    required this.hairStyle,
    required this.hairColor,
    this.beardStyle,
  });

  factory AvatarConfig.fromJson(Map<String, dynamic> j) => AvatarConfig(
        skinTone: (j['skinTone'] as num).toInt(),
        hairStyle: (j['hairStyle'] as num).toInt(),
        hairColor: (j['hairColor'] as num).toInt(),
        beardStyle: (j['beardStyle'] as num?)?.toInt(),
      );

  AvatarConfig copyWith({int? skinTone, int? hairStyle, int? hairColor, int? beardStyle, bool clearBeard = false}) =>
      AvatarConfig(
        skinTone: skinTone ?? this.skinTone,
        hairStyle: hairStyle ?? this.hairStyle,
        hairColor: hairColor ?? this.hairColor,
        beardStyle: clearBeard ? null : (beardStyle ?? this.beardStyle),
      );

  Map<String, dynamic> toJson() => {
        'skinTone': skinTone,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'beardStyle': beardStyle,
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

class EndgameInfo {
  final int beaten;
  final int total;
  final bool grandSlamComplete;
  final List<String> remaining;
  final int? globalRank;
  final int globalTotal;
  final bool isTop100;
  final bool ambassador;
  const EndgameInfo({
    required this.beaten,
    required this.total,
    required this.grandSlamComplete,
    required this.remaining,
    required this.globalRank,
    required this.globalTotal,
    required this.isTop100,
    required this.ambassador,
  });

  factory EndgameInfo.fromJson(Map<String, dynamic> j) {
    final gs = j['grandSlam'] as Map<String, dynamic>;
    return EndgameInfo(
      beaten: (gs['beaten'] as num).toInt(),
      total: (gs['total'] as num).toInt(),
      grandSlamComplete: gs['complete'] as bool? ?? false,
      remaining: ((gs['remaining'] as List?) ?? []).map((e) => e.toString()).toList(),
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
  const WodCatalogEntry({
    required this.id,
    required this.name,
    required this.scoreType,
    required this.requiresEquipment,
    required this.isCustom,
    this.isFlagship = false,
  });

  factory WodCatalogEntry.fromJson(Map<String, dynamic> j) => WodCatalogEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        scoreType: j['scoreType'] as String,
        requiresEquipment: j['requiresEquipment'] as bool? ?? false,
        isCustom: j['isCustom'] as bool? ?? false,
        isFlagship: j['isFlagship'] as bool? ?? false,
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
    );
  }
}

class WodLeaderboardEntry {
  final int position;
  final String userId;
  final String displayName;
  final String rank;
  final num rawResult;
  final int? subScore;
  final bool isMe;
  const WodLeaderboardEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.rank,
    required this.rawResult,
    required this.subScore,
    required this.isMe,
  });

  factory WodLeaderboardEntry.fromJson(Map<String, dynamic> j) => WodLeaderboardEntry(
        position: (j['position'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '—',
        rank: j['rank'] as String? ?? 'rookie',
        rawResult: j['rawResult'] as num,
        subScore: (j['subScore'] as num?)?.toInt(),
        isMe: j['isMe'] as bool? ?? false,
      );
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
