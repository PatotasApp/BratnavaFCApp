import 'package:dio/dio.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/championship_models.dart';
import 'championship_datasource.dart';

/// Rotas de `docs/campeonato/CONTRATO-API.md` (v6) da API.
///
/// As respostas vêm no envelope `ApiResponse` ({ success, data, message,
/// error, errors }). Ações sem retorno respondem 204 sem corpo; recusas
/// chegam como 4xx com `{ error }` e viram [ServerException] com a mensagem.
class ChampionshipApiDataSource implements ChampionshipDataSource {
  const ChampionshipApiDataSource(this._dio);
  final Dio _dio;

  String _base(String groupId) => '/api/championships/group/$groupId';

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is Map && body['success'] == false) {
        final error = (body['error'] ?? body['message']) as String?;
        throw ServerException(
          error == null || error.isEmpty ? 'Operação recusada.' : error,
          statusCode: response.statusCode,
        );
      }
      return body;
    } on DioException catch (error) {
      throw ServerException(
        extractDioError(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> _map(
    Future<Response<dynamic>> Function() request,
  ) async {
    final data = unwrapMap(await _send(request));
    if (data == null) throw const ServerException('Resposta vazia da API.');
    return data;
  }

  static String? _message(dynamic body) {
    if (body is! Map) return null;
    final message = body['message'] as String?;
    return message == null || message.trim().isEmpty ? null : message;
  }

  @override
  Future<List<ChampionshipSummary>> fetchAll(String groupId) async {
    final body = await _send(() => _dio.get(_base(groupId)));
    return unwrapList(body)
        .map((item) => ChampionshipSummary.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  @override
  Future<ChampionshipDetails> fetchById(String groupId, String id) async =>
      ChampionshipDetails.fromJson(
        await _map(() => _dio.get('${_base(groupId)}/$id')),
      );

  @override
  Future<NextGameSuggestion?> fetchNextGame(String groupId, String id) async {
    final body = await _send(() => _dio.get('${_base(groupId)}/$id/next-game'));
    final data = body is Map ? body['data'] : body;
    return data is Map<String, dynamic>
        ? NextGameSuggestion.fromJson(data)
        : null;
  }

  @override
  Future<String> create(String groupId, ChampionshipUpsert input) async {
    final data = await _map(
      () => _dio.post(_base(groupId), data: input.toJson()),
    );
    return data['id'] as String;
  }

  @override
  Future<void> update(
    String groupId,
    String id,
    ChampionshipUpsert input,
  ) =>
      _send(() => _dio.put('${_base(groupId)}/$id', data: input.toJson()));

  @override
  Future<void> cancel(String groupId, String id) =>
      _send(() => _dio.post('${_base(groupId)}/$id/cancel'));

  @override
  Future<void> openAcceptation(String groupId, String id) =>
      _send(() => _dio.post('${_base(groupId)}/$id/acceptation/open'));

  @override
  Future<void> acceptMyInvite(String groupId, String id) =>
      _send(() => _dio.patch('${_base(groupId)}/$id/my-invite/accept'));

  @override
  Future<void> rejectMyInvite(String groupId, String id) =>
      _send(() => _dio.patch('${_base(groupId)}/$id/my-invite/reject'));

  @override
  Future<void> acceptInvite(String groupId, String id, String playerId) =>
      _send(() => _dio.patch(
            '${_base(groupId)}/$id/invite/accept',
            data: {'playerId': playerId},
          ));

  @override
  Future<void> rejectInvite(String groupId, String id, String playerId) =>
      _send(() => _dio.patch(
            '${_base(groupId)}/$id/invite/reject',
            data: {'playerId': playerId},
          ));

  @override
  Future<void> addGuest(String groupId, String id, String playerId) =>
      _send(() => _dio.post(
            '${_base(groupId)}/$id/players/guest',
            data: {'playerId': playerId},
          ));

  @override
  Future<ChampionshipTeamsDraw> drawTeams(
    String groupId,
    String id,
    int teamCount,
  ) async {
    final body = await _send(() => _dio.post(
          '${_base(groupId)}/$id/teams/draw',
          data: {'teamCount': teamCount},
        ));
    final data = unwrapMap(body);
    if (data == null) throw const ServerException('Resposta vazia da API.');
    return ChampionshipTeamsDraw(
      teams: DefineChampionshipTeams.fromJson(data),
      message: _message(body),
    );
  }

  @override
  Future<void> defineTeams(
    String groupId,
    String id,
    DefineChampionshipTeams input,
  ) =>
      _send(
          () => _dio.put('${_base(groupId)}/$id/teams', data: input.toJson()));

  @override
  Future<void> assignPlayerTeam(
    String groupId,
    String id,
    String playerId,
    String teamId,
  ) =>
      _send(() => _dio.patch(
            '${_base(groupId)}/$id/players/$playerId/team',
            data: {'teamId': teamId},
          ));

  @override
  Future<String?> drawTeamColors(String groupId, String id) async =>
      _message(await _send(
        () => _dio.post('${_base(groupId)}/$id/teams/colors/draw'),
      ));

  @override
  Future<void> updateTeam(
    String groupId,
    String id,
    String teamId, {
    required String name,
    String? colorId,
  }) =>
      _send(() => _dio.patch(
            '${_base(groupId)}/$id/teams/$teamId',
            data: {'name': name, 'colorId': colorId},
          ));

  @override
  Future<void> start(String groupId, String id) =>
      _send(() => _dio.post('${_base(groupId)}/$id/start'));

  @override
  Future<String> createGame(
    String groupId,
    String id,
    String teamAId,
    String teamBId,
  ) async {
    final data = await _map(() => _dio.post(
          '${_base(groupId)}/$id/games',
          data: {'teamAId': teamAId, 'teamBId': teamBId},
        ));
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
  }) =>
      _send(() => _dio.post(
            '${_base(groupId)}/$id/games/$gameId/goals',
            data: {
              'scorerPlayerId': scorerPlayerId,
              'assistPlayerId': assistPlayerId,
              'isOwnGoal': isOwnGoal,
              'timeSeconds': timeSeconds,
            },
          ));

  @override
  Future<void> deleteGoal(
    String groupId,
    String id,
    String gameId,
    String goalId,
  ) =>
      _send(() =>
          _dio.delete('${_base(groupId)}/$id/games/$gameId/goals/$goalId'));

  @override
  Future<void> setGoalkeeper(
    String groupId,
    String id,
    String teamId,
    String playerId,
  ) =>
      _send(() => _dio.patch(
            '${_base(groupId)}/$id/goalkeeper',
            data: {'teamId': teamId, 'playerId': playerId},
          ));

  @override
  Future<void> endGame(
    String groupId,
    String id,
    String gameId, {
    String? externalWinnerTeamId,
  }) =>
      _send(() => _dio.post(
            '${_base(groupId)}/$id/games/$gameId/end',
            data: {'externalWinnerTeamId': externalWinnerTeamId},
          ));

  @override
  Future<void> finish(String groupId, String id) =>
      _send(() => _dio.post('${_base(groupId)}/$id/finish'));

  @override
  Future<void> vote(
    String groupId,
    String id,
    String votedPlayerId, {
    String? gameId,
  }) =>
      _send(() => _dio.post(
            '${_base(groupId)}/$id/vote',
            data: {'votedPlayerId': votedPlayerId, 'gameId': gameId},
          ));

  @override
  Future<void> finalize(
    String groupId,
    String id, {
    List<String>? externalDecisionTeamOrder,
  }) =>
      _send(() => _dio.post(
            '${_base(groupId)}/$id/finalize',
            data: {'externalDecisionTeamOrder': externalDecisionTeamOrder},
          ));
}
