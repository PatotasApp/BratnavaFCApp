import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/absence.dart';

class AbsencesRemoteDataSource {
  final Dio _dio;
  const AbsencesRemoteDataSource(this._dio);

  Future<List<AbsenceDto>> fetchMine() async {
    final res = await _dio.get(
      ApiConstants.absencesMine,
      queryParameters: const {'page': 1, 'pageSize': 200},
    );
    final envelope = res.data as Map<String, dynamic>?;
    final dataNode = envelope?['data'] ?? envelope?['Data'];
    final data =
        dataNode is Map ? (dataNode['items'] ?? dataNode['Items']) : dataNode;
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AbsenceDto.fromJson)
        .toList();
  }

  Future<PagedAbsences> fetchByGroup(
    String groupId, {
    required String status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _dio.get(
      ApiConstants.absencesByGroup(groupId),
      queryParameters: {
        'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    final envelope = res.data as Map<String, dynamic>?;
    final dataNode = envelope?['data'] ?? envelope?['Data'];
    return PagedAbsences.fromJson(dataNode, fallbackPage: page);
  }

  Future<AbsenceDto> create(CreateAbsenceDto dto) async {
    final res = await _dio.post(ApiConstants.absences, data: dto.toJson());
    _throwIfError(res.data);
    return AbsenceDto.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<AbsenceDto> update(String id, CreateAbsenceDto dto) async {
    final res =
        await _dio.put(ApiConstants.absenceById(id), data: dto.toJson());
    _throwIfError(res.data);
    return AbsenceDto.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final res = await _dio.delete(ApiConstants.absenceById(id));
    _throwIfError(res.data);
  }

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }
}
