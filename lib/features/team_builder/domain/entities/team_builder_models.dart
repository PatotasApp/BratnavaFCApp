int _int(dynamic v) => v is num ? v.toInt() : 0;
double _double(dynamic v) => v is num ? v.toDouble() : 0;
String _str(dynamic v) => v is String ? v : '';
bool _bool(dynamic v) => v == true;

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    (v as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(f)
        .toList();

T? _obj<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    v is Map<String, dynamic> ? f(v) : null;

Map<String, dynamic> _unwrap(Map<String, dynamic> j) =>
    j['data'] is Map<String, dynamic> ? j['data'] as Map<String, dynamic> : j;

/// Recorte das partidas. Os filtros se somam: temporada/data e depois
/// "últimos N jogos" sobre o que sobrou.
class TeamBuilderFilter {
  final int? season;
  final DateTime? from;
  final int? lastMatches;
  final bool includeChampionship;

  const TeamBuilderFilter({
    this.season,
    this.from,
    this.lastMatches,
    this.includeChampionship = true,
  });

  Map<String, dynamic> toJson() => {
        if (season != null) 'season': season,
        if (from != null)
          'from':
              '${from!.year.toString().padLeft(4, '0')}-${from!.month.toString().padLeft(2, '0')}-${from!.day.toString().padLeft(2, '0')}',
        if (lastMatches != null) 'lastMatches': lastMatches,
        'includeChampionship': includeChampionship,
      };
}

class TeamBuilderPlayer {
  final String id;
  final String name;

  /// Primeiro nome; nome completo quando outro jogador da patota tem o mesmo.
  final String shortName;
  final bool isGoalkeeper;

  /// Jogos no recorte (só na lista de escolha).
  final int games;

  const TeamBuilderPlayer({
    required this.id,
    required this.name,
    required this.isGoalkeeper,
    String? shortName,
    this.games = 0,
  }) : shortName = shortName ?? name;

  factory TeamBuilderPlayer.fromJson(Map<String, dynamic> j) =>
      TeamBuilderPlayer(
        id: _str(j['id']),
        name: _str(j['name']),
        shortName: j['shortName'] is String ? j['shortName'] as String : null,
        isGoalkeeper: _bool(j['isGoalkeeper']),
        games: _int(j['games']),
      );
}

class TeamBuilderPlayers {
  final int periodMatches;
  final List<int> seasons;
  final List<TeamBuilderPlayer> players;

  const TeamBuilderPlayers({
    this.periodMatches = 0,
    this.seasons = const [],
    this.players = const [],
  });

  factory TeamBuilderPlayers.fromJson(Map<String, dynamic> json) {
    final d = _unwrap(json);
    return TeamBuilderPlayers(
      periodMatches: _int(d['periodMatches']),
      seasons: (d['seasons'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList(),
      players: _list(d['players'], TeamBuilderPlayer.fromJson),
    );
  }
}

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

  /// Usa os nomes curtos quando a API manda.
  factory AssistPair.fromJson(Map<String, dynamic> j) => AssistPair(
        assisterId: _str(j['assisterId']),
        assisterName: _str(j['assisterShortName'] ?? j['assisterName']),
        scorerId: _str(j['scorerId']),
        scorerName: _str(j['scorerShortName'] ?? j['scorerName']),
        count: _int(j['count']),
      );
}

class PlayerBreakdown {
  final String id;
  final String name;
  final String shortName;
  final bool isGoalkeeper;
  final int goals;
  final int assists;
  final int mvps;

  /// Aproveitamento do jogador em todos os jogos do recorte ("geral").
  final int overallGames;
  final int overallPointsPct;

  const PlayerBreakdown({
    required this.id,
    required this.name,
    required this.shortName,
    required this.isGoalkeeper,
    this.goals = 0,
    this.assists = 0,
    this.mvps = 0,
    this.overallGames = 0,
    this.overallPointsPct = 0,
  });

  factory PlayerBreakdown.fromJson(Map<String, dynamic> j) => PlayerBreakdown(
        id: _str(j['id']),
        name: _str(j['name']),
        shortName: _str(j['shortName'] ?? j['name']),
        isGoalkeeper: _bool(j['isGoalkeeper']),
        goals: _int(j['goals']),
        assists: _int(j['assists']),
        mvps: _int(j['mvps']),
        overallGames: _int(j['overallGames']),
        overallPointsPct: _int(j['overallPointsPct']),
      );
}

/// Uma partida em que jogaram juntos, do ponto de vista do time deles.
class FormationMatch {
  final String matchId;
  final DateTime playedAt;
  final int goalsFor;
  final int goalsAgainst;

  /// 1 vitória, 0 empate, -1 derrota.
  final int result;
  final bool isChampionship;

  const FormationMatch({
    required this.matchId,
    required this.playedAt,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.result,
    this.isChampionship = false,
  });

  factory FormationMatch.fromJson(Map<String, dynamic> j) => FormationMatch(
        matchId: _str(j['matchId']),
        playedAt: DateTime.tryParse(_str(j['playedAt']))?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        goalsFor: _int(j['goalsFor']),
        goalsAgainst: _int(j['goalsAgainst']),
        result: _int(j['result']),
        isChampionship: _bool(j['isChampionship']),
      );
}

class OpponentRecord {
  final String playerId;
  final String shortName;
  final int wins;
  final int draws;
  final int losses;

  const OpponentRecord({
    required this.playerId,
    required this.shortName,
    required this.wins,
    required this.draws,
    required this.losses,
  });

  factory OpponentRecord.fromJson(Map<String, dynamic> j) => OpponentRecord(
        playerId: _str(j['playerId']),
        shortName: _str(j['shortName'] ?? j['name']),
        wins: _int(j['wins']),
        draws: _int(j['draws']),
        losses: _int(j['losses']),
      );
}

class Streak {
  final int result;
  final int count;
  const Streak({required this.result, required this.count});

  factory Streak.fromJson(Map<String, dynamic> j) =>
      Streak(result: _int(j['result']), count: _int(j['count']));
}

/// "Juntos" = partidas em que todos estavam no MESMO time.
class TeamBuilderStats {
  final bool neverPlayedTogether;
  final int totalMatches;
  final int wins;
  final int draws;
  final int losses;
  final int goalsScored;
  final int goalsConceded;
  final int goalDifference;
  final double goalsPerMatch;
  final int pointsPct;
  final int averageIndividualPointsPct;
  final int oppositeTeamsMatches;
  final FormationMatch? biggestWin;
  final FormationMatch? worstLoss;
  final FormationMatch? lastMatch;
  final Streak? currentStreak;
  final OpponentRecord? nemesis;
  final OpponentRecord? favoriteVictim;
  final List<String> curiosities;
  final List<AssistPair> assistPairs;
  final List<PlayerBreakdown> playerBreakdown;
  final List<FormationMatch> matches;

  const TeamBuilderStats({
    required this.neverPlayedTogether,
    this.totalMatches = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsScored = 0,
    this.goalsConceded = 0,
    this.goalDifference = 0,
    this.goalsPerMatch = 0,
    this.pointsPct = 0,
    this.averageIndividualPointsPct = 0,
    this.oppositeTeamsMatches = 0,
    this.biggestWin,
    this.worstLoss,
    this.lastMatch,
    this.currentStreak,
    this.nemesis,
    this.favoriteVictim,
    this.curiosities = const [],
    this.assistPairs = const [],
    this.playerBreakdown = const [],
    this.matches = const [],
  });

  PlayerBreakdown? breakdownOf(String playerId) {
    for (final p in playerBreakdown) {
      if (p.id == playerId) return p;
    }
    return null;
  }

  factory TeamBuilderStats.fromJson(Map<String, dynamic> json) {
    final d = _unwrap(json);
    return TeamBuilderStats(
      neverPlayedTogether: d['neverPlayedTogether'] != false,
      totalMatches: _int(d['totalMatches']),
      wins: _int(d['wins']),
      draws: _int(d['draws']),
      losses: _int(d['losses']),
      goalsScored: _int(d['goalsScored']),
      goalsConceded: _int(d['goalsConceded']),
      goalDifference: _int(d['goalDifference']),
      goalsPerMatch: _double(d['goalsPerMatch']),
      pointsPct: _int(d['pointsPct']),
      averageIndividualPointsPct: _int(d['averageIndividualPointsPct']),
      oppositeTeamsMatches: _int(d['oppositeTeamsMatches']),
      biggestWin: _obj(d['biggestWin'], FormationMatch.fromJson),
      worstLoss: _obj(d['worstLoss'], FormationMatch.fromJson),
      lastMatch: _obj(d['lastMatch'], FormationMatch.fromJson),
      currentStreak: _obj(d['currentStreak'], Streak.fromJson),
      nemesis: _obj(d['nemesis'], OpponentRecord.fromJson),
      favoriteVictim: _obj(d['favoriteVictim'], OpponentRecord.fromJson),
      curiosities: (d['curiosities'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      assistPairs: _list(d['assistPairs'], AssistPair.fromJson),
      playerBreakdown: _list(d['playerBreakdown'], PlayerBreakdown.fromJson),
      matches: _list(d['matches'], FormationMatch.fromJson),
    );
  }
}
