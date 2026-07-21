class PlayerSynergyItem {
  final String withPlayerId;
  final String withPlayerName;
  final int matchesTogether;
  final int winsTogether;
  final double winRateTogether; // 0–1 or 0–100 — use normalizeWR()

  const PlayerSynergyItem({
    required this.withPlayerId,
    required this.withPlayerName,
    required this.matchesTogether,
    required this.winsTogether,
    required this.winRateTogether,
  });

  factory PlayerSynergyItem.fromJson(Map<String, dynamic> j) =>
      PlayerSynergyItem(
        withPlayerId: (j['withPlayerId'] ?? '') as String,
        withPlayerName: (j['withPlayerName'] ?? '') as String,
        matchesTogether: (j['matchesTogether'] as num?)?.toInt() ?? 0,
        winsTogether: (j['winsTogether'] as num?)?.toInt() ?? 0,
        winRateTogether: (j['winRateTogether'] as num?)?.toDouble() ?? 0,
      );
}

class PlayerVisualStatsItem {
  final String playerId;
  final String name;
  final int status; // 1 = active
  final bool isGoalkeeper;
  final int gamesPlayed;
  final int wins;
  final int ties;
  final int losses;
  final double winRate; // normalise with normalizeWR()
  final int points;
  final int classificationRank;
  final int mvps;
  final int goals;
  final int assists;
  final int ownGoals;
  final int mvpVotes; // total MVP votes received
  final int mvpsRank;
  final int mvpVotesRank;
  final int goalsRank;
  final int assistsRank;
  final int? ownGoalsRank;
  final List<PlayerSynergyItem> synergies;

  const PlayerVisualStatsItem({
    required this.playerId,
    required this.name,
    required this.status,
    required this.isGoalkeeper,
    required this.gamesPlayed,
    required this.wins,
    required this.ties,
    required this.losses,
    required this.winRate,
    required this.points,
    required this.classificationRank,
    required this.mvps,
    required this.goals,
    required this.assists,
    required this.ownGoals,
    this.mvpVotes = 0,
    required this.mvpsRank,
    required this.mvpVotesRank,
    required this.goalsRank,
    required this.assistsRank,
    this.ownGoalsRank,
    required this.synergies,
  });

  bool get isActive => status == 1;

  factory PlayerVisualStatsItem.fromJson(Map<String, dynamic> j) {
    final rawSyn = j['synergies'];
    final synList = rawSyn is List
        ? rawSyn
            .whereType<Map<String, dynamic>>()
            .map(PlayerSynergyItem.fromJson)
            .toList()
        : <PlayerSynergyItem>[];

    return PlayerVisualStatsItem(
      playerId: (j['playerId'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      status: (j['status'] as num?)?.toInt() ?? 1,
      isGoalkeeper: (j['isGoalkeeper'] as bool?) ?? false,
      gamesPlayed: (j['gamesPlayed'] as num?)?.toInt() ?? 0,
      wins: (j['wins'] as num?)?.toInt() ?? 0,
      ties: (j['ties'] as num?)?.toInt() ?? 0,
      losses: (j['losses'] as num?)?.toInt() ?? 0,
      winRate: (j['winRate'] as num?)?.toDouble() ?? 0,
      points: (j['points'] as num?)?.toInt() ??
          (((j['wins'] as num?)?.toInt() ?? 0) * 3 +
              ((j['ties'] as num?)?.toInt() ?? 0)),
      classificationRank: (j['classificationRank'] as num?)?.toInt() ?? 0,
      mvps: (j['mvps'] as num?)?.toInt() ?? 0,
      goals: (j['goals'] as num?)?.toInt() ?? 0,
      assists: (j['assists'] as num?)?.toInt() ?? 0,
      ownGoals: (j['ownGoals'] as num?)?.toInt() ?? 0,
      mvpVotes: (j['mvpVotes'] as num?)?.toInt() ?? 0,
      mvpsRank: (j['mvpsRank'] as num?)?.toInt() ?? 0,
      mvpVotesRank: (j['mvpVotesRank'] as num?)?.toInt() ?? 0,
      goalsRank: (j['goalsRank'] as num?)?.toInt() ?? 0,
      assistsRank: (j['assistsRank'] as num?)?.toInt() ?? 0,
      ownGoalsRank: (j['ownGoalsRank'] as num?)?.toInt(),
      synergies: synList,
    );
  }
}

class PlayerVisualStatsReport {
  final String groupId;
  final int totalMatchesConsidered;
  final int totalFinalizedMatches;
  final int totalMatchesWithScore;
  final List<PlayerVisualStatsItem> players;

  const PlayerVisualStatsReport({
    required this.groupId,
    required this.totalMatchesConsidered,
    required this.totalFinalizedMatches,
    required this.totalMatchesWithScore,
    required this.players,
  });

  factory PlayerVisualStatsReport.fromJson(Map<String, dynamic> json) {
    // Unwrap { data: { ... } } envelope
    final j = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final rawPlayers = j['players'];
    final players = rawPlayers is List
        ? rawPlayers
            .whereType<Map<String, dynamic>>()
            .map(PlayerVisualStatsItem.fromJson)
            .toList()
        : <PlayerVisualStatsItem>[];

    return PlayerVisualStatsReport(
      groupId: (j['groupId'] ?? '') as String,
      totalMatchesConsidered:
          (j['totalMatchesConsidered'] as num?)?.toInt() ?? 0,
      totalFinalizedMatches: (j['totalFinalizedMatches'] as num?)?.toInt() ?? 0,
      totalMatchesWithScore: (j['totalMatchesWithScore'] as num?)?.toInt() ?? 0,
      players: players,
    );
  }
}
