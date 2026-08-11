// ── Spotlight player (top-N slot) ─────────────────────────────────────────────

class SpotlightPlayer {
  final String playerId;
  final String? userId;
  final String playerName;
  final int goals;
  final int assists;
  final int mvpCount;
  final int matchCount;
  final double winRate; // 0–1 fraction
  final bool isGoalkeeper;

  const SpotlightPlayer({
    required this.playerId,
    this.userId,
    required this.playerName,
    this.goals = 0,
    this.assists = 0,
    this.mvpCount = 0,
    this.matchCount = 0,
    this.winRate = 0,
    this.isGoalkeeper = false,
  });

  factory SpotlightPlayer.fromJson(Map<String, dynamic> j) => SpotlightPlayer(
        playerId: (j['playerId'] ?? '') as String,
        userId: (j['userId'] ?? j['UserId'])?.toString(),
        playerName: (j['playerName'] ?? j['name'] ?? '') as String,
        goals: (j['goals'] as num?)?.toInt() ?? 0,
        assists: (j['assists'] as num?)?.toInt() ?? 0,
        mvpCount: ((j['mvpCount'] ?? j['mvps']) as num?)?.toInt() ?? 0,
        matchCount:
            ((j['matchCount'] ?? j['gamesPlayed']) as num?)?.toInt() ?? 0,
        winRate: (j['winRate'] as num?)?.toDouble() ?? 0,
        isGoalkeeper:
            (j['isGoalkeeper'] ?? j['goalkeeper'] ?? false) as bool? ?? false,
      );
}

// ── Full report ───────────────────────────────────────────────────────────────

class PlayerSpotlightReport {
  final SpotlightPlayer? topScorer;
  final SpotlightPlayer? topAssist;
  final SpotlightPlayer? topMvp;
  final SpotlightPlayer? bestWinRate;
  final List<SpotlightPlayer> players;

  const PlayerSpotlightReport({
    this.topScorer,
    this.topAssist,
    this.topMvp,
    this.bestWinRate,
    this.players = const [],
  });

  bool get isEmpty =>
      topScorer == null &&
      topAssist == null &&
      topMvp == null &&
      bestWinRate == null &&
      players.isEmpty;

  factory PlayerSpotlightReport.fromJson(Map<String, dynamic> json) {
    // Unwrap { data: { ... } } envelope if present
    final j = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    SpotlightPlayer? parseSlot(String key) {
      final raw = j[key];
      if (raw is! Map<String, dynamic>) return null;
      return SpotlightPlayer.fromJson(raw);
    }

    final rawPlayers = j['players'];
    final players = rawPlayers is List
        ? rawPlayers
            .whereType<Map<String, dynamic>>()
            .map(SpotlightPlayer.fromJson)
            .toList()
        : <SpotlightPlayer>[];

    return PlayerSpotlightReport(
      topScorer: parseSlot('topScorer'),
      topAssist: parseSlot('topAssist'),
      topMvp: parseSlot('topMvp'),
      bestWinRate: parseSlot('bestWinRate'),
      players: players,
    );
  }
}
