import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/errors/app_exception.dart';
import 'package:patotas_app/features/championships/data/datasources/championship_api_datasource.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_enums.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_models.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_rules.dart';

/// Responde cada rota com o JSON do contrato v6, no envelope `ApiResponse`
/// que o backend serializa (`Ok(result)` → success/data/message).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  final Map<String, (int, Object?)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    final (status, body) = routes[key] ?? (404, {'error': 'sem rota $key'});
    if (body == null) return ResponseBody.fromString('', status);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _base = '/api/championships/group/g1';

Map<String, dynamic> _ok(Object? data, {String? message}) => {
      'success': true,
      'data': data,
      'message': message,
      'error': null,
      'errors': <String>[],
      'status': 200,
    };

final _rules = {
  'historyMode': 1,
  'resultMode': 2,
  'placementResults': [1, 2, 3],
  'mvpMode': 2,
  'mvpCountsInGeneralStats': true,
  'goalsCountInGeneralStats': false,
  'includeInTeamDraw': false,
  'minGamesForPlacementResult': 1,
  'format': 2,
  'roundRobinTurns': 1,
  'winnerStays': {'consecutiveWinsLimit': 2, 'tieRule': 2, 'limitRule': 1},
  'gameEnd': {'timeLimitMinutes': 10, 'goalLimit': 2},
  'standings': {
    'mode': 2,
    'winPoints': 3,
    'drawPoints': 1,
    'tiebreakers': [1, 2, 3, 4, 5],
  },
};

final _details = {
  'id': 'c1',
  'name': 'Copa',
  'playedAt': '2026-10-27T21:30:00Z',
  'placeName': 'Arena',
  'status': 3,
  'rules': _rules,
  'rulesLocked': true,
  'ruleBadges': ['Conta como uma única partida', '1º V · 2º E · 3º D'],
  'players': [
    {
      'playerId': 'p1',
      'name': 'Luis',
      'photoUrl': null,
      'isGuest': false,
      'isGoalkeeper': true,
      'inviteResponse': 3,
      'teamId': 't1',
      'didNotPlay': false,
    },
  ],
  'teams': [
    {
      'id': 't1',
      'name': 'Azul',
      'colorId': 'cor1',
      'colorHex': '#2563EB',
      'finalPosition': null,
      'playerIds': ['p1'],
    },
    {
      'id': 't2',
      'name': 'Sem cor',
      'colorId': null,
      'colorHex': null,
      'finalPosition': null,
      'playerIds': <String>[],
    },
  ],
  'games': [
    {
      'id': 'j1',
      'order': 1,
      'teamAId': 't1',
      'teamBId': 't2',
      'teamAGoals': 1,
      'teamBGoals': 0,
      'externalWinnerTeamId': null,
      'status': 1,
      'startedAt': '2026-10-27T21:35:00Z',
      'goals': [
        {
          'id': 'g1',
          'scorerPlayerId': 'p1',
          'assistPlayerId': null,
          'isOwnGoal': false,
          'timeSeconds': 60,
        },
      ],
    },
  ],
  'standings': [
    {
      'position': 1,
      'teamId': 't1',
      'played': 1,
      'wins': 1,
      'draws': 0,
      'losses': 0,
      'goalsFor': 1,
      'goalsAgainst': 0,
      'goalDifference': 1,
      'points': 3,
      'pointsPerGame': 3.0,
    },
  ],
  'currentGameId': 'j1',
  'waitingTeamIds': <String>[],
  'topScorers': [
    {'playerId': 'p1', 'goals': 1},
  ],
  'topAssists': <Map<String, dynamic>>[],
  'mvpPlayerIds': <String>[],
  'myInviteResponse': null,
  'canVote': false,
  'myVotes': <Map<String, dynamic>>[],
};

ChampionshipUpsert _upsert() => ChampionshipUpsert(
      name: 'Copa',
      playedAt: DateTime.utc(2026, 10, 27, 21, 30),
      placeName: 'Arena',
      rules: ChampionshipRules.fromJson(_rules),
    );

