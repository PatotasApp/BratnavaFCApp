import 'championship_enums.dart';
import 'championship_rules.dart';

class ChampionshipSummary {
  const ChampionshipSummary({
    required this.id,
    required this.name,
    required this.playedAt,
    required this.placeName,
    required this.status,
    required this.teamCount,
    required this.gameCount,
    required this.championTeamName,
    required this.championTeamColorHex,
    required this.ruleBadges,
  });

  final String id;
  final String name;
  final DateTime playedAt;
  final String placeName;
  final ChampionshipStatus status;
  final int teamCount;
  final int gameCount;
  final String? championTeamName;
  final String? championTeamColorHex;
  final List<String> ruleBadges;

  factory ChampionshipSummary.fromJson(Map<String, dynamic> json) =>
      ChampionshipSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        playedAt: DateTime.parse(json['playedAt'] as String).toLocal(),
        placeName: json['placeName'] as String,
        status: enumByValue(
          ChampionshipStatus.values,
          json['status'] as int,
        ),
        teamCount: json['teamCount'] as int,
        gameCount: json['gameCount'] as int,
        championTeamName: json['championTeamName'] as String?,
        championTeamColorHex: json['championTeamColorHex'] as String?,
        ruleBadges: List<String>.from(json['ruleBadges'] as List<dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'playedAt': playedAt.toUtc().toIso8601String(),
        'placeName': placeName,
        'status': status.value,
        'teamCount': teamCount,
        'gameCount': gameCount,
        'championTeamName': championTeamName,
        'championTeamColorHex': championTeamColorHex,
        'ruleBadges': ruleBadges,
      };
}

class ChampionshipPlayer {
  const ChampionshipPlayer({
    required this.playerId,
    required this.name,
    required this.photoUrl,
    required this.isGuest,
    required this.isGoalkeeper,
    required this.inviteResponse,
    required this.teamId,
    required this.didNotPlay,
  });

  final String playerId;
  final String name;
  final String? photoUrl;
  final bool isGuest;
  final bool isGoalkeeper;
  final ChampionshipInviteResponse inviteResponse;
  final String? teamId;
  final bool didNotPlay;

  factory ChampionshipPlayer.fromJson(Map<String, dynamic> json) =>
      ChampionshipPlayer(
        playerId: json['playerId'] as String,
        name: json['name'] as String,
        photoUrl: json['photoUrl'] as String?,
        isGuest: json['isGuest'] as bool,
        isGoalkeeper: json['isGoalkeeper'] as bool,
        inviteResponse: enumByValue(
          ChampionshipInviteResponse.values,
          json['inviteResponse'] as int,
        ),
        teamId: json['teamId'] as String?,
        didNotPlay: json['didNotPlay'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'photoUrl': photoUrl,
        'isGuest': isGuest,
        'isGoalkeeper': isGoalkeeper,
        'inviteResponse': inviteResponse.value,
        'teamId': teamId,
        'didNotPlay': didNotPlay,
      };

  ChampionshipPlayer copyWith({
    ChampionshipInviteResponse? inviteResponse,
    String? teamId,
    bool? didNotPlay,
  }) =>
      ChampionshipPlayer(
        playerId: playerId,
        name: name,
        photoUrl: photoUrl,
        isGuest: isGuest,
        isGoalkeeper: isGoalkeeper,
        inviteResponse: inviteResponse ?? this.inviteResponse,
        teamId: teamId ?? this.teamId,
        didNotPlay: didNotPlay ?? this.didNotPlay,
      );
}

class ChampionshipTeam {
  const ChampionshipTeam({
    required this.id,
    required this.name,
    required this.colorId,
    required this.colorHex,
    required this.finalPosition,
    required this.playerIds,
  });

  final String id;
  final String name;
  final String? colorId;
  final String? colorHex;
  final int? finalPosition;
  final List<String> playerIds;

  factory ChampionshipTeam.fromJson(Map<String, dynamic> json) =>
      ChampionshipTeam(
        id: json['id'] as String,
        name: json['name'] as String,
        colorId: json['colorId'] as String?,
        colorHex: json['colorHex'] as String?,
        finalPosition: json['finalPosition'] as int?,
        playerIds: List<String>.from(json['playerIds'] as List<dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorId': colorId,
        'colorHex': colorHex,
        'finalPosition': finalPosition,
        'playerIds': playerIds,
      };
}

class ChampionshipGoal {
  const ChampionshipGoal({
    required this.id,
    required this.scorerPlayerId,
    required this.assistPlayerId,
    required this.isOwnGoal,
    required this.timeSeconds,
  });

