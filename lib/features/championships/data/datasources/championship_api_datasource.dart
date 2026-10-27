import 'package:dio/dio.dart';
import '../../domain/entities/championship_models.dart';
import 'championship_datasource.dart';

class ChampionshipApiDataSource implements ChampionshipDataSource {
  const ChampionshipApiDataSource(this._dio);
  final Dio _dio;

  String _base(String groupId) => '/api/championships/group/$groupId';
  dynamic _unwrap(dynamic value) =>
      value is Map && value.containsKey('data') ? value['data'] : value;

  @override
  Future<List<ChampionshipSummary>> fetchAll(String groupId) async {
    final response = await _dio.get(_base(groupId));
    final data = _unwrap(response.data) as List<dynamic>;
    return data
        .map((item) => ChampionshipSummary.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  @override
  Future<ChampionshipDetails> fetchById(String groupId, String id) async {
    final response = await _dio.get('${_base(groupId)}/$id');
    return ChampionshipDetails.fromJson(
      _unwrap(response.data) as Map<String, dynamic>,
    );
  }

  @override
  Future<NextGameSuggestion?> fetchNextGame(String groupId, String id) async {
    final response = await _dio.get('${_base(groupId)}/$id/next-game');
    final data = _unwrap(response.data);
    return data == null
        ? null
        : NextGameSuggestion.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<String> create(String groupId, ChampionshipUpsert input) async {
    final response = await _dio.post(_base(groupId), data: input.toJson());
    final data = _unwrap(response.data) as Map<String, dynamic>;
    return data['id'] as String;
  }

  @override
  Future<void> update(
    String groupId,
    String id,
    ChampionshipUpsert input,
  ) async =>
      _dio.put('${_base(groupId)}/$id', data: input.toJson());

  @override
  Future<void> cancel(String groupId, String id) async =>
      _dio.post('${_base(groupId)}/$id/cancel');

  @override
  Future<void> openAcceptation(String groupId, String id) async =>
      _dio.post('${_base(groupId)}/$id/acceptation/open');

  @override
  Future<void> acceptMyInvite(String groupId, String id) async =>
      _dio.patch('${_base(groupId)}/$id/my-invite/accept');

  @override
  Future<void> rejectMyInvite(String groupId, String id) async =>
      _dio.patch('${_base(groupId)}/$id/my-invite/reject');

  @override
  Future<void> acceptInvite(
    String groupId,
    String id,
    String playerId,
  ) async =>
      _dio.patch(
        '${_base(groupId)}/$id/invite/accept',
        data: {'playerId': playerId},
      );

  @override
  Future<void> rejectInvite(
    String groupId,
    String id,
    String playerId,
  ) async =>
      _dio.patch(
        '${_base(groupId)}/$id/invite/reject',
        data: {'playerId': playerId},
      );

  @override
  Future<void> addGuest(String groupId, String id, String playerId) async =>
      _dio.post(
        '${_base(groupId)}/$id/players/guest',
        data: {'playerId': playerId},
      );

  @override
  Future<DefineChampionshipTeams> drawTeams(
    String groupId,
    String id,
    int teamCount,
  ) async {
    final response = await _dio.post(
      '${_base(groupId)}/$id/teams/draw',
      data: {'teamCount': teamCount},
    );
    return DefineChampionshipTeams.fromJson(
      _unwrap(response.data) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> defineTeams(
    String groupId,
    String id,
    DefineChampionshipTeams input,
  ) async =>
      _dio.put('${_base(groupId)}/$id/teams', data: input.toJson());

  @override
  Future<void> assignPlayerTeam(
    String groupId,
    String id,
    String playerId,
    String teamId,
  ) async =>
      _dio.patch(
        '${_base(groupId)}/$id/players/$playerId/team',
        data: {'teamId': teamId},
      );

  @override
  Future<void> start(String groupId, String id) async =>
      _dio.post('${_base(groupId)}/$id/start');

  @override
  Future<String> createGame(
    String groupId,
    String id,
    String teamAId,
    String teamBId,
  ) async {
    final response = await _dio.post(
      '${_base(groupId)}/$id/games',
      data: {'teamAId': teamAId, 'teamBId': teamBId},
    );
    final data = _unwrap(response.data) as Map<String, dynamic>;
    return data['gameId'] as String;
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
  }) async =>
      _dio.post(
        '${_base(groupId)}/$id/games/$gameId/goals',
        data: {
          'scorerPlayerId': scorerPlayerId,
          'assistPlayerId': assistPlayerId,
          'isOwnGoal': isOwnGoal,
          'timeSeconds': timeSeconds,
        },
      );

  @override
  Future<void> deleteGoal(
    String groupId,
    String id,
    String gameId,
    String goalId,
  ) async =>
      _dio.delete('${_base(groupId)}/$id/games/$gameId/goals/$goalId');

  @override
  Future<void> setGoalkeeper(
    String groupId,
    String id,
    String teamId,
    String playerId,
  ) async =>
      _dio.patch(
        '${_base(groupId)}/$id/goalkeeper',
        data: {'teamId': teamId, 'playerId': playerId},
      );

  @override
  Future<void> endGame(
    String groupId,
    String id,
    String gameId, {
    String? externalWinnerTeamId,
  }) async =>
      _dio.post(
        '${_base(groupId)}/$id/games/$gameId/end',
        data: {'externalWinnerTeamId': externalWinnerTeamId},
      );

  @override
  Future<void> finish(String groupId, String id) async =>
      _dio.post('${_base(groupId)}/$id/finish');

  @override
  Future<void> vote(
    String groupId,
    String id,
    String votedPlayerId, {
    String? gameId,
  }) async =>
      _dio.post(
        '${_base(groupId)}/$id/vote',
        data: {'votedPlayerId': votedPlayerId, 'gameId': gameId},
      );

  @override
  Future<void> finalize(
    String groupId,
    String id, {
    List<String>? externalDecisionTeamOrder,
  }) async =>
      _dio.post(
        '${_base(groupId)}/$id/finalize',
        data: {'externalDecisionTeamOrder': externalDecisionTeamOrder},
      );
}
