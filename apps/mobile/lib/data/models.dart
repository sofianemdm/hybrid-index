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

class IndexSummary {
  final int value;
  final double percentile;
  final String rank;
  final bool isProvisional;
  final bool isEstimated;
  final int radarCoverage;
  const IndexSummary({
    required this.value,
    required this.percentile,
    required this.rank,
    required this.isProvisional,
    required this.isEstimated,
    required this.radarCoverage,
  });

  factory IndexSummary.fromJson(Map<String, dynamic> j) => IndexSummary(
        value: (j['value'] as num).toInt(),
        percentile: (j['percentile'] as num).toDouble(),
        rank: j['rank'] as String,
        isProvisional: j['isProvisional'] as bool? ?? false,
        isEstimated: j['isEstimated'] as bool? ?? false,
        radarCoverage: (j['radarCoverage'] as num?)?.toInt() ?? 0,
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

class Profile {
  final IndexSummary index;
  final List<RadarAttribute> radar;
  final SocialProof? socialProof;
  /// Renseigné quand le dernier recalcul a fait MONTER de bande population (déclenche la célébration).
  final List<String>? bandCelebration; // [from, to] où from peut être '' (null)
  const Profile({required this.index, required this.radar, this.socialProof, this.bandCelebration});

  factory Profile.fromJson(Map<String, dynamic> j) {
    final celeb = j['bandCelebration'] as Map<String, dynamic>?;
    return Profile(
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
    required this.actorUserId,
    required this.actorName,
    required this.actorRank,
    required this.isMe,
    required this.payload,
    required this.reactions,
    required this.myReactions,
  });

  factory FeedActivity.fromJson(Map<String, dynamic> j) {
    final actor = j['actor'] as Map<String, dynamic>;
    final reactions = <String, int>{};
    (j['reactions'] as Map?)?.forEach((k, v) => reactions[k.toString()] = (v as num).toInt());
    return FeedActivity(
      id: j['id'] as String,
      type: j['type'] as String,
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
  const WodCatalogEntry({
    required this.id,
    required this.name,
    required this.scoreType,
    required this.requiresEquipment,
    required this.isCustom,
  });

  factory WodCatalogEntry.fromJson(Map<String, dynamic> j) => WodCatalogEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        scoreType: j['scoreType'] as String,
        requiresEquipment: j['requiresEquipment'] as bool? ?? false,
        isCustom: j['isCustom'] as bool? ?? false,
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
