import 'package:dio/dio.dart';
import '../../domain/entities/team_builder_models.dart';

class TeamBuilderDataSource {
  final Dio _dio;
  const TeamBuilderDataSource(this._dio);

  Future<TeamBuilderPlayers> fetchPlayers(
      String groupId, TeamBuilderFilter filter) async {
    final res = await _dio.get(
      '/api/TeamBuilder/group/$groupId/players',
      queryParameters: filter.toJson(),
    );
    return TeamBuilderPlayers.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TeamBuilderStats> fetchStats(
      String groupId, List<String> playerIds, TeamBuilderFilter filter) async {
    final res = await _dio.post(
      '/api/TeamBuilder/group/$groupId/stats',
      data: {'playerIds': playerIds, ...filter.toJson()},
    );
    return TeamBuilderStats.fromJson(res.data as Map<String, dynamic>);
  }
}
