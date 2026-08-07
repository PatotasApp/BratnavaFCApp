import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../dashboard/domain/entities/my_player.dart';
import '../../domain/entities/player_history_models.dart';

class PlayerHistoryRemoteDataSource {
  final Dio _dio;
  const PlayerHistoryRemoteDataSource(this._dio);

  // GET /api/players/mine → List<MyPlayer>
  Future<List<MyPlayer>> fetchMyPlayers() async {
    final res = await _dio.get(ApiConstants.playersMe);
    return unwrapList(res.data)
        .map((e) => MyPlayer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // GET /api/matches/group/{groupId}/player-history?playerId={}&year={}
  // → List<MatchHistoryItemDto>
  /// [year] nulo traz o histórico inteiro — é como o site chama por padrão.
  /// Mandar sempre o ano corrente escondia temporadas anteriores e fazia a
  /// "primeira temporada" ser sempre a atual.
  Future<List<MatchHistoryItem>> fetchPlayerHistory({
    required String groupId,
    required String playerId,
    int? year,
  }) async {
    final res = await _dio.get(
      '/api/matches/group/$groupId/player-history',
      queryParameters: {
        'playerId': playerId,
        if (year != null) 'year': year,
      },
    );
    return unwrapList(res.data)
        .map((e) => MatchHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
