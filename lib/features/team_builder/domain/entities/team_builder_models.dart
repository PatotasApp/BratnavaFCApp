class TeamBuilderPlayer {
  final String id;
  final String name;
  final bool isGoalkeeper;

  const TeamBuilderPlayer({
    required this.id,
    required this.name,
    required this.isGoalkeeper,
  });

  factory TeamBuilderPlayer.fromJson(Map<String, dynamic> j) =>
      TeamBuilderPlayer(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        isGoalkeeper: (j['isGoalkeeper'] ?? false) as bool,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class AssistPair {
  final String assisterId;
  final String assisterName;
  final String scorerId;
  final String scorerName;
  final int count;

  const AssistPair({
    required this.assisterId,
    required this.assisterName,
    required this.scorerId,
    required this.scorerName,
    required this.count,
  });

  factory AssistPair.fromJson(Map<String, dynamic> j) => AssistPair(
        assisterId: (j['assisterId'] ?? '') as String,
        assisterName: (j['assisterName'] ?? '') as String,
        scorerId: (j['scorerId'] ?? '') as String,
        scorerName: (j['scorerName'] ?? '') as String,
        count: (j['count'] ?? 0) as int,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class TeamBuilderStats {
  final bool neverPlayedTogether;
  final int totalMatches;
  final int wins;
  final int draws;
  final int losses;
  final int goalsScored;
  final int goalsConceded;
  final int goalsScoredByPlayers;
  final List<AssistPair> assistPairs;
  final List<TeamBuilderPlayer> players;

  const TeamBuilderStats({
    required this.neverPlayedTogether,
    this.totalMatches = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsScored = 0,
    this.goalsConceded = 0,
    this.goalsScoredByPlayers = 0,
    this.assistPairs = const [],
    this.players = const [],
  });

  factory TeamBuilderStats.fromJson(Map<String, dynamic> j) {
    final d = (j['data'] is Map<String, dynamic>)
        ? j['data'] as Map<String, dynamic>
        : j;
    return TeamBuilderStats(
      neverPlayedTogether: (d['neverPlayedTogether'] ?? true) as bool,
      totalMatches: (d['totalMatches'] ?? 0) as int,
      wins: (d['wins'] ?? 0) as int,
      draws: (d['draws'] ?? 0) as int,
      losses: (d['losses'] ?? 0) as int,
      goalsScored: (d['goalsScored'] ?? 0) as int,
      goalsConceded: (d['goalsConceded'] ?? 0) as int,
      goalsScoredByPlayers: (d['goalsScoredByPlayers'] ?? 0) as int,
      assistPairs: (d['assistPairs'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AssistPair.fromJson)
          .toList(),
      players: (d['players'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TeamBuilderPlayer.fromJson)
          .toList(),
    );
  }
}
