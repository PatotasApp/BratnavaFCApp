import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/current_match.dart';
import '../../domain/entities/my_player.dart';
import '../../domain/entities/recent_match.dart';

class DashboardRemoteDataSource {
  final Dio _dio;

  const DashboardRemoteDataSource(this._dio);

  Future<List<MyPlayer>> fetchMyPlayers() async {
    try {
      final res = await _dio.get(ApiConstants.playersMe);
      return unwrapList(res.data)
          .map((e) => MyPlayer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }

  Future<CurrentMatch?> fetchCurrentMatch(String groupId) async {
    try {
      // Passo 1 — `upcoming` devolve os headers das partidas em aberto num
      // payload pequeno. Antes usávamos `/current`, que retorna o
      // MatchDetailsDto inteiro só para descobrirmos o id — e ainda assim
      // buscávamos `/details` logo depois. Eram dois payloads gordos para
      // montar um card. É o mesmo caminho do site.
      final res = await _dio.get(ApiConstants.upcomingMatches(groupId));
      final headers = unwrapList(res.data);
      if (headers.isEmpty) return null;

      final stub = headers.first as Map<String, dynamic>;
      final matchId = stub['matchId'] as String? ?? stub['id'] as String? ?? '';
      if (matchId.isEmpty) return null;

      // Step 2 — full details: teamAColor / teamBColor objects, players, status.
      try {
        final detRes =
            await _dio.get(ApiConstants.matchDetails(groupId, matchId));
        final details = unwrapMap(detRes.data);
        if (details != null) {
          // Merge: stub wins for top-level primitives; details win for lists/objects.
          final merged = <String, dynamic>{
            ...stub,
            ...details,
            'matchId': matchId,
          };
          return CurrentMatch.fromJson(merged);
        }
      } catch (_) {
        // Details unavailable — fall back to stub-only (no colors/players).
      }

      return CurrentMatch.fromJson({...stub, 'matchId': matchId});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ServerException(extractDioError(e));
    }
  }

  Future<List<RecentMatch>> fetchRecentMatches(
    String groupId,
    String playerId, {
    int take = 3,
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.playerRecentMatches(groupId),
        queryParameters: {'playerId': playerId, 'take': take},
      );
      return unwrapList(res.data)
          .map((e) => RecentMatch.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(extractDioError(e));
    }
  }
}
