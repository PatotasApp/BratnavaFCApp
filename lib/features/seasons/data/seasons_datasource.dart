import 'package:dio/dio.dart';
import '../domain/season_models.dart';

/// Rotas em api/seasons/group/{groupId} (docs/temporadas/TEMPORADAS.md no repo da API).
class SeasonsDatasource {
  final Dio _dio;
  const SeasonsDatasource(this._dio);

  String _base(String groupId) => '/api/seasons/group/$groupId';

  Future<SeasonsOverview> list(String groupId) async {
    final res = await _dio.get(_base(groupId));
    return SeasonsOverview.fromJson(_unwrap(res.data));
  }

  Future<SeasonClosePreview> closePreview(
      String groupId, DateTime cutAt) async {
    final res = await _dio.get('${_base(groupId)}/close-preview',
        queryParameters: {'cutAt': cutAt.toUtc().toIso8601String()});
    return SeasonClosePreview.fromJson(_unwrap(res.data));
  }

  Future<void> close(String groupId,
      {required DateTime cutAt,
      String? nextName,
      required bool nextIsPreSeason}) async {
    await _dio.post('${_base(groupId)}/close', data: {
      'cutAt': cutAt.toUtc().toIso8601String(),
      'nextName': nextName,
      'nextIsPreSeason': nextIsPreSeason,
    });
  }

  Future<void> update(String groupId, String seasonId,
      {String? name, required bool isPreSeason}) async {
    await _dio.put('${_base(groupId)}/$seasonId',
        data: {'name': name, 'isPreSeason': isPreSeason});
  }

  Future<void> moveStart(
      String groupId, String seasonId, DateTime startsAt) async {
    await _dio.put('${_base(groupId)}/$seasonId/start',
        data: {'startsAt': startsAt.toUtc().toIso8601String()});
  }

  Future<void> undoClose(String groupId) async {
    await _dio.post('${_base(groupId)}/undo-close');
  }

  Future<SeasonSummary> summary(String groupId, String seasonId) async {
    final res = await _dio.get('${_base(groupId)}/$seasonId/summary');
    return SeasonSummary.fromJson(_unwrap(res.data));
  }

  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map) {
      final map = body.cast<String, dynamic>();
      final data = map['data'];
      if (data is Map) return data.cast<String, dynamic>();
      return map;
    }
    throw const FormatException('Resposta inesperada da API');
  }
}
