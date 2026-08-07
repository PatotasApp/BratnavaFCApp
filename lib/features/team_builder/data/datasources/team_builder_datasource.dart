import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/team_builder_models.dart';

class TeamBuilderDataSource {
  final Dio _dio;
  const TeamBuilderDataSource(this._dio);

  Future<TeamBuilderStats> fetchStats(
      String groupId, List<String> playerIds) async {
    final res = await _dio.post(
      '/api/TeamBuilder/group/$groupId/stats',
      data: {'playerIds': playerIds},
    );
    return TeamBuilderStats.fromJson(res.data as Map<String, dynamic>);
  }
}
