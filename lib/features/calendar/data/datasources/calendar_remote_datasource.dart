import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/calendar_event.dart';

class CalendarRemoteDataSource {
  final Dio _dio;
  const CalendarRemoteDataSource(this._dio);

  // ── Events ────────────────────────────────────────────────────────────────

  Future<List<CalendarEvent>> fetchEvents(
      String groupId, String start, String end) async {
    final res =
        await _dio.get(ApiConstants.calendarEvents(groupId, start, end));
    final raw = _unwrap(res.data);
    return (raw as List? ?? [])
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createEvent(String groupId, Map<String, dynamic> dto) async {
    final res =
        await _dio.post(ApiConstants.calendarEvents2(groupId), data: dto);
    _throwIfError(res.data);
  }

  Future<void> updateEvent(
      String groupId, String id, Map<String, dynamic> dto) async {
    final res =
        await _dio.put(ApiConstants.calendarEventById(groupId, id), data: dto);
    _throwIfError(res.data);
  }

  Future<void> deleteEvent(String groupId, String id) async {
    final res = await _dio.delete(ApiConstants.calendarEventById(groupId, id));
    _throwIfError(res.data);
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<CalendarCategory>> fetchCategories(String groupId) async {
    final res = await _dio.get(ApiConstants.calendarCategories(groupId));
    final raw = _unwrap(res.data);
    return (raw as List? ?? [])
        .map((e) => CalendarCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createCategory(String groupId, Map<String, dynamic> dto) async {
    final res =
        await _dio.post(ApiConstants.calendarCategories(groupId), data: dto);
    _throwIfError(res.data);
  }

  Future<void> updateCategory(
      String groupId, String id, Map<String, dynamic> dto) async {
    final res = await _dio.put(ApiConstants.calendarCategoryById(groupId, id),
        data: dto);
    _throwIfError(res.data);
  }

  Future<void> deleteCategory(String groupId, String id) async {
    final res =
        await _dio.delete(ApiConstants.calendarCategoryById(groupId, id));
    _throwIfError(res.data);
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  dynamic _unwrap(dynamic data) {
    if (data is List) return data;
    if (data is Map) return data['data'] ?? data['Data'] ?? [];
    return [];
  }
}