void main() {
  late _FakeAdapter adapter;
  late ChampionshipApiDataSource datasource;

  void setUpRoutes(Map<String, (int, Object?)> routes) {
    adapter = _FakeAdapter(routes);
    final dio = Dio()..httpClientAdapter = adapter;
    datasource = ChampionshipApiDataSource(dio);
  }

  test('lista e detalhe saem do envelope ApiResponse', () async {
    setUpRoutes({
      'GET $_base': (
        200,
        _ok([
          {
            'id': 'c1',
            'name': 'Copa',
            'playedAt': '2026-10-27T21:30:00Z',
            'placeName': 'Arena',
            'status': 5,
            'teamCount': 3,
            'gameCount': 7,
            'championTeamName': 'Azul',
            'championTeamColorHex': '#2563EB',
            'ruleBadges': ['Conta como uma única partida'],
          },
        ]),
      ),
      'GET $_base/c1': (200, _ok(_details)),
    });

    final list = await datasource.fetchAll('g1');
    final details = await datasource.fetchById('g1', 'c1');

    expect(list.single.status, ChampionshipStatus.finalized);
    expect(list.single.championTeamName, 'Azul');
    expect(details.rules.winnerStays!.limitRule,
        WinnerStaysLimitRule.winnerLeaves);
    expect(details.rules.minGamesForPlacementResult, 1);
    expect(details.teams[1].colorHex, isNull);
    expect(details.currentGame!.goals.single.scorerPlayerId, 'p1');
    expect(details.myInviteResponse, isNull);
  });

  test('próximo jogo nulo quando o campeonato acabou', () async {
    setUpRoutes({'GET $_base/c1/next-game': (200, _ok(null))});

    expect(await datasource.fetchNextGame('g1', 'c1'), isNull);
  });

  test('create e createGame leem o id do envelope', () async {
    setUpRoutes({
      'POST $_base': (201, _ok({'id': 'novo'})),
      'POST $_base/c1/games': (201, _ok({'gameId': 'j9'})),
    });

    expect(await datasource.create('g1', _upsert()), 'novo');
    expect(await datasource.createGame('g1', 'c1', 't1', 't2'), 'j9');
    final body = adapter.requests.first.data as Map<String, dynamic>;
    final rules = body['rules'] as Map<String, dynamic>;
    expect(rules.containsKey('championshipEnd'), isFalse);
    expect((rules['winnerStays'] as Map)['limitRule'], 1);
    expect((rules['standings'] as Map)['tiebreakers'], [1, 2, 3, 4, 5]);
  });

  test('sorteio de times devolve o aviso de poucas cores', () async {
    const warning = 'Ha so 2 cor(es) ativa(s) para 3 times: 1 time(s) '
        'ficaram sem cor. Cadastre mais cores em Cores dos times.';
    setUpRoutes({
      'POST $_base/c1/teams/draw': (
        200,
        _ok({
          'teams': [
            {
              'name': 'Azul',
              'colorId': 'cor1',
              'playerIds': ['p1'],
              'goalkeeperPlayerId': 'p1',
            },
          ],
        }, message: warning),
      ),
    });

    final draw = await datasource.drawTeams('g1', 'c1', 3);

    expect(draw.message, warning);
    expect(draw.teams.teams.single.colorId, 'cor1');
    expect(adapter.requests.single.data, {'teamCount': 3});
  });

  test('sorteio de cores aceita 204 sem corpo e lê message se vier', () async {
    setUpRoutes({'POST $_base/c1/teams/colors/draw': (204, null)});
    expect(await datasource.drawTeamColors('g1', 'c1'), isNull);

    setUpRoutes({
      'POST $_base/c1/teams/colors/draw': (
        200,
        _ok(null, message: 'Cores sorteadas.'),
      ),
    });
    expect(await datasource.drawTeamColors('g1', 'c1'), 'Cores sorteadas.');
  });

  test('editar time manda nome e cor no PATCH', () async {
    setUpRoutes({'PATCH $_base/c1/teams/t1': (204, null)});

    await datasource.updateTeam('g1', 'c1', 't1', name: 'Azul', colorId: null);

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.data, {'name': 'Azul', 'colorId': null});
  });

  test('recusa 400 { error } vira ServerException com a mensagem', () async {
    setUpRoutes({
      'POST $_base/c1/finish': (
        400,
        {'error': 'Encerre o jogo em andamento antes.'},
      ),
    });

    expect(
      () => datasource.finish('g1', 'c1'),
      throwsA(isA<ServerException>().having(
        (error) => error.message,
        'message',
        'Encerre o jogo em andamento antes.',
      )),
    );
  });
}
