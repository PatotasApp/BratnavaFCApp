import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/team_color.dart';

class TeamColorRemoteDataSource {
  final Dio _dio;
  const TeamColorRemoteDataSource(this._dio);

  Future<List<TeamColor>> fetchColors(String groupId) async {
    final res = await _dio.get(ApiConstants.teamColors(groupId));
    final raw = _unwrapList(res.data);
    return raw
        .map((e) => TeamColor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TeamColor> createColor(
      String groupId, String name, String hexValue) async {
    final res = await _dio.post(
      ApiConstants.teamColors(groupId),
      data: {'name': name, 'hexValue': hexValue},
    );
    final raw = _unwrapMap(res.data);
    return TeamColor.fromJson(raw);
  }

  Future<TeamColor> updateColor(
      String groupId, String colorId, String name, String hexValue) async {
    final res = await _dio.put(
      ApiConstants.teamColorById(groupId, colorId),
      data: {'name': name, 'hexValue': hexValue},
    );
    final raw = _unwrapMap(res.data);
    return TeamColor.fromJson(raw);
  }

  Future<void> activateColor(String groupId, String colorId) async {
    final res =
        await _dio.post(ApiConstants.teamColorActivate(groupId, colorId));
    _throwIfError(res.data);
  }

  Future<void> deactivateColor(String groupId, String colorId) async {
    final res =
        await _dio.post(ApiConstants.teamColorDeactivate(groupId, colorId));
    _throwIfError(res.data);
  }

  /// Lança exceção quando o servidor retorna HTTP 200 com corpo de erro.
  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = (data['error'] ?? data['message']) as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final d = data['data'] ?? data['Data'];
      if (d is List) return d;
    }
    return [];
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      if (data.containsKey('Data') && data['Data'] is Map<String, dynamic>) {
        return data['Data'] as Map<String, dynamic>;
      }
      return data;
    }
    return {};
  }
}
