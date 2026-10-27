import 'dart:convert';
import '../../domain/entities/championship_enums.dart';
import '../../domain/entities/championship_models.dart';
import '../../domain/entities/championship_rules.dart';
import 'championship_datasource.dart';

class ChampionshipMockDataSource implements ChampionshipDataSource {
  ChampionshipMockDataSource() {
    for (var index = 0; index < ChampionshipStatus.values.length; index++) {
      final status = ChampionshipStatus.values[index];
      final details = _seed(status, index);
      _items[details['id'] as String] = details;
    }
  }

  final Map<String, Map<String, dynamic>> _items = {};
  int _sequence = 100;

  Map<String, dynamic> _require(String id) {
    final item = _items[id];
    if (item == null) throw StateError('Campeonato não encontrado.');
    return item;
  }

  Map<String, dynamic> _clone(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  @override
  Future<List<ChampionshipSummary>> fetchAll(String groupId) async {
    final result = _items.values.map((item) {
      final teams = item['teams'] as List<dynamic>;
      Map<String, dynamic>? champion;
      for (final raw in teams) {
        final team = raw as Map<String, dynamic>;
        if (team['finalPosition'] == 1) champion = team;
      }
      return ChampionshipSummary.fromJson({
        'id': item['id'],
        'name': item['name'],
        'playedAt': item['playedAt'],
        'placeName': item['placeName'],
        'status': item['status'],
        'teamCount': teams.length,
        'gameCount': (item['games'] as List<dynamic>).length,
        'championTeamName': champion?['name'],
        'championTeamColorHex': champion?['colorHex'],
        'ruleBadges': item['ruleBadges'],
      });
    }).toList();
    result.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return result;
  }

  @override
  Future<ChampionshipDetails> fetchById(String groupId, String id) async =>
      ChampionshipDetails.fromJson(_clone(_require(id)));

  @override
  Future<NextGameSuggestion?> fetchNextGame(String groupId, String id) async {
    final item = _require(id);
    if (item['status'] != ChampionshipStatus.inProgress.value) return null;
    final teams = item['teams'] as List<dynamic>;
    if (teams.length < 2) return null;
    return NextGameSuggestion(
      teamAId: (teams[0] as Map<String, dynamic>)['id'] as String,
      teamBId: (teams[1] as Map<String, dynamic>)['id'] as String,
      reason: 'Fica quem ganha: Azul ganhou e fica; entra Verde',
      waitingTeamIds: teams
          .skip(2)
          .map((team) => (team as Map<String, dynamic>)['id'] as String)
          .toList(),
    );
  }

  @override
  Future<String> create(String groupId, ChampionshipUpsert input) async {
    final id = 'championship-mock-${_sequence++}';
    final base = _seed(ChampionshipStatus.created, _sequence);
    base
      ..['id'] = id
      ..['name'] = input.name
      ..['playedAt'] = input.playedAt.toUtc().toIso8601String()
      ..['placeName'] = input.placeName
      ..['rules'] = input.rules.toJson()
      ..['ruleBadges'] = buildChampionshipRuleBadges(input.rules);
    _items[id] = base;
    return id;
  }

  @override
  Future<void> update(
    String groupId,
    String id,
    ChampionshipUpsert input,
  ) async {
    final item = _require(id);
    if (item['rulesLocked'] == true) {
      throw StateError('As regras já estão travadas.');
    }
    item
      ..['name'] = input.name
      ..['playedAt'] = input.playedAt.toUtc().toIso8601String()
      ..['placeName'] = input.placeName
      ..['rules'] = input.rules.toJson()
      ..['ruleBadges'] = buildChampionshipRuleBadges(input.rules);
  }

  @override
  Future<void> cancel(String groupId, String id) async {
    _require(id)['status'] = ChampionshipStatus.cancelled.value;
  }

  @override
  Future<void> openAcceptation(String groupId, String id) async {
    _require(id)['status'] = ChampionshipStatus.acceptation.value;
  }

  Future<void> _setInvite(
    String id,
    String playerId,
    ChampionshipInviteResponse response,
  ) async {
    final players = _require(id)['players'] as List<dynamic>;
    for (final raw in players) {
      final player = raw as Map<String, dynamic>;
      if (player['playerId'] == playerId) {
        player['inviteResponse'] = response.value;
        return;
      }
    }
  }

  @override
  Future<void> acceptMyInvite(String groupId, String id) async {
    final players = _require(id)['players'] as List<dynamic>;
    await _setInvite(
      id,
      (players.first as Map<String, dynamic>)['playerId'] as String,
      ChampionshipInviteResponse.accepted,
    );
    _require(id)['myInviteResponse'] =
        ChampionshipInviteResponse.accepted.value;
  }

  @override
  Future<void> rejectMyInvite(String groupId, String id) async {
    final players = _require(id)['players'] as List<dynamic>;
    await _setInvite(
      id,
      (players.first as Map<String, dynamic>)['playerId'] as String,
      ChampionshipInviteResponse.rejected,
    );
    _require(id)['myInviteResponse'] =
        ChampionshipInviteResponse.rejected.value;
  }

  @override
  Future<void> acceptInvite(
    String groupId,
    String id,
    String playerId,
  ) =>
      _setInvite(id, playerId, ChampionshipInviteResponse.accepted);

  @override
  Future<void> rejectInvite(
    String groupId,
    String id,
    String playerId,
  ) =>
      _setInvite(id, playerId, ChampionshipInviteResponse.rejected);

  @override
  Future<void> addGuest(String groupId, String id, String playerId) async {
    final players = _require(id)['players'] as List<dynamic>;
    players.add({
      'playerId': playerId,
      'name': 'Convidado',
      'photoUrl': null,
      'isGuest': true,
      'isGoalkeeper': false,
      'inviteResponse': ChampionshipInviteResponse.accepted.value,
      'teamId': null,
      'didNotPlay': false,
    });
  }

  /// Cores "ativas da patota" no mock: só 3, para exercitar o aviso da v5.
  static const _mockColors = [
    ('mock-color-blue', '#2563EB'),
    ('mock-color-green', '#16A34A'),
    ('mock-color-orange', '#F97316'),
  ];

  static String? _colorWarning(int teamCount) => teamCount <= _mockColors.length
      ? null
      : 'Ha so ${_mockColors.length} cor(es) ativa(s) para $teamCount times: '
          '${teamCount - _mockColors.length} time(s) ficaram sem cor. '
          'Cadastre mais cores em Cores dos times.';

  static String? _hexOf(String? colorId) {
    for (final (id, hex) in _mockColors) {
      if (id == colorId) return hex;
    }
    return null;
  }

  @override
  Future<ChampionshipTeamsDraw> drawTeams(
    String groupId,
    String id,
    int teamCount,
  ) async {
    final players = (_require(id)['players'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((player) =>
            player['inviteResponse'] ==
            ChampionshipInviteResponse.accepted.value)
        .toList();
    const names = ['Azul', 'Verde', 'Laranja', 'Roxo', 'Branco'];
    final teams = DefineChampionshipTeams(
      teams: List.generate(teamCount, (teamIndex) {
        final ids = <String>[];
        for (var playerIndex = teamIndex;
            playerIndex < players.length;
            playerIndex += teamCount) {
          ids.add(players[playerIndex]['playerId'] as String);
        }
        return DefineChampionshipTeam(
          name: names[teamIndex % names.length],
          colorId:
              teamIndex < _mockColors.length ? _mockColors[teamIndex].$1 : null,
          playerIds: ids,
          goalkeeperPlayerId: ids.isEmpty ? null : ids.first,
        );
      }),
    );
    return ChampionshipTeamsDraw(
      teams: teams,
      message: _colorWarning(teamCount),
    );
  }

  @override
  Future<String?> drawTeamColors(String groupId, String id) async {
    final teams =
        (_require(id)['teams'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (var index = 0; index < teams.length; index++) {
      final color = index < _mockColors.length ? _mockColors[index] : null;
      teams[index]
        ..['colorId'] = color?.$1
        ..['colorHex'] = color?.$2;
    }
    return _colorWarning(teams.length) ?? 'Cores sorteadas.';
  }

  @override
  Future<void> updateTeam(
    String groupId,
    String id,
    String teamId, {
    required String name,
    String? colorId,
  }) async {
    for (final raw in _require(id)['teams'] as List<dynamic>) {
      final team = raw as Map<String, dynamic>;
      if (team['id'] != teamId) continue;
      team
        ..['name'] = name
        ..['colorId'] = colorId
        ..['colorHex'] =
            _hexOf(colorId) ?? (colorId == null ? null : team['colorHex']);
    }
  }

  @override
  Future<void> defineTeams(
    String groupId,
    String id,
    DefineChampionshipTeams input,
  ) async {
    final item = _require(id);
    final teams = <Map<String, dynamic>>[];
    for (var index = 0; index < input.teams.length; index++) {
      final definition = input.teams[index];
      final teamId = '$id-team-${index + 1}';
      teams.add({
        'id': teamId,
        'name': definition.name,
        'colorId': definition.colorId,
        'colorHex': _hexOf(definition.colorId),
        'finalPosition': null,
        'playerIds': definition.playerIds,
      });
      for (final raw in item['players'] as List<dynamic>) {
        final player = raw as Map<String, dynamic>;
        if (definition.playerIds.contains(player['playerId'])) {
          player
            ..['teamId'] = teamId
            ..['isGoalkeeper'] =
                player['playerId'] == definition.goalkeeperPlayerId;
        }
      }
    }
    item
      ..['teams'] = teams
      ..['status'] = ChampionshipStatus.teamDraw.value;
  }

  @override
  Future<void> assignPlayerTeam(
    String groupId,
    String id,
    String playerId,
    String teamId,
  ) async {
    final item = _require(id);
    for (final raw in item['players'] as List<dynamic>) {
      final player = raw as Map<String, dynamic>;
      if (player['playerId'] == playerId) player['teamId'] = teamId;
    }
    for (final raw in item['teams'] as List<dynamic>) {
      final team = raw as Map<String, dynamic>;
      final ids = team['playerIds'] as List<dynamic>;
      ids.remove(playerId);
      if (team['id'] == teamId) ids.add(playerId);
    }
  }

  @override
  Future<void> start(String groupId, String id) async {
    final item = _require(id);
    item
      ..['status'] = ChampionshipStatus.inProgress.value
      ..['rulesLocked'] = true;
  }

  @override
  Future<String> createGame(
    String groupId,
    String id,
    String teamAId,
    String teamBId,
  ) async {
    final item = _require(id);
    final games = item['games'] as List<dynamic>;
    final gameId = '$id-game-${_sequence++}';
    games.add({
      'id': gameId,
      'order': games.length + 1,
      'teamAId': teamAId,
      'teamBId': teamBId,
      'teamAGoals': 0,
      'teamBGoals': 0,
      'externalWinnerTeamId': null,
      'status': ChampionshipGameStatus.inProgress.value,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'goals': <dynamic>[],
    });
    item['currentGameId'] = gameId;
    return gameId;
  }

  @override
  Future<void> addGoal(
    String groupId,
    String id,
    String gameId, {
    required String scorerPlayerId,
    String? assistPlayerId,
    required bool isOwnGoal,
    int? timeSeconds,
  }) async {
    final item = _require(id);
    final game = _game(item, gameId);
    final player = (item['players'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((candidate) => candidate['playerId'] == scorerPlayerId);
    final scorerTeamId = player['teamId'];
    final scoresForA = isOwnGoal
        ? scorerTeamId == game['teamBId']
        : scorerTeamId == game['teamAId'];
    final scoreKey = scoresForA ? 'teamAGoals' : 'teamBGoals';
    game[scoreKey] = (game[scoreKey] as int) + 1;
    (game['goals'] as List<dynamic>).add({
      'id': '$gameId-goal-${_sequence++}',
      'scorerPlayerId': scorerPlayerId,
      'assistPlayerId': assistPlayerId,
      'isOwnGoal': isOwnGoal,
      'timeSeconds': timeSeconds,
    });
  }

  Map<String, dynamic> _game(Map<String, dynamic> item, String gameId) =>
      (item['games'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((game) => game['id'] == gameId);

  @override
  Future<void> deleteGoal(
    String groupId,
    String id,
    String gameId,
    String goalId,
  ) async {
    final item = _require(id);
    final game = _game(item, gameId);
    final goals = game['goals'] as List<dynamic>;
    Map<String, dynamic>? removed;
    for (final raw in goals) {
      final goal = raw as Map<String, dynamic>;
      if (goal['id'] == goalId) removed = goal;
    }
    goals.removeWhere((goal) => (goal as Map<String, dynamic>)['id'] == goalId);
    if (removed == null) return;
    final player = (item['players'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere(
            (candidate) => candidate['playerId'] == removed!['scorerPlayerId']);
    final scorerTeamId = player['teamId'];
    final scoresForA = removed['isOwnGoal'] == true
        ? scorerTeamId == game['teamBId']
        : scorerTeamId == game['teamAId'];
    final scoreKey = scoresForA ? 'teamAGoals' : 'teamBGoals';
    game[scoreKey] = (game[scoreKey] as int) - 1;
  }

  @override
  Future<void> setGoalkeeper(
    String groupId,
    String id,
    String teamId,
    String playerId,
  ) async {
    final item = _require(id);
    final players = item['players'] as List<dynamic>;
    for (final raw in players) {
      final player = raw as Map<String, dynamic>;
      if (player['teamId'] == teamId) {
        player['isGoalkeeper'] = player['playerId'] == playerId;
      }
    }
  }

  @override
  Future<void> endGame(
    String groupId,
    String id,
    String gameId, {
    String? externalWinnerTeamId,
  }) async {
    final item = _require(id);
    final game = _game(item, gameId);
    game
      ..['status'] = ChampionshipGameStatus.finished.value
      ..['externalWinnerTeamId'] = externalWinnerTeamId;
    item['currentGameId'] = null;
  }

  @override
  Future<void> finish(String groupId, String id) async {
    final item = _require(id);
    item
      ..['status'] = ChampionshipStatus.postGame.value
      ..['canVote'] = true;
  }

  @override
  Future<void> vote(
    String groupId,
    String id,
    String votedPlayerId, {
    String? gameId,
  }) async {
    final item = _require(id);
    (item['myVotes'] as List<dynamic>).add({
      'gameId': gameId,
      'votedPlayerId': votedPlayerId,
    });
    item['canVote'] = false;
  }

  @override
  Future<void> finalize(
    String groupId,
    String id, {
    List<String>? externalDecisionTeamOrder,
  }) async {
    final item = _require(id);
    item
      ..['status'] = ChampionshipStatus.finalized.value
      ..['canVote'] = false;
    final teams = (item['teams'] as List<dynamic>).cast<Map<String, dynamic>>();
    final order = externalDecisionTeamOrder ??
        teams.map((team) => team['id'] as String).toList();
    for (final team in teams) {
      final position = order.indexOf(team['id'] as String);
      team['finalPosition'] = position < 0 ? null : position + 1;
    }
  }

  static Map<String, dynamic> _seed(ChampionshipStatus status, int index) {
    final id = 'championship-${status.value}';
    final rules = ChampionshipRules.defaults();
    final hasAcceptation = status != ChampionshipStatus.created;
    final hasTeams = status.value >= ChampionshipStatus.teamDraw.value &&
        status != ChampionshipStatus.cancelled;
    final hasGame = status.value >= ChampionshipStatus.inProgress.value &&
        status != ChampionshipStatus.cancelled;
    final isFinalized = status == ChampionshipStatus.finalized;
    final playerIds = List.generate(9, (i) => '$id-player-${i + 1}');
    final teamIds = List.generate(3, (i) => '$id-team-${i + 1}');
    final teams = hasTeams
        ? List.generate(
            3,
            (teamIndex) => {
                  'id': teamIds[teamIndex],
                  'name': ['Azul', 'Verde', 'Laranja'][teamIndex],
                  'colorId': _mockColors[teamIndex].$1,
                  'colorHex': _mockColors[teamIndex].$2,
                  'finalPosition': isFinalized ? teamIndex + 1 : null,
                  'playerIds': playerIds
                      .skip(teamIndex * 3)
                      .take(3)
                      .toList(growable: false),
                })
        : <Map<String, dynamic>>[];
    final games = hasGame
        ? <Map<String, dynamic>>[
            {
              'id': '$id-game-1',
              'order': 1,
              'teamAId': teamIds[0],
              'teamBId': teamIds[1],
              'teamAGoals': 2,
              'teamBGoals': 1,
              'externalWinnerTeamId': null,
              'status': status == ChampionshipStatus.inProgress
                  ? ChampionshipGameStatus.inProgress.value
                  : ChampionshipGameStatus.finished.value,
              'startedAt': DateTime.now()
                  .subtract(const Duration(minutes: 8))
                  .toUtc()
                  .toIso8601String(),
              'goals': [
                {
                  'id': '$id-goal-1',
                  'scorerPlayerId': playerIds[0],
                  'assistPlayerId': playerIds[1],
                  'isOwnGoal': false,
                  'timeSeconds': 90,
                },
                {
                  'id': '$id-goal-2',
                  'scorerPlayerId': playerIds[3],
                  'assistPlayerId': null,
                  'isOwnGoal': false,
                  'timeSeconds': 210,
                },
                {
                  'id': '$id-goal-3',
                  'scorerPlayerId': playerIds[2],
                  'assistPlayerId': playerIds[0],
                  'isOwnGoal': false,
                  'timeSeconds': 390,
                },
              ],
            }
          ]
        : <Map<String, dynamic>>[];

    return {
      'id': id,
      'name': [
        'Copa de Domingo',
        'Taça da Patota',
        'Campeonato Relâmpago',
        'Fica Quem Ganha',
        'Copa Pós-jogo',
        'Torneio dos Amigos',
        'Copa Cancelada',
      ][index % 7],
      'playedAt': DateTime.now()
          .add(Duration(days: index - 3))
          .toUtc()
          .toIso8601String(),
      'placeName': 'Arena Bratnava',
      'status': status.value,
      'rules': rules.toJson(),
      'rulesLocked': status.value >= ChampionshipStatus.inProgress.value,
      'ruleBadges': buildChampionshipRuleBadges(rules),
      'players': List.generate(9, (playerIndex) {
        final teamIndex = playerIndex ~/ 3;
        return {
          'playerId': playerIds[playerIndex],
          'name': [
            'Luis',
            'André',
            'Caio',
            'Bruno',
            'Diego',
            'Rafael',
            'João',
            'Mateus',
            'Pedro'
          ][playerIndex],
          'photoUrl': null,
          'isGuest': playerIndex == 8,
          'isGoalkeeper': playerIndex % 3 == 0,
          'inviteResponse': hasAcceptation
              ? ChampionshipInviteResponse.accepted.value
              : ChampionshipInviteResponse.none.value,
          'teamId': hasTeams ? teamIds[teamIndex] : null,
          'didNotPlay': false,
        };
      }),
      'teams': teams,
      'games': games,
      'standings': hasTeams
          ? List.generate(
              3,
              (teamIndex) => {
                    'position': teamIndex + 1,
                    'teamId': teamIds[teamIndex],
                    'played': hasGame ? 1 : 0,
                    'wins': hasGame && teamIndex == 0 ? 1 : 0,
                    'draws': 0,
                    'losses': hasGame && teamIndex == 1 ? 1 : 0,
                    'goalsFor': hasGame ? [2, 1, 0][teamIndex] : 0,
                    'goalsAgainst': hasGame ? [1, 2, 0][teamIndex] : 0,
                    'goalDifference': hasGame ? [1, -1, 0][teamIndex] : 0,
                    'points': hasGame && teamIndex == 0 ? 3 : 0,
                    'pointsPerGame': hasGame && teamIndex == 0 ? 3.0 : 0.0,
                  })
          : <Map<String, dynamic>>[],
      'currentGameId':
          status == ChampionshipStatus.inProgress ? '$id-game-1' : null,
      'waitingTeamIds':
          status == ChampionshipStatus.inProgress ? [teamIds[2]] : <String>[],
      'topScorers': hasGame
          ? [
              {'playerId': playerIds[0], 'goals': 1},
              {'playerId': playerIds[2], 'goals': 1},
              {'playerId': playerIds[3], 'goals': 1},
            ]
          : <Map<String, dynamic>>[],
      'topAssists': hasGame
          ? [
              {'playerId': playerIds[0], 'assists': 1},
              {'playerId': playerIds[1], 'assists': 1},
            ]
          : <Map<String, dynamic>>[],
      'mvpPlayerIds': isFinalized ? [playerIds[0]] : <String>[],
      'myInviteResponse': hasAcceptation
          ? ChampionshipInviteResponse.accepted.value
          : ChampionshipInviteResponse.none.value,
      'canVote': status == ChampionshipStatus.postGame,
      'myVotes': <Map<String, dynamic>>[],
    };
  }
}

List<String> buildChampionshipRuleBadges(ChampionshipRules rules) {
  final history = switch (rules.historyMode) {
    ChampionshipHistoryMode.consolidated => 'Conta como 1 partida',
    ChampionshipHistoryMode.separateGames => 'Jogos separados',
    ChampionshipHistoryMode.championshipOnly => 'Só no campeonato',
  };
  final result = switch (rules.resultMode) {
    ChampionshipResultMode.perGame => 'Resultado por jogo',
    ChampionshipResultMode.placement => '1º V · 2º E · 3º D',
    ChampionshipResultMode.winForAll => 'Vitória para todos',
    ChampionshipResultMode.presenceOnly => 'Só presença',
  };
  final mvp = switch (rules.mvpMode) {
    ChampionshipMvpMode.perGame => 'MVP por jogo',
    ChampionshipMvpMode.perChampionship => 'MVP do campeonato',
    ChampionshipMvpMode.none => 'Sem MVP',
  };
  return [history, result, mvp];
}