  final String id;
  final String scorerPlayerId;
  final String? assistPlayerId;
  final bool isOwnGoal;
  final int? timeSeconds;

  factory ChampionshipGoal.fromJson(Map<String, dynamic> json) =>
      ChampionshipGoal(
        id: json['id'] as String,
        scorerPlayerId: json['scorerPlayerId'] as String,
        assistPlayerId: json['assistPlayerId'] as String?,
        isOwnGoal: json['isOwnGoal'] as bool,
        timeSeconds: json['timeSeconds'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scorerPlayerId': scorerPlayerId,
        'assistPlayerId': assistPlayerId,
        'isOwnGoal': isOwnGoal,
        'timeSeconds': timeSeconds,
      };
}

class ChampionshipGame {
  const ChampionshipGame({
    required this.id,
    required this.order,
    required this.teamAId,
    required this.teamBId,
    required this.teamAGoals,
    required this.teamBGoals,
    required this.externalWinnerTeamId,
    required this.status,
    required this.startedAt,
    required this.goals,
  });

  final String id;
  final int order;
  final String teamAId;
  final String teamBId;
  final int teamAGoals;
  final int teamBGoals;
  final String? externalWinnerTeamId;
  final ChampionshipGameStatus status;
  final DateTime? startedAt;
  final List<ChampionshipGoal> goals;

  factory ChampionshipGame.fromJson(Map<String, dynamic> json) =>
      ChampionshipGame(
        id: json['id'] as String,
        order: json['order'] as int,
        teamAId: json['teamAId'] as String,
        teamBId: json['teamBId'] as String,
        teamAGoals: json['teamAGoals'] as int,
        teamBGoals: json['teamBGoals'] as int,
        externalWinnerTeamId: json['externalWinnerTeamId'] as String?,
        status: enumByValue(
          ChampionshipGameStatus.values,
          json['status'] as int,
        ),
        startedAt: json['startedAt'] == null
            ? null
            : DateTime.parse(json['startedAt'] as String).toLocal(),
        goals: (json['goals'] as List<dynamic>)
            .map((item) => ChampionshipGoal.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'teamAId': teamAId,
        'teamBId': teamBId,
        'teamAGoals': teamAGoals,
        'teamBGoals': teamBGoals,
        'externalWinnerTeamId': externalWinnerTeamId,
        'status': status.value,
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'goals': goals.map((item) => item.toJson()).toList(),
      };
}

class ChampionshipStanding {
  const ChampionshipStanding({
    required this.position,
    required this.teamId,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
    required this.pointsPerGame,
  });

  final int position;
  final String teamId;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;
  final double pointsPerGame;

