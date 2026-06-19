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
