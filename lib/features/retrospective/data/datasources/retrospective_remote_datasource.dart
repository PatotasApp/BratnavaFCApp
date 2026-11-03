import 'package:dio/dio.dart';

import '../../../../core/api/api_response.dart';
import '../../domain/entities/player_retrospective.dart';

class RetrospectiveRemoteDataSource {
  final Dio _dio;
  const RetrospectiveRemoteDataSource(this._dio);

  // GET /api/Retrospective/group/{groupId}?playerId=&year= (só admin da patota)
  Future<PlayerRetrospective> fetch(String groupId,
      {String? playerId, int? year}) async {
    final res = await _dio.get(
      '/api/Retrospective/group/$groupId',
      queryParameters: {
        if (playerId != null && playerId.isNotEmpty) 'playerId': playerId,
        if (year != null) 'year': year,
      },
    );
    final data = unwrapMap(res.data);
    if (data == null) {
      throw Exception('Resposta inesperada da API de retrospectiva');
    }
    return PlayerRetrospective.fromJson(data);
  }
}
