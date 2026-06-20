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

class Profile {
  final IndexSummary index;
  final List<RadarAttribute> radar;
  const Profile({required this.index, required this.radar});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        index: IndexSummary.fromJson(j['index'] as Map<String, dynamic>),
        radar: (j['radar'] as List<dynamic>)
            .map((e) => RadarAttribute.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
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

class Rival {
  final String state; // leader | active | none
  final int? gap;
  final String? displayName;
  final int? value;
  final int? position;
  const Rival({required this.state, this.gap, this.displayName, this.value, this.position});

  factory Rival.fromJson(Map<String, dynamic> j) {
    final r = j['rival'] as Map<String, dynamic>?;
    return Rival(
      state: j['state'] as String? ?? 'none',
      gap: (j['gap'] as num?)?.toInt(),
      displayName: r?['displayName'] as String?,
      value: (r?['value'] as num?)?.toInt(),
      position: (r?['position'] as num?)?.toInt(),
    );
  }
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
  const PublicProfile({
    required this.userId,
    required this.displayName,
    required this.sex,
    required this.goal,
    required this.rank,
    required this.index,
    required this.radar,
    required this.position,
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