  factory ChampionshipStanding.fromJson(Map<String, dynamic> json) =>
      ChampionshipStanding(
        position: json['position'] as int,
        teamId: json['teamId'] as String,
        played: json['played'] as int,
        wins: json['wins'] as int,
        draws: json['draws'] as int,
        losses: json['losses'] as int,
        goalsFor: json['goalsFor'] as int,
        goalsAgainst: json['goalsAgainst'] as int,
        goalDifference: json['goalDifference'] as int,
        points: json['points'] as int,
        pointsPerGame: (json['pointsPerGame'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'teamId': teamId,
        'played': played,
        'wins': wins,
        'draws': draws,
        'losses': losses,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
        'goalDifference': goalDifference,
        'points': points,
        'pointsPerGame': pointsPerGame,
      };
}

class ChampionshipPlayerTotal {
  const ChampionshipPlayerTotal({required this.playerId, required this.total});

  final String playerId;
  final int total;

  factory ChampionshipPlayerTotal.fromJson(
    Map<String, dynamic> json,
    String field,
  ) =>
      ChampionshipPlayerTotal(
        playerId: json['playerId'] as String,
        total: json[field] as int,
      );

  Map<String, dynamic> toJson(String field) => {
        'playerId': playerId,
        field: total,
      };
}

class ChampionshipVote {
  const ChampionshipVote({required this.gameId, required this.votedPlayerId});

  final String? gameId;
  final String votedPlayerId;

  factory ChampionshipVote.fromJson(Map<String, dynamic> json) =>
      ChampionshipVote(
        gameId: json['gameId'] as String?,
        votedPlayerId: json['votedPlayerId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'votedPlayerId': votedPlayerId,
      };
}

class ChampionshipDetails {
  const ChampionshipDetails({
    required this.id,
    required this.name,
    required this.playedAt,
    required this.placeName,
    required this.status,
    required this.rules,
    required this.rulesLocked,
    required this.ruleBadges,
    required this.players,
    required this.teams,
    required this.games,
    required this.standings,
    required this.currentGameId,
    required this.waitingTeamIds,
    required this.topScorers,
    required this.topAssists,
    required this.mvpPlayerIds,
    required this.myInviteResponse,
    required this.canVote,
    required this.myVotes,
    this.linkedPollId,
  });

  final String id;
  final String name;
  final DateTime playedAt;
  final String placeName;
  final ChampionshipStatus status;
  final ChampionshipRules rules;
  final bool rulesLocked;
  final List<String> ruleBadges;
  final List<ChampionshipPlayer> players;
  final List<ChampionshipTeam> teams;
  final List<ChampionshipGame> games;
  final List<ChampionshipStanding> standings;
  final String? currentGameId;
  final List<String> waitingTeamIds;
  final List<ChampionshipPlayerTotal> topScorers;
  final List<ChampionshipPlayerTotal> topAssists;
  final List<String> mvpPlayerIds;
  final ChampionshipInviteResponse? myInviteResponse;
  final bool canVote;
  final List<ChampionshipVote> myVotes;

  /// Votação/evento vinculado, como na partida (v8).
  final String? linkedPollId;

  /// Etapa Sorteio: `TeamDraw` ainda sem times (v8). Com times é a etapa Times.
  bool get isDrawStage =>
      status == ChampionshipStatus.teamDraw && teams.isEmpty;

  bool get isTeamsStage =>
      status == ChampionshipStatus.teamDraw && teams.isNotEmpty;

  List<ChampionshipPlayer> get confirmedPlayers => players
      .where((p) => p.inviteResponse == ChampionshipInviteResponse.accepted)
      .toList(growable: false);

  /// Jogadores confirmados que ainda não estão em nenhum time.
  List<ChampionshipPlayer> get unassignedPlayers => confirmedPlayers
      .where((p) => p.teamId == null || teamById(p.teamId!) == null)
      .toList(growable: false);

  ChampionshipGame? get currentGame {
    if (currentGameId == null) return null;
    for (final game in games) {
      if (game.id == currentGameId) return game;
    }
    return null;
  }

  ChampionshipTeam? teamById(String id) {
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  ChampionshipPlayer? playerById(String id) {
    for (final player in players) {
      if (player.playerId == id) return player;
    }
    return null;
  }

  factory ChampionshipDetails.fromJson(Map<String, dynamic> json) =>
      ChampionshipDetails(
        id: json['id'] as String,
        name: json['name'] as String,
        playedAt: DateTime.parse(json['playedAt'] as String).toLocal(),
        placeName: json['placeName'] as String,
        status: enumByValue(
          ChampionshipStatus.values,
          json['status'] as int,
        ),
        rules: ChampionshipRules.fromJson(
          json['rules'] as Map<String, dynamic>,
        ),
        rulesLocked: json['rulesLocked'] as bool,
        ruleBadges: List<String>.from(json['ruleBadges'] as List<dynamic>),
        players: (json['players'] as List<dynamic>)
            .map((item) => ChampionshipPlayer.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(growable: false),
        teams: (json['teams'] as List<dynamic>)
            .map((item) => ChampionshipTeam.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(growable: false),
        games: (json['games'] as List<dynamic>)
            .map((item) => ChampionshipGame.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(growable: false),
        standings: (json['standings'] as List<dynamic>)
            .map((item) => ChampionshipStanding.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(growable: false),
        currentGameId: json['currentGameId'] as String?,
        waitingTeamIds:
            List<String>.from(json['waitingTeamIds'] as List<dynamic>),
        topScorers: (json['topScorers'] as List<dynamic>)
            .map((item) => ChampionshipPlayerTotal.fromJson(
                  item as Map<String, dynamic>,
                  'goals',
                ))
            .toList(growable: false),
        topAssists: (json['topAssists'] as List<dynamic>)
            .map((item) => ChampionshipPlayerTotal.fromJson(
                  item as Map<String, dynamic>,
                  'assists',
                ))
            .toList(growable: false),
        mvpPlayerIds: List<String>.from(json['mvpPlayerIds'] as List<dynamic>),
        myInviteResponse: json['myInviteResponse'] == null
            ? null
            : enumByValue(
                ChampionshipInviteResponse.values,
                json['myInviteResponse'] as int,
              ),
        canVote: json['canVote'] as bool,
        myVotes: (json['myVotes'] as List<dynamic>)
            .map((item) => ChampionshipVote.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(growable: false),
        linkedPollId: json['linkedPollId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'playedAt': playedAt.toUtc().toIso8601String(),
        'placeName': placeName,
        'status': status.value,
        'rules': rules.toJson(),
        'rulesLocked': rulesLocked,
        'ruleBadges': ruleBadges,
        'players': players.map((item) => item.toJson()).toList(),
        'teams': teams.map((item) => item.toJson()).toList(),
        'games': games.map((item) => item.toJson()).toList(),
        'standings': standings.map((item) => item.toJson()).toList(),
        'currentGameId': currentGameId,
        'waitingTeamIds': waitingTeamIds,
        'topScorers': topScorers.map((item) => item.toJson('goals')).toList(),
        'topAssists': topAssists.map((item) => item.toJson('assists')).toList(),
        'mvpPlayerIds': mvpPlayerIds,
        'myInviteResponse': myInviteResponse?.value,
        'canVote': canVote,
        'myVotes': myVotes.map((item) => item.toJson()).toList(),
        'linkedPollId': linkedPollId,
      };
}

class ChampionshipUpsert {
  const ChampionshipUpsert({
    required this.name,
    required this.playedAt,
    required this.placeName,
    required this.rules,
  });

  final String name;
  final DateTime playedAt;
  final String placeName;
  final ChampionshipRules rules;

  factory ChampionshipUpsert.fromJson(Map<String, dynamic> json) =>
      ChampionshipUpsert(
        name: json['name'] as String,
        playedAt: DateTime.parse(json['playedAt'] as String).toLocal(),
        placeName: json['placeName'] as String,
        rules: ChampionshipRules.fromJson(
          json['rules'] as Map<String, dynamic>,
        ),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'playedAt': playedAt.toUtc().toIso8601String(),
        'placeName': placeName,
        'rules': rules.toJson(),
      };

  List<String> validate() {
    final errors = rules.validate();
    if (name.trim().isEmpty) errors.insert(0, 'Informe o nome do campeonato.');
    if (placeName.trim().isEmpty) errors.insert(0, 'Informe o local.');
    return errors;
  }
}

class DefineChampionshipTeam {
  const DefineChampionshipTeam({
    required this.name,
    required this.colorId,
    required this.playerIds,
    required this.goalkeeperPlayerId,
  });

  final String name;
  final String? colorId;
  final List<String> playerIds;
  final String? goalkeeperPlayerId;

  factory DefineChampionshipTeam.fromJson(Map<String, dynamic> json) =>
      DefineChampionshipTeam(
        name: json['name'] as String,
        colorId: json['colorId'] as String?,
        playerIds: List<String>.from(json['playerIds'] as List<dynamic>),
        goalkeeperPlayerId: json['goalkeeperPlayerId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'colorId': colorId,
        'playerIds': playerIds,
        'goalkeeperPlayerId': goalkeeperPlayerId,
      };
}

class DefineChampionshipTeams {
  const DefineChampionshipTeams({required this.teams});
  final List<DefineChampionshipTeam> teams;

  factory DefineChampionshipTeams.fromJson(Map<String, dynamic> json) =>
      DefineChampionshipTeams(
        teams: (json['teams'] as List<dynamic>)
            .map((item) => DefineChampionshipTeam.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'teams': teams.map((item) => item.toJson()).toList(),
      };
}

/// Sugestão de `POST /{id}/teams/draw`: os times (não salvos) e o aviso do
/// servidor em `message` quando há menos cores ativas que times (v5).
/// Uma opção do sorteio da etapa Sorteio (`POST /{id}/teams/draw-options`, v8).
class ChampionshipDrawOption {
  const ChampionshipDrawOption({
    required this.teams,
    required this.unassignedPlayerIds,
    required this.teamStrengths,
    required this.strengthDifference,
  });

  final List<DefineChampionshipTeam> teams;
  final List<String> unassignedPlayerIds;
  final List<double> teamStrengths;
  final double strengthDifference;

  factory ChampionshipDrawOption.fromJson(Map<String, dynamic> json) =>
      ChampionshipDrawOption(
        teams: (json['teams'] as List<dynamic>)
            .map((item) =>
                DefineChampionshipTeam.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        unassignedPlayerIds: List<String>.from(
            (json['unassignedPlayerIds'] as List<dynamic>?) ?? const []),
        teamStrengths: ((json['teamStrengths'] as List<dynamic>?) ?? const [])
            .map((value) => (value as num).toDouble())
            .toList(growable: false),
        strengthDifference:
            (json['strengthDifference'] as num?)?.toDouble() ?? 0,
      );
}

class ChampionshipDrawOptions {
  const ChampionshipDrawOptions({required this.options, this.message});

  final List<ChampionshipDrawOption> options;

  /// Aviso do servidor (ex.: menos cores que times).
  final String? message;
}

/// Replays do campeonato por jogo (`GET /{id}/replays`, v8).
class ChampionshipReplayClip {
  const ChampionshipReplayClip({
    required this.id,
    required this.url,
    required this.eventType,
    required this.recordedAt,
    required this.teamId,
    required this.teamAGoals,
    required this.teamBGoals,
    required this.label,
  });

  final String id;
  final String url;
  final String eventType;
  final DateTime recordedAt;
  final String? teamId;
  final int teamAGoals;
  final int teamBGoals;

  /// Placar do momento, ex.: "Jogo 1 - 1 x 0".
  final String label;

  bool get isGoal => eventType == 'GolTimeA' || eventType == 'GolTimeB';

  factory ChampionshipReplayClip.fromJson(Map<String, dynamic> json) =>
      ChampionshipReplayClip(
        id: json['id'] as String,
        url: (json['url'] as String?) ?? '',
        eventType: json['eventType'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String).toLocal(),
        teamId: json['teamId'] as String?,
        teamAGoals: (json['teamAGoals'] as num?)?.toInt() ?? 0,
        teamBGoals: (json['teamBGoals'] as num?)?.toInt() ?? 0,
        label: (json['label'] as String?) ?? '',
      );
}

class ChampionshipGameReplays {
  const ChampionshipGameReplays({
    required this.gameId,
    required this.order,
    required this.teamAId,
    required this.teamAName,
    required this.teamAColorHex,
    required this.teamBId,
    required this.teamBName,
    required this.teamBColorHex,
    required this.teamAGoals,
    required this.teamBGoals,
    required this.clips,
  });

  final String gameId;
  final int order;
  final String teamAId;
  final String teamAName;
  final String? teamAColorHex;
  final String teamBId;
  final String teamBName;
  final String? teamBColorHex;
  final int? teamAGoals;
  final int? teamBGoals;
  final List<ChampionshipReplayClip> clips;

  factory ChampionshipGameReplays.fromJson(Map<String, dynamic> json) =>
      ChampionshipGameReplays(
        gameId: json['gameId'] as String,
        order: (json['order'] as num).toInt(),
        teamAId: json['teamAId'] as String,
        teamAName: json['teamAName'] as String,
        teamAColorHex: json['teamAColorHex'] as String?,
        teamBId: json['teamBId'] as String,
        teamBName: json['teamBName'] as String,
        teamBColorHex: json['teamBColorHex'] as String?,
        teamAGoals: (json['teamAGoals'] as num?)?.toInt(),
        teamBGoals: (json['teamBGoals'] as num?)?.toInt(),
        clips: ((json['clips'] as List<dynamic>?) ?? const [])
            .map((item) =>
                ChampionshipReplayClip.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class ChampionshipReplays {
  const ChampionshipReplays(
      {required this.championshipId, required this.games});

  final String championshipId;
  final List<ChampionshipGameReplays> games;

  factory ChampionshipReplays.fromJson(Map<String, dynamic> json) =>
      ChampionshipReplays(
        championshipId: json['championshipId'] as String,
        games: ((json['games'] as List<dynamic>?) ?? const [])
            .map((item) =>
                ChampionshipGameReplays.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class ChampionshipTeamsDraw {
  const ChampionshipTeamsDraw({required this.teams, this.message});

  final DefineChampionshipTeams teams;
  final String? message;
}

class NextGameSuggestion {
  const NextGameSuggestion({
    required this.teamAId,
    required this.teamBId,
    required this.reason,
    required this.waitingTeamIds,
  });

  final String teamAId;
  final String teamBId;
  final String reason;
  final List<String> waitingTeamIds;

  factory NextGameSuggestion.fromJson(Map<String, dynamic> json) =>
      NextGameSuggestion(
        teamAId: json['teamAId'] as String,
        teamBId: json['teamBId'] as String,
        reason: json['reason'] as String,
        waitingTeamIds:
            List<String>.from(json['waitingTeamIds'] as List<dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'teamAId': teamAId,
        'teamBId': teamBId,
        'reason': reason,
        'waitingTeamIds': waitingTeamIds,
      };
}
